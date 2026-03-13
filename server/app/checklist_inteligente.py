"""
Servico de geracao de checklist inteligente baseado nos documentos do projeto.

Pipeline incremental por pagina com SSE streaming:
1. Para cada pagina do PDF -> identifica caracteristicas
2. Para cada caracteristica NOVA -> gera itens de checklist com normas detalhadas
3. Envia resultados ao cliente via Server-Sent Events em tempo real

Cadeia de fallback para identificacao: Gemini -> OpenAI -> Claude
Cadeia de fallback para geracao: Gemini -> OpenAI (web search)
Cadeia de fallback para enriquecimento: Gemini -> OpenAI -> Claude

Guardrails obrigatorios (RULES.md):
- Nunca apresentar como parecer tecnico ou opiniao profissional
- Indicar nivel de confianca em toda analise
- Itens criticos exigem evidencia
- Achados de alto risco requerem validacao profissional
- Linguagem acessivel ao proprietario leigo
"""

import base64
import json
import logging
import os
from datetime import datetime, timezone
from typing import Generator, Optional
from uuid import UUID

import anthropic
from openai import OpenAI

from .pdf_utils import extrair_pagina_individual, contar_paginas
from .utils import clean_json_response

logger = logging.getLogger(__name__)

# ─── Mapeamento de caracteristicas para etapas ──────────────────────────────

CARACTERISTICA_ETAPA_MAP: dict[str, list[str]] = {
    "piscina": [
        "Fundacao e Estrutura",
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "ar_condicionado": [
        "Planejamento",
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "elevador": [
        "Fundacao e Estrutura",
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "aquecimento_solar": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "energia_solar_fotovoltaica": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "automacao_residencial": [
        "Planejamento",
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "lareira": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
    ],
    "churrasqueira": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
    ],
    "adega": [
        "Acabamentos",
        "Entrega e Testes",
    ],
    "sauna": [
        "Acabamentos",
        "Entrega e Testes",
    ],
    "aquecimento_piso": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
    ],
    "sistema_incendio": [
        "Planejamento",
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "gas_encanado": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "cisterna_reuso": [
        "Fundacao e Estrutura",
        "Alvenaria e Infraestrutura",
        "Entrega e Testes",
    ],
    "paisagismo_irrigacao": [
        "Acabamentos",
        "Entrega e Testes",
    ],
    "home_theater": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
    ],
    "gerador": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
    "portao_automatico": [
        "Acabamentos",
        "Entrega e Testes",
    ],
    "cerca_eletrica": [
        "Acabamentos",
        "Entrega e Testes",
    ],
    "cftv": [
        "Alvenaria e Infraestrutura",
        "Acabamentos",
        "Entrega e Testes",
    ],
}


# ─── Prompt para analise de pagina individual ────────────────────────────────

PHASE1_PAGE_PROMPT = """\
Voce e um Especialista em Leitura de Projetos de Construcao Civil.
Sua missao e analisar os documentos anexados e varrer a prancha em busca de \
SISTEMAS ESPECIAIS e INFRAESTRUTURAS ESPECIFICAS.

DIRETRIZES DE EXTRACAO (REGRA DE ZERO INFERENCIA):
1. Identifique SOMENTE as caracteristicas que estao CLARAMENTE escritas, \
desenhadas com simbologia tecnica explicita ou cotadas.
2. NUNCA ESPECULE. Um banheiro grande nao significa "sauna" a menos que \
esteja escrito ou tenha o equipamento especificado.
3. Nao liste equipamentos padrao (torneiras comuns, chuveiros eletricos, \
tomadas simples, interruptores).
4. Cite a evidencia exata que o fez identificar o sistema (texto lido ou simbolo visto).

SISTEMAS ALVO (Busque apenas por estes ou similares de alta complexidade):
- Lazer/Agua: Piscina, spa, espelho d'agua, sauna (seca/umida).
- Climatizacao: Ar condicionado (VRF, Split, Central), aquecimento de piso, lareira.
- Energia/Aquecimento: Aquecimento solar (boiler/placas), energia solar fotovoltaica, gerador.
- Tecnologia/Seguranca: Automacao residencial (Smart Home), CFTV, cerca eletrica, \
portao automatico, home theater (acustica).
- Instalacoes Especiais: Elevador/Plataforma, sistema de combate a incendio \
(SPDA, sprinklers), gas encanado, cisterna/reuso de agua, irrigacao automatica.

FORMATO DE RESPOSTA OBRIGATORIO (JSON puro):
{
  "resumo_prancha": "Descricao concisa do conteudo desta pagina \
(ex: Planta de cobertura e telhado).",
  "sistemas_especiais_encontrados": [
    {
      "categoria_id": "Identificador padronizado (ex: energia_solar_fotovoltaica)",
      "nome_encontrado": "Nome exato encontrado no projeto (ex: Placas Fotovoltaicas 400W)",
      "localizacao_na_prancha": "Onde esta localizado o detalhe \
(ex: Canto superior direito, na legenda)",
      "evidencia_visual_ou_textual": "Texto exato ou descricao do simbolo tecnico \
que prova a existencia do sistema."
    }
  ]
}
IMPORTANTE: Se a pagina for apenas uma planta generica sem nenhum dos sistemas \
acima, retorne a lista "sistemas_especiais_encontrados" VAZIA [].
Retorne APENAS o JSON valido."""


# ─── Prompt Fase 2: Geracao de itens (atualizado com normas explicativas) ────

PHASE2_SYSTEM_PROMPT = """\
Voce e um Auditor de Obras de Alto Padrao e Especialista em Normas Tecnicas (ABNT/NR).
Sua missao e gerar um checklist de fiscalizacao pratico para um PROPRIETARIO DE OBRA \
leigo, focado exclusivamente no seguinte sistema especial identificado no projeto.

DIRETRIZES DO CHECKLIST:
1. O proprietario NAO e engenheiro. Traduza qualquer jargao para o impacto pratico \
na rotina, seguranca ou bolso dele.
2. Cada item deve ser uma acao de verificacao fisica ou documental que o proprietario \
consiga fazer sozinho.
3. Classifique rigorosamente a Etapa da Obra (Planejamento, Fundacao e Estrutura, \
Alvenaria e Infraestrutura, Acabamentos, Entrega e Testes).
4. Informe sempre a Norma Tecnica (ABNT/NR/NTC) de referencia. Se nao houver, \
indique "Boas praticas de engenharia".

FORMATO DE RESPOSTA OBRIGATORIO (JSON puro):
{
  "sistema_analisado": "identificador do sistema (ex: piscina)",
  "introducao_ao_proprietario": "Breve explicacao do porque este sistema exige \
atencao especial na obra (max 3 linhas).",
  "checklist": [
    {
      "etapa_da_obra": "Planejamento | Fundacao e Estrutura | Alvenaria e Infraestrutura \
| Acabamentos | Entrega e Testes",
      "risco": "ALTO | MEDIO | BAIXO",
      "titulo_verificacao": "O que verificar (ex: Impermeabilizacao do fosso do elevador)",
      "norma_tecnica": "Ex: NBR NM 313 ou ABNT NBR 5410",
      "por_que_isso_importa": "Explicacao para o leigo do que acontece se der errado \
(ex: Se infiltrar agua, a placa do elevador queima).",
      "como_o_proprietario_verifica": {
        "acao_pratica": "Instrucao visual ou documental (ex: Peca o laudo de \
estanqueidade antes de fecharem a caixa).",
        "medida_ou_regra_minima": "Exigencia normativa concreta (ex: O poco deve ter \
no minimo 1.50m de profundidade)."
      },
      "dialogo_com_engenheiro": {
        "pergunta_pronta": "Pergunta educada e direta para mandar no WhatsApp do engenheiro.",
        "resposta_tranquilizadora": "O que o proprietario deve esperar ouvir para saber \
que o profissional domina o assunto."
      },
      "documento_para_exibir": "Nome do laudo, ART ou certificado a ser cobrado na etapa (ou null)"
    }
  ]
}
Retorne APENAS o JSON valido. Certifique-se de criar de 3 a 5 itens de checklist \
altamente relevantes e especificos para o sistema."""


# ─── Normalizadores: converte resposta IA nova → formato interno ─────────────

def _normalizar_fase1(raw: dict) -> dict:
    """Converte resposta da Fase 1 (novo formato) para o formato interno usado pelo pipeline."""
    sistemas = raw.get("sistemas_especiais_encontrados", [])
    caracteristicas = []
    for s in sistemas:
        caracteristicas.append({
            "id": s.get("categoria_id", ""),
            "nome_legivel": s.get("nome_encontrado", s.get("categoria_id", "")),
            "descricao_no_projeto": (
                f"{s.get('localizacao_na_prancha', '')} — "
                f"{s.get('evidencia_visual_ou_textual', '')}"
            )[:200],
            "evidencia_textual": s.get("evidencia_visual_ou_textual", ""),
            "confianca": 90,  # zero-inference = alta confianca implicita
        })
    return {
        "caracteristicas": caracteristicas,
        "resumo_pagina": raw.get("resumo_prancha", ""),
    }


def _normalizar_fase2(raw: dict) -> dict:
    """Converte resposta da Fase 2 (novo formato) para o formato interno de itens."""
    itens = []
    introducao = raw.get("introducao_ao_proprietario", "")
    for item in raw.get("checklist", []):
        risco_raw = (item.get("risco", "BAIXO") or "BAIXO").upper()
        risco_map = {"ALTO": "alto", "MEDIO": "medio", "MÉDIO": "medio", "BAIXO": "baixo"}
        risco = risco_map.get(risco_raw, "baixo")
        is_alto = risco == "alto"

        verificacao = item.get("como_o_proprietario_verifica", {}) or {}
        dialogo = item.get("dialogo_com_engenheiro", {}) or {}
        doc = item.get("documento_para_exibir")

        itens.append({
            "etapa_nome": item.get("etapa_da_obra", "Acabamentos"),
            "titulo": item.get("titulo_verificacao", "")[:80],
            "descricao": item.get("por_que_isso_importa", "")[:300],
            "norma_referencia": item.get("norma_tecnica"),
            "critico": is_alto,
            "risco_nivel": risco,
            "requer_validacao_profissional": is_alto,
            "confianca": 85,
            "como_verificar": verificacao.get("acao_pratica", ""),
            "medidas_minimas": verificacao.get("medida_ou_regra_minima"),
            "explicacao_leigo": item.get("por_que_isso_importa", "")[:200],
            "dado_projeto": {
                "descricao": item.get("titulo_verificacao", "")[:150],
                "especificacao": verificacao.get("medida_ou_regra_minima", ""),
                "fonte": "Projeto de construcao",
                "valor_referencia": verificacao.get("medida_ou_regra_minima", ""),
            },
            "verificacoes": [
                {
                    "instrucao": verificacao.get("acao_pratica", "")[:100],
                    "tipo": "visual",
                    "valor_esperado": verificacao.get("medida_ou_regra_minima", ""),
                    "como_medir": verificacao.get("acao_pratica", "")[:150],
                }
            ],
            "pergunta_engenheiro": {
                "contexto": item.get("titulo_verificacao", "")[:150],
                "pergunta": dialogo.get("pergunta_pronta", "")[:150],
                "tom": "colaborativo",
                "resposta_esperada": dialogo.get("resposta_tranquilizadora", ""),
            },
            "documentos_a_exigir": [doc] if doc else [],
        })

    return {
        "caracteristica": raw.get("sistema_analisado", ""),
        "introducao_ao_proprietario": introducao,
        "itens": itens,
    }


# ─── Funcoes auxiliares ──────────────────────────────────────────────────────

def _sse_event(event: str, data: dict) -> str:
    """Formata um evento SSE."""
    return f"data: {json.dumps({'event': event, **data}, ensure_ascii=False)}\n\n"


# ─── Fase 1: Analise de pagina individual (com fallback) ────────────────────

def _analisar_pagina_claude(img_b64: str, page_label: str) -> dict:
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY nao configurada")

    client = anthropic.Anthropic(api_key=api_key)
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": f"[{page_label}]"},
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": img_b64,
                    },
                },
                {"type": "text", "text": PHASE1_PAGE_PROMPT},
            ],
        }],
    )
    text = response.content[0].text if response.content else ""
    if not text:
        raise ValueError("Claude nao retornou resposta")
    return json.loads(clean_json_response(text))


def _analisar_pagina_openai(img_b64: str, page_label: str) -> dict:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY nao configurada")

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": f"[{page_label}]"},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
                {"type": "text", "text": PHASE1_PAGE_PROMPT},
            ],
        }],
    )
    text = response.choices[0].message.content or ""
    if not text:
        raise ValueError("OpenAI nao retornou resposta")
    return json.loads(clean_json_response(text))


def _analisar_pagina_gemini(img_b64: str, page_label: str) -> dict:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY nao configurada")

    import google.generativeai as genai
    from google.generativeai.types import content_types

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")

    img_bytes = base64.standard_b64decode(img_b64)
    response = model.generate_content([
        f"[{page_label}]",
        content_types.to_part({"mime_type": "image/jpeg", "data": img_bytes}),
        PHASE1_PAGE_PROMPT,
    ])
    text = response.text
    if not text:
        raise ValueError("Gemini nao retornou resposta")
    return json.loads(clean_json_response(text))


def analisar_pagina(img_b64: str, page_label: str) -> dict:
    """Analisa uma pagina individual com fallback chain: Gemini -> OpenAI -> Claude.
    Normaliza resposta do novo formato (sistemas_especiais) para formato interno."""
    providers = [
        ("Gemini", _analisar_pagina_gemini),
        ("OpenAI", _analisar_pagina_openai),
        ("Claude", _analisar_pagina_claude),
    ]
    last_error = None
    for name, func in providers:
        try:
            result = func(img_b64, page_label)
            # Normaliza se veio no novo formato (sistemas_especiais_encontrados)
            if "sistemas_especiais_encontrados" in result:
                result = _normalizar_fase1(result)
            logger.info("Pagina '%s' analisada via %s", page_label, name)
            return result
        except Exception as exc:
            logger.warning("Analise de '%s' falhou via %s: %s", page_label, name, exc)
            last_error = exc

    raise ValueError(f"Todos os providers falharam para '{page_label}'. Ultimo: {last_error}")


# ─── Fase 2: Geracao de itens por caracteristica ────────────────────────────

def _gerar_itens_openai(query: str) -> dict:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY nao configurada")

    client = OpenAI(api_key=api_key)
    response = client.responses.create(
        model="gpt-4o-mini",
        tools=[{"type": "web_search_preview"}],
        input=f"{PHASE2_SYSTEM_PROMPT}\n\nConsulta: {query}",
    )

    output_text = ""
    for item in response.output:
        if hasattr(item, "content"):
            for block in item.content:
                if hasattr(block, "text"):
                    output_text = block.text
                    break
        if output_text:
            break

    if not output_text:
        raise ValueError("OpenAI nao retornou resposta valida")
    return json.loads(clean_json_response(output_text))


def _gerar_itens_gemini(query: str) -> dict:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY nao configurada")

    import google.generativeai as genai
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")

    response = model.generate_content(
        f"{PHASE2_SYSTEM_PROMPT}\n\nConsulta: {query}"
    )

    output_text = response.text
    if not output_text:
        raise ValueError("Gemini nao retornou resposta valida")
    return json.loads(clean_json_response(output_text))


def gerar_itens_para_caracteristica(
    caracteristica_id: str,
    caracteristica_nome: str,
    descricao_no_projeto: str,
    etapas_alvo: list[str],
    localizacao: Optional[str] = None,
) -> dict:
    """
    Para uma caracteristica identificada, gera itens de checklist.
    Cadeia de fallback: OpenAI (com web search) -> Gemini.
    """
    etapas_str = ", ".join(etapas_alvo)
    loc_str = f" na regiao de {localizacao}" if localizacao else " no Brasil"

    query = (
        f"Sistema identificado no projeto: {caracteristica_nome}. "
        f"Detalhes encontrados no projeto: {descricao_no_projeto}. "
        f"Localizacao da obra{loc_str}. "
        f"Foque nos itens das seguintes etapas: {etapas_str}. "
        f"Gere de 3 a 5 itens de checklist altamente relevantes e especificos "
        f"para fiscalizacao deste sistema pelo proprietario leigo."
    )

    providers = [
        ("Gemini", _gerar_itens_gemini),
        ("OpenAI", _gerar_itens_openai),
    ]
    last_error = None
    for name, func in providers:
        try:
            result = func(query)
            # Normaliza se veio no novo formato (checklist[])
            if "checklist" in result and "itens" not in result:
                result = _normalizar_fase2(result)
            logger.info("Fase 2 (%s) concluida via %s", caracteristica_id, name)
            return result
        except Exception as exc:
            logger.warning("Fase 2 (%s) falhou via %s: %s", caracteristica_id, name, exc)
            last_error = exc

    raise ValueError(
        f"Todos os providers falharam na Fase 2 para {caracteristica_id}. "
        f"Ultimo erro: {last_error}"
    )


# ─── Enriquecimento unitario de item padrao ─────────────────────────────────

ENRICH_PROMPT_TEMPLATE = """\
Voce e um Auditor de Obras de Alto Padrao e Especialista em Normas Tecnicas (ABNT/NR).
Analise este item de checklist de obra no contexto dos documentos do projeto \
e enriqueca com orientacoes praticas para o PROPRIETARIO leigo.

Item: {titulo}
Descricao: {descricao}
Etapa: {etapa_nome}

Documentos do projeto:
{contexto_docs}

DIRETRIZES:
1. O proprietario NAO e engenheiro. Traduza jargao para impacto pratico.
2. Cada orientacao deve ser uma acao que o proprietario consiga fazer sozinho.
3. Informe a Norma Tecnica (ABNT/NR) de referencia. Se nao houver, \
indique "Boas praticas de engenharia".
4. NUNCA apresente como parecer tecnico.

FORMATO DE RESPOSTA (JSON obrigatorio):
{{
  "severidade": "alto" | "medio" | "baixo",
  "traducao_leigo": "explicacao simples para proprietario leigo (max 200 chars)",
  "dado_projeto": {{
    "descricao": "o que este item representa no projeto (max 150 chars)",
    "especificacao": "especificacao tecnica com VALORES CONCRETOS do projeto. \
Se projeto nao detalha, use minimo normativo.",
    "fonte": "onde encontrar no projeto (ex: 'Planta Estrutural - Folha 3')",
    "valor_referencia": "valor numerico ou descritivo de referencia"
  }},
  "verificacoes": [
    {{
      "instrucao": "instrucao simples de verificacao (max 100 chars)",
      "tipo": "medicao | visual | documento",
      "valor_esperado": "o que esperar",
      "como_medir": "como realizar a verificacao na pratica (max 150 chars)"
    }}
  ],
  "pergunta_engenheiro": {{
    "contexto": "contexto para o engenheiro (max 150 chars)",
    "pergunta": "pergunta educada e direta para mandar no WhatsApp do engenheiro (max 150 chars)",
    "tom": "colaborativo",
    "resposta_esperada": "o que o proprietario deve esperar ouvir para saber que o profissional domina o assunto"
  }},
  "norma_referencia": "norma ABNT/NBR aplicavel ou 'Boas praticas de engenharia'",
  "documentos_a_exigir": ["nome do laudo, ART ou certificado"],
  "confianca": 0-100,
  "como_verificar": "instrucao pratica em 1-2 frases de COMO o proprietario verifica este item",
  "medidas_minimas": "exigencia normativa concreta (dimensoes, espessuras, inclinacoes) ou null",
  "explicacao_leigo": "explicacao do que acontece se der errado — impacto pratico (max 200 chars)"
}}

Retorne SOMENTE o JSON, sem markdown, sem texto adicional."""


def _enriquecer_claude(prompt: str) -> dict:
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY nao configurada")
    client = anthropic.Anthropic(api_key=api_key)
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )
    text = response.content[0].text if response.content else ""
    if not text:
        raise ValueError("Claude nao retornou resposta")
    return json.loads(clean_json_response(text))


def _enriquecer_openai(prompt: str) -> dict:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY nao configurada")
    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )
    text = response.choices[0].message.content or ""
    if not text:
        raise ValueError("OpenAI nao retornou resposta")
    return json.loads(clean_json_response(text))


def _enriquecer_gemini(prompt: str) -> dict:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY nao configurada")
    import google.generativeai as genai
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")
    response = model.generate_content(prompt)
    text = response.text
    if not text:
        raise ValueError("Gemini nao retornou resposta")
    return json.loads(clean_json_response(text))


def enriquecer_item_unico(
    titulo: str,
    descricao: str,
    etapa_nome: str,
    contexto_docs: str,
) -> dict:
    """Enriquece um item de checklist padrao com analise IA.

    Cadeia de fallback: Gemini -> OpenAI -> Claude.
    Retorna dict com campos dos 3 blocos de orientacao.
    """
    prompt = ENRICH_PROMPT_TEMPLATE.format(
        titulo=titulo,
        descricao=descricao or "Sem descricao",
        etapa_nome=etapa_nome,
        contexto_docs=contexto_docs[:8000] if contexto_docs else "Nenhum documento analisado",
    )

    providers = [
        ("Gemini", _enriquecer_gemini),
        ("OpenAI", _enriquecer_openai),
        ("Claude", _enriquecer_claude),
    ]
    last_error = None
    for name, func in providers:
        try:
            result = func(prompt)
            logger.info("Enriquecimento de '%s' via %s", titulo[:40], name)
            return result
        except Exception as exc:
            logger.warning("Enriquecimento de '%s' falhou via %s: %s", titulo[:40], name, exc)
            last_error = exc

    raise ValueError(f"Todos os providers falharam para enriquecer '{titulo[:40]}'. Ultimo: {last_error}")


# ─── Pipeline SSE Streaming ─────────────────────────────────────────────────

def gerar_checklist_stream(
    pdfs: list[tuple[bytes, str]],
    localizacao: Optional[str] = None,
) -> Generator[str, None, None]:
    """
    Pipeline incremental que yield eventos SSE conforme processa cada pagina.

    Eventos emitidos:
    - step: mudanca de fase no stepper (step=1..4)
    - page: progresso de pagina (current, total, doc)
    - caracteristica: nova caracteristica identificada
    - itens: itens gerados para uma caracteristica
    - error: erro parcial (nao interrompe pipeline)
    - done: pipeline concluido com resumo
    """
    aviso_legal = (
        "Esta analise e informativa e NAO substitui parecer tecnico "
        "de engenheiro ou arquiteto habilitado. Itens marcados como "
        "'requer validacao profissional' exigem avaliacao de "
        "engenheiro ou arquiteto antes da execucao."
    )

    # ─── Step 1: Extraindo PDFs ──────────────────────────────────────────
    yield _sse_event("step", {"step": 1, "label": "Extraindo paginas dos PDFs..."})

    # Contar total de paginas
    total_pages = 0
    pdf_page_counts: list[int] = []
    for pdf_bytes, nome in pdfs:
        count = contar_paginas(pdf_bytes)
        pdf_page_counts.append(count)
        total_pages += count
        logger.info("PDF '%s': %d paginas", nome, count)

    yield _sse_event("page", {"current": 0, "total": total_pages, "doc": ""})

    # ─── Step 2: Analisando projeto ──────────────────────────────────────
    yield _sse_event("step", {"step": 2, "label": "Analisando projeto com IA..."})

    caracteristicas_encontradas: dict[str, dict] = {}  # id -> carac data
    resumos_paginas: list[str] = []
    global_page = 0

    for pdf_idx, (pdf_bytes, nome) in enumerate(pdfs):
        num_pages = pdf_page_counts[pdf_idx]

        for page_idx in range(num_pages):
            global_page += 1
            page_label = f"{nome} - Pagina {page_idx + 1}"

            yield _sse_event("page", {
                "current": global_page,
                "total": total_pages,
                "doc": nome,
            })

            try:
                # Extrair e analisar uma pagina de cada vez (economiza memoria)
                img_b64, page_num = extrair_pagina_individual(pdf_bytes, page_idx)
                resultado = analisar_pagina(img_b64, page_label)
                del img_b64  # libera memoria

                resumo = resultado.get("resumo_pagina", "")
                if resumo:
                    resumos_paginas.append(f"[p{global_page}] {resumo}")

                # Verificar caracteristicas novas (filtrar confianca < 70)
                for carac in resultado.get("caracteristicas", []):
                    carac_id = carac.get("id", "")
                    confianca = carac.get("confianca", 0)
                    if not carac_id or carac_id in caracteristicas_encontradas:
                        continue
                    if confianca < 70:
                        logger.info("Caracteristica '%s' descartada (confianca=%d < 70)", carac_id, confianca)
                        continue

                    caracteristicas_encontradas[carac_id] = carac
                    yield _sse_event("caracteristica", {
                        "id": carac_id,
                        "nome": carac.get("nome_legivel", carac_id),
                        "confianca": carac.get("confianca", 0),
                        "pagina": global_page,
                    })

                    # ─── Step 3: Gerar itens para esta caracteristica ────────
                    yield _sse_event("step", {
                        "step": 3,
                        "label": f"Gerando checklist para {carac.get('nome_legivel', carac_id)}...",
                    })

                    etapas_alvo = CARACTERISTICA_ETAPA_MAP.get(
                        carac_id, ["Acabamentos"]
                    )

                    try:
                        itens_resultado = gerar_itens_para_caracteristica(
                            caracteristica_id=carac_id,
                            caracteristica_nome=carac.get("nome_legivel", carac_id),
                            descricao_no_projeto=carac.get("descricao_no_projeto", ""),
                            etapas_alvo=etapas_alvo,
                            localizacao=localizacao,
                        )
                        itens = itens_resultado.get("itens", [])
                        for item in itens:
                            item["caracteristica_origem"] = carac_id

                        yield _sse_event("itens", {
                            "caracteristica": carac_id,
                            "introducao": itens_resultado.get("introducao_ao_proprietario", ""),
                            "itens": itens,
                        })

                    except Exception as exc:
                        logger.error("Erro ao gerar itens para %s: %s", carac_id, exc)
                        yield _sse_event("error", {
                            "message": f"Erro ao gerar itens para {carac.get('nome_legivel', carac_id)}: {exc}",
                            "recoverable": True,
                        })

                    # Volta ao step 2 se ainda tem paginas
                    if global_page < total_pages:
                        yield _sse_event("step", {
                            "step": 2,
                            "label": "Analisando projeto com IA...",
                        })

            except Exception as exc:
                logger.error("Erro ao analisar %s: %s", page_label, exc)
                yield _sse_event("error", {
                    "message": f"Erro ao analisar {page_label}: {exc}",
                    "recoverable": True,
                })

    # ─── Step 4: Concluido ───────────────────────────────────────────────
    yield _sse_event("step", {"step": 4, "label": "Concluido!"})

    resumo_projeto = "; ".join(resumos_paginas[:5]) if resumos_paginas else ""

    yield _sse_event("done", {
        "resumo_projeto": resumo_projeto,
        "total_caracteristicas": len(caracteristicas_encontradas),
        "caracteristicas": list(caracteristicas_encontradas.keys()),
        "aviso_legal": aviso_legal,
    })


# ─── Processamento em Background ────────────────────────────────────────────

def processar_checklist_background(
    log_id: UUID,
    projetos_info: list[tuple[str, str, str]],  # (arquivo_url, arquivo_nome, doc_id)
    localizacao: Optional[str],
    database_url: str,
    bucket: str,
) -> None:
    """
    Runs the full checklist pipeline in a background thread.
    Downloads PDFs inside the thread to avoid blocking the HTTP handler.
    Uses shared DB engine (threads cannot share SQLModel sessions, but can share engines).
    Saves results incrementally to ChecklistGeracaoItem.
    Updates ChecklistGeracaoLog with progress and final status.
    """
    from sqlmodel import Session
    from .models import ChecklistGeracaoLog, ChecklistGeracaoItem
    from .storage import download_by_url, extract_object_key
    from .db import engine

    # Download PDFs here (inside thread) so the HTTP handler returns immediately
    pdfs: list[tuple[bytes, str, str]] = []  # (pdf_bytes, nome, doc_id)
    for arquivo_url, arquivo_nome, doc_id in projetos_info:
        object_key = extract_object_key(arquivo_url, bucket)
        pdf_bytes = download_by_url(arquivo_url, bucket, object_key)
        pdfs.append((pdf_bytes, arquivo_nome, doc_id))

    try:
        # Count total pages
        total_pages = 0
        pdf_page_counts: list[int] = []
        for pdf_bytes, nome, _doc_id in pdfs:
            count = contar_paginas(pdf_bytes)
            pdf_page_counts.append(count)
            total_pages += count

        with Session(engine) as session:
            log = session.get(ChecklistGeracaoLog, log_id)
            if log:
                log.total_paginas = total_pages
                log.total_docs_analisados = len(pdfs)
                log.updated_at = datetime.now(timezone.utc)
                session.add(log)
                session.commit()

        # Process pages
        caracteristicas_encontradas: dict[str, dict] = {}
        resumos_paginas: list[str] = []
        global_page = 0
        total_itens = 0

        for pdf_idx, (pdf_bytes, nome, current_doc_id) in enumerate(pdfs):
            num_pages = pdf_page_counts[pdf_idx]

            for page_idx in range(num_pages):
                global_page += 1
                page_label = f"{nome} - Pagina {page_idx + 1}"

                try:
                    img_b64, page_num = extrair_pagina_individual(pdf_bytes, page_idx)
                    resultado = analisar_pagina(img_b64, page_label)
                    del img_b64

                    resumo = resultado.get("resumo_pagina", "")
                    if resumo:
                        resumos_paginas.append(f"[p{global_page}] {resumo}")

                    for carac in resultado.get("caracteristicas", []):
                        carac_id = carac.get("id", "")
                        confianca = carac.get("confianca", 0)
                        if not carac_id or carac_id in caracteristicas_encontradas:
                            continue
                        if confianca < 70:
                            logger.info("BG: Caracteristica '%s' descartada (confianca=%d < 70)", carac_id, confianca)
                            continue

                        caracteristicas_encontradas[carac_id] = carac

                        etapas_alvo = CARACTERISTICA_ETAPA_MAP.get(
                            carac_id, ["Acabamentos"]
                        )

                        try:
                            itens_resultado = gerar_itens_para_caracteristica(
                                caracteristica_id=carac_id,
                                caracteristica_nome=carac.get("nome_legivel", carac_id),
                                descricao_no_projeto=carac.get("descricao_no_projeto", ""),
                                etapas_alvo=etapas_alvo,
                                localizacao=localizacao,
                            )
                            itens = itens_resultado.get("itens", [])

                            # Save items to DB incrementally
                            with Session(engine) as session:
                                for item_data in itens:
                                    item = ChecklistGeracaoItem(
                                        log_id=log_id,
                                        etapa_nome=item_data.get("etapa_nome", ""),
                                        titulo=item_data.get("titulo", ""),
                                        descricao=item_data.get("descricao", ""),
                                        norma_referencia=item_data.get("norma_referencia"),
                                        critico=bool(item_data.get("critico", False)),
                                        risco_nivel=item_data.get("risco_nivel", "baixo"),
                                        requer_validacao_profissional=bool(
                                            item_data.get("requer_validacao_profissional", False)
                                        ),
                                        confianca=int(item_data.get("confianca", 0)),
                                        como_verificar=item_data.get("como_verificar", ""),
                                        medidas_minimas=item_data.get("medidas_minimas"),
                                        explicacao_leigo=item_data.get("explicacao_leigo", ""),
                                        caracteristica_origem=carac_id,
                                        projeto_doc_id=current_doc_id,
                                        projeto_doc_nome=nome,
                                        # 3 Camadas
                                        dado_projeto=json.dumps(item_data["dado_projeto"], ensure_ascii=False) if item_data.get("dado_projeto") else None,
                                        verificacoes=json.dumps(item_data["verificacoes"], ensure_ascii=False) if item_data.get("verificacoes") else None,
                                        pergunta_engenheiro=json.dumps(item_data["pergunta_engenheiro"], ensure_ascii=False) if item_data.get("pergunta_engenheiro") else None,
                                        documentos_a_exigir=json.dumps(item_data["documentos_a_exigir"], ensure_ascii=False) if item_data.get("documentos_a_exigir") else None,
                                    )
                                    session.add(item)
                                    total_itens += 1
                                session.commit()

                        except Exception as exc:
                            logger.error("Erro ao gerar itens para %s: %s", carac_id, exc)

                except Exception as exc:
                    logger.error("Erro ao analisar %s: %s", page_label, exc)

                # Update progress
                with Session(engine) as session:
                    log = session.get(ChecklistGeracaoLog, log_id)
                    if log:
                        log.paginas_processadas = global_page
                        log.caracteristicas_identificadas = json.dumps(
                            list(caracteristicas_encontradas.keys())
                        )
                        log.total_itens_sugeridos = total_itens
                        log.updated_at = datetime.now(timezone.utc)
                        session.add(log)
                        session.commit()

        # Mark as completed
        resumo_projeto = "; ".join(resumos_paginas[:5]) if resumos_paginas else ""
        with Session(engine) as session:
            log = session.get(ChecklistGeracaoLog, log_id)
            if log:
                log.status = "concluido"
                log.resumo_geral = resumo_projeto
                log.aviso_legal = (
                    "Esta analise e informativa e NAO substitui parecer tecnico "
                    "de engenheiro ou arquiteto habilitado."
                )
                log.updated_at = datetime.now(timezone.utc)
                session.add(log)
                session.commit()

    except Exception as exc:
        logger.error("Erro fatal no background checklist: %s", exc)
        try:
            with Session(engine) as session:
                log = session.get(ChecklistGeracaoLog, log_id)
                if log:
                    log.status = "erro"
                    log.erro_detalhe = str(exc)
                    log.updated_at = datetime.now(timezone.utc)
                    session.add(log)
                    session.commit()
        except Exception:
            logger.error("Falha ao salvar erro no log %s", log_id)
