"""
Servico de analise de documentos de projeto via IA.

Fase 3 — Document AI.

Analise pagina por pagina com cadeia de fallback: Gemini -> Claude -> OpenAI.

Guardrails obrigatorios:
- Nunca apresentar como parecer tecnico ou opiniao profissional
- Indicar nivel de confianca em toda analise
- Riscos de alto nivel exigem recomendacao de validacao profissional
- Linguagem acessivel ao proprietario leigo
"""

import base64
import json
import logging
import os

import anthropic
from openai import OpenAI

from .pdf_utils import extrair_paginas_como_imagens
from .utils import clean_json_response

logger = logging.getLogger(__name__)

# ─── Prompt do sistema ────────────────────────────────────────────────────────

SYSTEM_PROMPT = """Voce e um Consultor de Obras e Gestor de Riscos atuando como o "Anjo da Guarda" de proprietarios de obras de alto padrao.
Sua funcao e analisar as pranchas de projeto anexadas e identificar inconsistencias, omissoes ou pontos criticos de atencao.

O usuario final e o PROPRIETARIO. Ele nao tem formacao tecnica. Ele usara seu relatorio para saber exatamente o que perguntar e o que cobrar dos profissionais contratados.

DIRETRIZES DE ANALISE:
1. Identifique riscos concretos baseados estritamente nos documentos fornecidos.
2. Traduza problemas complexos (ex: "falta de compatibilizacao estrutural") para o impacto real ("sua parede pode precisar ser quebrada depois").
3. Forneca perguntas prontas e polidas para o proprietario enviar ao engenheiro/arquiteto no WhatsApp.
4. Jamais atue como parecerista legal ou juridico.

REGRAS DO JSON:
- "disciplina": Classifique o risco em "Arquitetura", "Eletrica", "Hidraulica", "Estrutural" ou "Geral".
- "severidade": Use "ALTA" (Risco financeiro/seguranca grave), "MEDIA" (Retrabalho possivel), "BAIXA" (Dica de melhoria).
- "dado_projeto": Preencha apenas se a informacao estiver explicitamente escrita ou desenhada na prancha. Se for inferencia, retorne null.
- "verificacoes": Acoes fisicas que o proprietario pode fazer na obra com uma trena ou os proprios olhos.

FORMATO DE RESPOSTA OBRIGATORIO (JSON puro):
{
  "resumo_executivo": "Resumo em 2 linhas focado no que o proprietario precisa saber hoje.",
  "aviso_legal": "Esta analise e preventiva e educacional. Nao substitui o acompanhamento tecnico de um profissional com CREA/CAU.",
  "riscos_e_alertas": [
    {
      "disciplina": "Arquitetura | Eletrica | Hidraulica | Estrutural | Geral",
      "descricao_tecnica": "O que esta no projeto",
      "severidade": "ALTA" | "MEDIA" | "BAIXA",
      "traducao_para_leigo": "O que isso significa no seu bolso ou na sua rotina (max 250 caracteres).",
      "acao_imediata": "O que voce deve pedir hoje para a equipe tecnica.",
      "norma_referencia": "Nome da NBR/NR aplicavel (se houver)",
      "dado_projeto": {
        "elemento": "Ex: Ralo oculto banheiro master",
        "prancha_ou_fonte": "Ex: Projeto Hidraulico Folha 05",
        "especificacao_encontrada": "Ex: Tubo de 40mm"
      },
      "verificacao_na_obra": {
        "o_que_olhar": "Como o proprietario verifica visualmente",
        "ferramenta": "Olho nu | Trena | Nivel",
        "condicao_ideal": "Como deve estar para estar certo"
      },
      "mensagem_para_o_profissional": {
        "texto_whatsapp": "Sugestao de mensagem educada e colaborativa para copiar e colar para o engenheiro.",
        "resposta_que_voce_deve_ouvir": "O que o profissional deve responder para provar que tem a situacao sob controle."
      },
      "documento_para_exigir": ["Ex: ART de projeto", "Laudo de sondagem"]
    }
  ]
}
Retorne APENAS o objeto JSON."""


# ─── Funcoes auxiliares ──────────────────────────────────────────────────────


def _build_user_text(arquivo_nome: str, num_pages: int) -> str:
    return (
        f"{SYSTEM_PROMPT}\n\n"
        f"Analise TODAS as {num_pages} pranchas do documento de projeto "
        f"'{arquivo_nome}' acima. Examine cada prancha individualmente e "
        f"identifique todas as inconsistencias, omissoes e pontos criticos "
        f"de atencao relevantes para o proprietario da obra."
    )


# ─── Analise via Claude (pagina por pagina) ──────────────────────────────────

def _analisar_com_claude(paginas: list[tuple[str, int]], arquivo_nome: str) -> dict:
    """Analisa documento pagina por pagina via Claude Vision API."""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY nao configurada")

    client = anthropic.Anthropic(api_key=api_key)

    content_blocks: list[dict] = []
    for img_b64, page_num in paginas:
        content_blocks.append({
            "type": "text",
            "text": f"[Pagina {page_num}]",
        })
        content_blocks.append({
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": "image/png",
                "data": img_b64,
            },
        })

    content_blocks.append({
        "type": "text",
        "text": _build_user_text(arquivo_nome, len(paginas)),
    })

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[{"role": "user", "content": content_blocks}],
    )

    output_text = response.content[0].text if response.content else ""
    if not output_text:
        raise ValueError("Claude nao retornou resposta valida")

    return json.loads(clean_json_response(output_text))


# ─── Analise via OpenAI (pagina por pagina) ──────────────────────────────────

def _analisar_com_openai(paginas: list[tuple[str, int]], arquivo_nome: str) -> dict:
    """Analisa documento pagina por pagina via OpenAI GPT-4o Vision."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY nao configurada para fallback")

    client = OpenAI(api_key=api_key)

    content_parts: list[dict] = []
    for img_b64, page_num in paginas:
        content_parts.append({
            "type": "text",
            "text": f"[Pagina {page_num}]",
        })
        content_parts.append({
            "type": "image_url",
            "image_url": {"url": f"data:image/png;base64,{img_b64}"},
        })

    content_parts.append({
        "type": "text",
        "text": _build_user_text(arquivo_nome, len(paginas)),
    })

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": content_parts}],
        max_tokens=4096,
    )

    output_text = response.choices[0].message.content or ""
    if not output_text:
        raise ValueError("OpenAI nao retornou resposta valida")

    return json.loads(clean_json_response(output_text))


# ─── Analise via Gemini (pagina por pagina) ──────────────────────────────────

def _analisar_com_gemini(paginas: list[tuple[str, int]], arquivo_nome: str) -> dict:
    """Analisa documento pagina por pagina via Gemini Vision."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY nao configurada para fallback")

    import google.generativeai as genai
    from google.generativeai.types import content_types

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")

    parts = []
    for img_b64, page_num in paginas:
        parts.append(f"[Pagina {page_num}]")
        img_bytes = base64.standard_b64decode(img_b64)
        parts.append(content_types.to_part({"mime_type": "image/png", "data": img_bytes}))

    parts.append(_build_user_text(arquivo_nome, len(paginas)))

    response = model.generate_content(parts)

    output_text = response.text
    if not output_text:
        raise ValueError("Gemini nao retornou resposta valida")

    return json.loads(clean_json_response(output_text))


# ─── Funcao principal ────────────────────────────────────────────────────────

def analisar_documento(pdf_bytes: bytes, arquivo_nome: str) -> dict:
    """
    Analisa um PDF de projeto pagina por pagina.
    Cadeia de fallback: Gemini -> Claude -> OpenAI.

    Retorna dict com resumo_geral, aviso_legal e lista de riscos.
    """
    paginas = extrair_paginas_como_imagens(pdf_bytes)
    logger.info("Documento '%s': %d paginas extraidas para analise", arquivo_nome, len(paginas))

    providers = [
        ("Gemini", _analisar_com_gemini),
        ("Claude", _analisar_com_claude),
        ("OpenAI", _analisar_com_openai),
    ]
    last_error = None
    for name, func in providers:
        try:
            resultado = func(paginas, arquivo_nome)
            logger.info("Analise de documento concluida via %s", name)
            return resultado
        except Exception as exc:
            logger.warning("Analise de documento falhou via %s: %s", name, exc)
            last_error = exc

    raise ValueError(
        f"Todos os providers falharam na analise do documento. Ultimo erro: {last_error}"
    )
