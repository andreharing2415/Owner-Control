"""
Pipeline de extração de elementos construtivos em duas passagens.

Phase 01 — AI-01: Documento vira elementos construtivos estruturados.

Passagem 1 (por página): Identifica elementos construtivos em cada página via vision AI.
Passagem 2 (consolidação): Consolida, deduplica e enriquece via text AI.

Resultado: lista de ElementoConstrutivo[] persistida em ProjetoDoc.elementos_extraidos.
"""

import json
import logging
import os
from datetime import datetime, timezone
from uuid import UUID

from sqlmodel import Session

from .ai_providers import (
    call_text_with_fallback,
    call_vision_with_fallback,
    get_document_vision_chain,
    get_schedule_text_chain,
)
from .models import ProjetoDoc
from .pdf_utils import extrair_paginas_como_imagens
from .storage import download_by_url, extract_object_key

logger = logging.getLogger(__name__)

# ─── Prompts ──────────────────────────────────────────────────────────────────

_PASSAGEM1_PROMPT = """Voce e um Engenheiro de Obras senior analisando uma prancha de projeto.
Identifique TODOS os elementos construtivos especificos presentes NESTA PAGINA.

Um elemento construtivo e qualquer item tecnico concreto: estrutura, instalacao, material, sistema ou componente
que devera ser executado ou fornecido na obra (ex: "Viga V1 - 20x40cm C25", "Tubulacao esgoto PVC 100mm",
"Quadro de distribuicao 40 disjuntores", "Porta de entrada 0.90x2.10m", "Laje pre-moldada h=16cm").

NAO inclua elementos genericos como "parede", "piso", "teto" sem especificacao tecnica.
Se a pagina for folha de rosto, lista de materiais ou sem elementos tecnicos, retorne lista vazia.

FORMATO DE RESPOSTA (JSON puro):
{
  "elementos": [
    {
      "categoria": "Estrutural | Eletrico | Hidraulico | Arquitetura | Outro",
      "nome": "Nome tecnico conciso do elemento",
      "descricao": "O que e este elemento e sua funcao (null se nao houver informacao)",
      "especificacao": "Materiais, dimensoes, normas citadas (null se ausente)",
      "localizacao": "Onde na obra este elemento se localiza (null se nao identificavel)",
      "pagina_referencia": <numero_da_pagina>,
      "prancha_referencia": "Titulo ou identificacao da prancha (null se ausente)",
      "confianca": <0-100>
    }
  ]
}
Retorne APENAS o JSON valido. Se nao houver elementos nesta pagina, retorne {"elementos": []}.
"""

_PASSAGEM2_PROMPT_TEMPLATE = """Voce e um Engenheiro de Obras senior consolidando a analise de um projeto.

Abaixo estao os elementos construtivos identificados pagina a pagina do documento '{arquivo_nome}'.
Sua tarefa e:
1. Eliminar duplicatas (mesmo elemento aparecendo em multiplas paginas)
2. Enriquecer descricoes com informacoes de paginas diferentes sobre o mesmo elemento
3. Corrigir categorizacoes incorretas
4. Manter apenas elementos que representam itens construtivos reais e especificos da OBRA

ELEMENTOS IDENTIFICADOS POR PAGINA:
{elementos_por_pagina}

REGRAS DE CONSOLIDACAO:
- Se o mesmo elemento aparece em 2+ paginas: mantenha apenas 1 entrada, enriquecida
- Priorize a pagina com mais informacao tecnica para preencher os campos
- Use a maior confianca entre as ocorrencias
- Elementos estruturais duplicados em planta e corte: manter como 1 entrada
- Remova elementos que sejam anotacoes textuais genericas, simbolos ou cotas sem nome de elemento

FORMATO DE RESPOSTA (JSON puro):
{{
  "elementos_consolidados": [
    {{
      "categoria": "Estrutural | Eletrico | Hidraulico | Arquitetura | Outro",
      "nome": "Nome tecnico conciso e preciso",
      "descricao": "Descricao consolidada do elemento e sua funcao",
      "especificacao": "Especificacao tecnica consolidada (materiais, dimensoes, normas)",
      "localizacao": "Localizacao na obra",
      "pagina_referencia": <pagina_principal>,
      "prancha_referencia": "Prancha principal",
      "confianca": <0-100>
    }}
  ]
}}
Retorne APENAS o JSON valido."""


# ─── Passagem 1: extração por página ─────────────────────────────────────────


def _extrair_elementos_pagina(
    pagina: tuple[str, int],
    arquivo_nome: str,
    providers: list,
) -> list[dict]:
    """Extrai elementos construtivos de uma única página via vision AI.

    Args:
        pagina: Tupla (base64_image, numero_pagina).
        arquivo_nome: Nome do arquivo para contexto nos logs.
        providers: Chain de providers vision AI.

    Returns:
        Lista de dicts com elementos identificados na página.
    """
    img_b64, page_num = pagina
    content_parts = [
        {"type": "image", "media_type": "image/jpeg", "data": img_b64},
        {"type": "text", "text": f"[Pagina {page_num} de '{arquivo_nome}']\n\n{_PASSAGEM1_PROMPT}"},
    ]
    try:
        resultado = call_vision_with_fallback(
            providers=providers,
            content_parts=content_parts,
            task_label=f"Extracao pagina {page_num}",
        )
        elementos = resultado.get("elementos", [])
        # Garante que pagina_referencia está preenchida
        for elem in elementos:
            if elem.get("pagina_referencia") is None:
                elem["pagina_referencia"] = page_num
        logger.info(
            "Pagina %d de '%s': %d elementos identificados",
            page_num, arquivo_nome, len(elementos),
        )
        return elementos
    except ValueError as exc:
        logger.warning(
            "Falha ao extrair pagina %d de '%s': %s",
            page_num, arquivo_nome, exc,
        )
        return []


# ─── Passagem 2: consolidação ────────────────────────────────────────────────


def _consolidar_elementos(
    elementos_por_pagina: list[list[dict]],
    arquivo_nome: str,
    providers: list,
) -> list[dict]:
    """Consolida elementos de todas as páginas via text AI.

    Args:
        elementos_por_pagina: Lista de listas, uma por página.
        arquivo_nome: Nome do arquivo para contexto.
        providers: Chain de providers text AI.

    Returns:
        Lista consolidada de elementos construtivos.
    """
    # Monta representação textual dos elementos por página
    linhas = []
    for i, elementos_pagina in enumerate(elementos_por_pagina):
        if not elementos_pagina:
            continue
        linhas.append(f"\n=== Pagina {i + 1} ===")
        for elem in elementos_pagina:
            linhas.append(json.dumps(elem, ensure_ascii=False))

    if not linhas:
        logger.info("Nenhum elemento extraido para consolidar em '%s'", arquivo_nome)
        return []

    prompt = _PASSAGEM2_PROMPT_TEMPLATE.format(
        arquivo_nome=arquivo_nome,
        elementos_por_pagina="\n".join(linhas),
    )

    try:
        resultado = call_text_with_fallback(
            providers=providers,
            prompt=prompt,
            max_tokens=8192,
            task_label=f"Consolidacao de elementos '{arquivo_nome}'",
        )
        consolidados = resultado.get("elementos_consolidados", [])
        logger.info(
            "'%s': %d elementos consolidados",
            arquivo_nome, len(consolidados),
        )
        return consolidados
    except ValueError as exc:
        logger.warning(
            "Falha na consolidacao de '%s': %s. Usando elementos brutos.",
            arquivo_nome, exc,
        )
        # Fallback: retorna elementos brutos de todas as páginas sem deduplicação
        todos = []
        for elementos_pagina in elementos_por_pagina:
            todos.extend(elementos_pagina)
        return todos


# ─── Função principal de extração ────────────────────────────────────────────


def extrair_elementos_construtivos(
    paginas: list[tuple[str, int]],
    arquivo_nome: str,
) -> list[dict]:
    """Pipeline de extração em duas passagens.

    Passagem 1: Extrai elementos de cada página via vision AI (paralelo conceitual, sequencial na implementação).
    Passagem 2: Consolida e deduplica elementos via text AI.

    Args:
        paginas: Lista de tuplas (base64_image, numero_pagina) do PDF.
        arquivo_nome: Nome do arquivo de projeto (para logs e contexto).

    Returns:
        Lista de dicts representando ElementoConstrutivo[].
    """
    vision_providers = get_document_vision_chain()
    text_providers = get_schedule_text_chain()

    logger.info(
        "Iniciando extracao em duas passagens: '%s' (%d paginas)",
        arquivo_nome, len(paginas),
    )

    # Passagem 1: por página
    elementos_por_pagina: list[list[dict]] = []
    for pagina in paginas:
        elementos_pagina = _extrair_elementos_pagina(pagina, arquivo_nome, vision_providers)
        elementos_por_pagina.append(elementos_pagina)

    total_bruto = sum(len(e) for e in elementos_por_pagina)
    logger.info(
        "Passagem 1 concluida: %d elementos brutos em %d paginas",
        total_bruto, len(paginas),
    )

    # Passagem 2: consolidação
    elementos_finais = _consolidar_elementos(elementos_por_pagina, arquivo_nome, text_providers)

    logger.info(
        "Passagem 2 concluida: %d elementos consolidados (de %d brutos)",
        len(elementos_finais), total_bruto,
    )

    return elementos_finais


# ─── Persistência no ProjetoDoc ───────────────────────────────────────────────


def extrair_e_persistir_elementos(session: Session, projeto_id: UUID) -> None:
    """Executa o pipeline de extração e persiste os elementos no ProjetoDoc.

    Esta função é chamada pelo router de documentos após análise de riscos,
    enriquecendo o ProjetoDoc com elementos construtivos estruturados.

    Args:
        session: Sessão de banco de dados.
        projeto_id: ID do ProjetoDoc a processar.
    """
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        logger.error("Projeto %s nao encontrado para extracao de elementos", projeto_id)
        return

    bucket = os.getenv("S3_BUCKET", "")
    try:
        object_key = extract_object_key(projeto.arquivo_url, bucket)
        pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
        if not pdf_bytes:
            logger.warning("PDF vazio para projeto %s — elementos nao extraidos", projeto_id)
            return

        paginas = extrair_paginas_como_imagens(pdf_bytes, dpi=150, max_pages=15)
        if not paginas:
            logger.warning("Nenhuma pagina extraida do PDF do projeto %s", projeto_id)
            return

        elementos = extrair_elementos_construtivos(paginas, projeto.arquivo_nome)

        projeto.elementos_extraidos = json.dumps(elementos, ensure_ascii=False)
        projeto.updated_at = datetime.now(timezone.utc)
        session.add(projeto)
        session.commit()

        logger.info(
            "Elementos persistidos para projeto %s: %d elementos",
            projeto_id, len(elementos),
        )

    except Exception as exc:
        logger.exception(
            "Falha ao extrair elementos do projeto %s: %s",
            projeto_id, exc,
        )
        # Não propaga erro — extração de elementos é enriquecimento, não bloqueia análise
