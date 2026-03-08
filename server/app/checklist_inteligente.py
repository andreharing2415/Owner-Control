"""
Servico de geracao de checklist inteligente baseado nos documentos do projeto.

Pipeline incremental por pagina com SSE streaming:
1. Para cada pagina do PDF -> identifica caracteristicas
2. Para cada caracteristica NOVA -> gera itens de checklist com normas detalhadas
3. Envia resultados ao cliente via Server-Sent Events em tempo real

Cadeia de fallback para identificacao: Claude -> OpenAI -> Gemini
Cadeia de fallback para geracao: OpenAI (web search) -> Gemini

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
from datetime import datetime
from typing import Generator, Optional
from uuid import UUID

import anthropic
from openai import OpenAI

from .pdf_utils import extrair_pagina_individual, contar_paginas

logger = logging.getLogger(__name__)

# ─── Mapeamento de caracteristicas para etapas ──────────────────────────────

CARACTERISTICA_ETAPA_MAP: dict[str, list[str]] = {
    "piscina": [
        "Fundacoes e Estrutura",
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "ar_condicionado": [
        "Planejamento e Projeto",
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "elevador": [
        "Fundacoes e Estrutura",
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "aquecimento_solar": [
        "Alvenaria e Cobertura",
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "energia_solar_fotovoltaica": [
        "Alvenaria e Cobertura",
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "automacao_residencial": [
        "Planejamento e Projeto",
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "lareira": [
        "Alvenaria e Cobertura",
        "Instalacoes e Acabamentos",
    ],
    "churrasqueira": [
        "Alvenaria e Cobertura",
        "Instalacoes e Acabamentos",
    ],
    "adega": [
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "sauna": [
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "aquecimento_piso": [
        "Instalacoes e Acabamentos",
    ],
    "sistema_incendio": [
        "Planejamento e Projeto",
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "gas_encanado": [
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "cisterna_reuso": [
        "Preparacao do Terreno",
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "paisagismo_irrigacao": [
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "home_theater": [
        "Instalacoes e Acabamentos",
    ],
    "gerador": [
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
    "portao_automatico": [
        "Instalacoes e Acabamentos",
    ],
    "cerca_eletrica": [
        "Instalacoes e Acabamentos",
    ],
    "cftv": [
        "Instalacoes e Acabamentos",
        "Entrega e Pos-obra",
    ],
}


# ─── Prompt para analise de pagina individual ────────────────────────────────

PHASE1_PAGE_PROMPT = """\
Voce e um especialista em analise de projetos de construcao civil.

Analise esta UNICA pagina de um projeto de construcao e identifique \
TODAS as caracteristicas especiais e sistemas presentes.

REGRAS OBRIGATORIAS:
1. Identifique SOMENTE caracteristicas EXPLICITAMENTE mencionadas ou desenhadas
2. NAO especule sobre caracteristicas nao mencionadas
3. Para cada caracteristica, indique onde na pagina ela foi identificada
4. Indique nivel de confianca (0-100) para cada caracteristica

LISTA DE CARACTERISTICAS A BUSCAR:
- piscina (piscina, spa, espelho d'agua com sistema)
- ar_condicionado (HVAC, ar condicionado, climatizacao, split, VRF)
- elevador (elevador residencial, plataforma elevatoria)
- aquecimento_solar (aquecedor solar, placas de aquecimento, boiler solar)
- energia_solar_fotovoltaica (paineis fotovoltaicos, sistema on-grid, off-grid)
- automacao_residencial (domotica, automacao, smart home, KNX, Alexa)
- lareira (lareira, leira, forno a lenha interno)
- churrasqueira (churrasqueira, area gourmet com fogo)
- adega (adega climatizada, wine cellar)
- sauna (sauna seca, sauna umida)
- aquecimento_piso (piso aquecido, piso radiante)
- sistema_incendio (SPDA, sprinklers, sistema contra incendio, hidrantes)
- gas_encanado (gas encanado, gas natural, central de gas GLP)
- cisterna_reuso (cisterna, reuso de agua, captacao pluvial)
- paisagismo_irrigacao (irrigacao automatica, sistema de irrigacao)
- home_theater (home theater, sala de cinema, tratamento acustico)
- gerador (gerador, nobreak central, grupo gerador)
- portao_automatico (portao automatizado, portao eletrico)
- cerca_eletrica (cerca eletrica, alarme perimetral)
- cftv (cameras, CFTV, circuito fechado, vigilancia)

FORMATO DE RESPOSTA (JSON obrigatorio):
{
  "caracteristicas": [
    {
      "id": "piscina",
      "nome_legivel": "Piscina",
      "descricao_no_projeto": "onde e como aparece na pagina (max 200 chars)",
      "confianca": numero 0-100
    }
  ],
  "resumo_pagina": "descricao breve do conteudo desta pagina (max 150 chars)"
}

Se nenhuma caracteristica especial for encontrada, retorne:
{"caracteristicas": [], "resumo_pagina": "descricao do conteudo"}

Retorne SOMENTE o JSON, sem markdown, sem texto adicional."""


# ─── Prompt Fase 2: Geracao de itens (atualizado com normas explicativas) ────

PHASE2_SYSTEM_PROMPT = """\
Voce e um especialista em normas tecnicas brasileiras de construcao civil com \
foco em fiscalizacao de obras de alto padrao pelo proprietario.

Sua funcao e, dada uma CARACTERISTICA especifica de um projeto de construcao, \
gerar itens de checklist que o proprietario deve verificar durante a obra.

REGRAS OBRIGATORIAS:
1. Cada item deve ser uma ACAO CONCRETA que o proprietario pode verificar ou solicitar
2. Inclua a norma tecnica aplicavel (ABNT, NR, codigo de obras) quando houver
3. Escreva em linguagem SIMPLES e DIRETA para leigo
4. Indique COMO o proprietario deve verificar (o que olhar, o que perguntar, que documento pedir)
5. Classifique o risco: "alto" (seguranca/estrutural), "medio" (funcional), "baixo" (estetico/preventivo)
6. Itens de risco "alto" DEVEM ter requer_validacao_profissional: true
7. Distribua os itens nas etapas corretas da obra
8. Indique nivel de confianca (0-100) baseado na qualidade da fonte normativa
9. NUNCA apresente como parecer tecnico
10. Para cada item, inclua MEDIDAS MINIMAS exigidas pela norma e uma EXPLICACAO \
para leigo do que significa na pratica

As 6 etapas da obra sao:
- Planejamento e Projeto
- Preparacao do Terreno
- Fundacoes e Estrutura
- Alvenaria e Cobertura
- Instalacoes e Acabamentos
- Entrega e Pos-obra

FORMATO DE RESPOSTA (JSON obrigatorio):
{
  "caracteristica": "id da caracteristica",
  "itens": [
    {
      "etapa_nome": "nome exato da etapa (uma das 6 acima)",
      "titulo": "titulo curto do item de checklist (max 80 chars)",
      "descricao": "descricao detalhada: o que verificar, como verificar, que documento pedir (max 300 chars)",
      "norma_referencia": "norma aplicavel (ex: NBR 5410:2004) ou null",
      "critico": true | false,
      "risco_nivel": "alto" | "medio" | "baixo",
      "requer_validacao_profissional": true | false,
      "confianca": numero 0-100,
      "como_verificar": "instrucao pratica em 1-2 frases de COMO o proprietario verifica este item",
      "medidas_minimas": "exigencias normativas concretas. Ex: 'Cerca minima 1,10m de altura ao redor da piscina, alarme de acesso obrigatorio, capa de protecao quando nao em uso' ou null se nao houver",
      "explicacao_leigo": "explicacao em linguagem simples do POR QUE este item e importante e O QUE pode acontecer se nao for cumprido (max 200 chars)"
    }
  ]
}

Retorne SOMENTE o JSON, sem markdown, sem texto adicional."""


# ─── Funcoes auxiliares ──────────────────────────────────────────────────────

def _clean_json_response(text: str) -> str:
    """Remove blocos de markdown se presentes na resposta da IA."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        cleaned = (
            "\n".join(lines[1:-1])
            if lines[-1].strip() == "```"
            else "\n".join(lines[1:])
        )
    return cleaned


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
        model="claude-sonnet-4-6",
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
    return json.loads(_clean_json_response(text))


def _analisar_pagina_openai(img_b64: str, page_label: str) -> dict:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY nao configurada")

    client = OpenAI(api_key=api_key)
    response = client.chat.completions.create(
        model="gpt-4o",
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
    return json.loads(_clean_json_response(text))


def _analisar_pagina_gemini(img_b64: str, page_label: str) -> dict:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY nao configurada")

    import google.generativeai as genai
    from google.generativeai.types import content_types

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.0-flash")

    img_bytes = base64.standard_b64decode(img_b64)
    response = model.generate_content([
        f"[{page_label}]",
        content_types.to_part({"mime_type": "image/jpeg", "data": img_bytes}),
        PHASE1_PAGE_PROMPT,
    ])
    text = response.text
    if not text:
        raise ValueError("Gemini nao retornou resposta")
    return json.loads(_clean_json_response(text))


def analisar_pagina(img_b64: str, page_label: str) -> dict:
    """Analisa uma pagina individual com fallback chain: Claude -> OpenAI -> Gemini."""
    providers = [
        ("Claude", _analisar_pagina_claude),
        ("OpenAI", _analisar_pagina_openai),
        ("Gemini", _analisar_pagina_gemini),
    ]
    last_error = None
    for name, func in providers:
        try:
            result = func(img_b64, page_label)
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
        model="gpt-4o",
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
    return json.loads(_clean_json_response(output_text))


def _gerar_itens_gemini(query: str) -> dict:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY nao configurada")

    import google.generativeai as genai
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.0-flash")

    response = model.generate_content(
        f"{PHASE2_SYSTEM_PROMPT}\n\nConsulta: {query}"
    )

    output_text = response.text
    if not output_text:
        raise ValueError("Gemini nao retornou resposta valida")
    return json.loads(_clean_json_response(output_text))


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
        f"Gere itens de checklist para fiscalizacao de obra residencial de alto padrao "
        f"que possui {caracteristica_nome}. "
        f"Detalhes do projeto: {descricao_no_projeto}. "
        f"Localizacao{loc_str}. "
        f"Os itens devem ser distribuidos nas seguintes etapas: {etapas_str}. "
        f"Pesquise normas ABNT, NRs e regulamentacoes aplicaveis a {caracteristica_nome} "
        f"em construcao civil residencial brasileira. "
        f"Para cada item, inclua as MEDIDAS MINIMAS exigidas pela norma e uma "
        f"EXPLICACAO EM LINGUAGEM SIMPLES do por que e importante."
    )

    providers = [
        ("OpenAI", _gerar_itens_openai),
        ("Gemini", _gerar_itens_gemini),
    ]
    last_error = None
    for name, func in providers:
        try:
            result = func(query)
            logger.info("Fase 2 (%s) concluida via %s", caracteristica_id, name)
            return result
        except Exception as exc:
            logger.warning("Fase 2 (%s) falhou via %s: %s", caracteristica_id, name, exc)
            last_error = exc

    raise ValueError(
        f"Todos os providers falharam na Fase 2 para {caracteristica_id}. "
        f"Ultimo erro: {last_error}"
    )


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

                # Verificar caracteristicas novas
                for carac in resultado.get("caracteristicas", []):
                    carac_id = carac.get("id", "")
                    if not carac_id or carac_id in caracteristicas_encontradas:
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
                        carac_id, ["Instalacoes e Acabamentos"]
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
    projetos_info: list[tuple[str, str]],  # (arquivo_url, arquivo_nome)
    localizacao: Optional[str],
    database_url: str,
    bucket: str,
) -> None:
    """
    Runs the full checklist pipeline in a background thread.
    Downloads PDFs inside the thread to avoid blocking the HTTP handler.
    Creates its own DB session (threads cannot share SQLModel sessions).
    Saves results incrementally to ChecklistGeracaoItem.
    Updates ChecklistGeracaoLog with progress and final status.
    """
    from sqlmodel import Session, create_engine
    from .models import ChecklistGeracaoLog, ChecklistGeracaoItem
    from .storage import download_by_url, extract_object_key

    engine = create_engine(database_url, echo=False)

    # Download PDFs here (inside thread) so the HTTP handler returns immediately
    pdfs: list[tuple[bytes, str]] = []
    for arquivo_url, arquivo_nome in projetos_info:
        object_key = extract_object_key(arquivo_url, bucket)
        pdf_bytes = download_by_url(arquivo_url, bucket, object_key)
        pdfs.append((pdf_bytes, arquivo_nome))

    try:
        # Count total pages
        total_pages = 0
        pdf_page_counts: list[int] = []
        for pdf_bytes, nome in pdfs:
            count = contar_paginas(pdf_bytes)
            pdf_page_counts.append(count)
            total_pages += count

        with Session(engine) as session:
            log = session.get(ChecklistGeracaoLog, log_id)
            if log:
                log.total_paginas = total_pages
                log.total_docs_analisados = len(pdfs)
                log.updated_at = datetime.utcnow()
                session.add(log)
                session.commit()

        # Process pages
        caracteristicas_encontradas: dict[str, dict] = {}
        resumos_paginas: list[str] = []
        global_page = 0
        total_itens = 0

        for pdf_idx, (pdf_bytes, nome) in enumerate(pdfs):
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
                        if not carac_id or carac_id in caracteristicas_encontradas:
                            continue

                        caracteristicas_encontradas[carac_id] = carac

                        etapas_alvo = CARACTERISTICA_ETAPA_MAP.get(
                            carac_id, ["Instalacoes e Acabamentos"]
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
                        log.updated_at = datetime.utcnow()
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
                log.updated_at = datetime.utcnow()
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
                    log.updated_at = datetime.utcnow()
                    session.add(log)
                    session.commit()
        except Exception:
            logger.error("Falha ao salvar erro no log %s", log_id)
