"""
Serviço de análise de documentos e extração de detalhamento.

Extrai a lógica de negócio do router de documentos (ARQ-01):
- Análise de IA em background (riscos)
- Conversão de riscos em itens de checklist
- Extração de detalhamento (cômodos/m²) via vision AI
"""

import json
import logging
import os
from datetime import datetime, timezone
from uuid import UUID

from sqlmodel import Session, select

from ..ai_providers import call_vision_with_fallback, get_document_vision_chain
from ..documentos import analisar_documento
from ..enums import ProjetoDocStatus
from ..helpers import _RISCO_ETAPA_KEYWORDS, ETAPAS_PADRAO
from ..models import (
    ChecklistItem, Etapa, Obra, ObraDetalhamento, ProjetoDoc, Risco,
)
from ..pdf_utils import extrair_paginas_como_imagens
from ..storage import download_by_url, extract_object_key

logger = logging.getLogger(__name__)


# ─── Análise de documento (background) ──────────────────────────────────────


def analisar_documento_e_persistir(session: Session, projeto_id: UUID) -> None:
    """Executa análise de IA sobre um ProjetoDoc e persiste riscos encontrados.

    Args:
        session: Sessão do banco de dados.
        projeto_id: ID do ProjetoDoc a analisar.
    """
    projeto = session.get(ProjetoDoc, projeto_id)
    if not projeto:
        logger.error("Projeto %s nao encontrado para analise", projeto_id)
        return

    bucket = os.getenv("S3_BUCKET", "")
    try:
        object_key = extract_object_key(projeto.arquivo_url, bucket)
        pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
        if not pdf_bytes:
            raise ValueError("PDF vazio (0 bytes). Reenvie o documento.")
        resultado = analisar_documento(pdf_bytes, projeto.arquivo_nome)

        # Remove riscos anteriores se houver re-análise
        riscos_antigos = session.exec(
            select(Risco).where(Risco.projeto_id == projeto_id)
        ).all()
        for r in riscos_antigos:
            session.delete(r)

        # Persiste os novos riscos (formato "Anjo da Guarda")
        _persistir_riscos(session, projeto_id, resultado.get("riscos_e_alertas", []))

        projeto.resumo_geral = resultado.get("resumo_executivo")
        projeto.aviso_legal = resultado.get(
            "aviso_legal",
            "Esta análise é preventiva e educacional. Não substitui o acompanhamento técnico de um profissional com CREA/CAU.",
        )
        projeto.status = ProjetoDocStatus.CONCLUIDO
        projeto.updated_at = datetime.now(timezone.utc)
        session.add(projeto)
        session.commit()
        logger.info("Analise concluida para projeto %s", projeto_id)

    except Exception as exc:
        logger.error("Analise falhou para projeto %s: %s", projeto_id, exc)
        session.rollback()
        projeto = session.get(ProjetoDoc, projeto_id)
        if projeto:
            projeto.status = ProjetoDocStatus.ERRO
            projeto.erro_detalhe = "Falha na analise do documento"
            projeto.updated_at = datetime.now(timezone.utc)
            session.add(projeto)
            session.commit()


def _persistir_riscos(
    session: Session, projeto_id: UUID, riscos_data: list[dict]
) -> None:
    """Converte lista de riscos da IA em objetos Risco e salva no banco."""
    for risco_data in riscos_data:
        dado_projeto = risco_data.get("dado_projeto")
        verificacao = risco_data.get("verificacao_na_obra")
        mensagem_prof = risco_data.get("mensagem_para_o_profissional")
        documentos = risco_data.get("documento_para_exigir")
        severidade_raw = (risco_data.get("severidade") or "BAIXA").upper()
        risco = Risco(
            projeto_id=projeto_id,
            descricao=risco_data.get("descricao_tecnica", ""),
            severidade=severidade_raw,
            disciplina=risco_data.get("disciplina"),
            norma_referencia=risco_data.get("norma_referencia"),
            traducao_leigo=risco_data.get("traducao_para_leigo", ""),
            acao_proprietario=risco_data.get("acao_imediata", ""),
            documentos_a_exigir=json.dumps(documentos, ensure_ascii=False) if documentos else None,
            requer_validacao_profissional=severidade_raw == "ALTA",
            confianca=80,
            dado_projeto=json.dumps(dado_projeto, ensure_ascii=False) if dado_projeto else None,
            verificacoes=json.dumps(verificacao, ensure_ascii=False) if verificacao else None,
            pergunta_engenheiro=json.dumps(mensagem_prof, ensure_ascii=False) if mensagem_prof else None,
        )
        session.add(risco)


# ─── Aplicar riscos como checklist items ─────────────────────────────────────


def aplicar_riscos_como_itens(
    session: Session, obra_id: UUID, risco_ids: list[str]
) -> int:
    """Converte riscos selecionados em ChecklistItems nas etapas adequadas.

    Returns:
        Número de itens criados.
    """
    if not risco_ids:
        return 0

    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id)).all()
    if not etapas:
        from ..enums import EtapaStatus
        etapas = [
            Etapa(obra_id=obra_id, nome=nome, ordem=i + 1, status=EtapaStatus.PENDENTE.value)
            for i, nome in enumerate(ETAPAS_PADRAO)
        ]
        session.add_all(etapas)
        session.flush()

    etapa_map = {e.nome: e for e in etapas}
    etapa_fallback = etapa_map.get("Instalacoes e Acabamentos") or etapas[-1]

    obra_projeto_ids = set(
        p.id for p in session.exec(
            select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
        ).all()
    )

    criados = 0
    for rid in risco_ids:
        risco = session.get(Risco, UUID(rid))
        if not risco or risco.projeto_id not in obra_projeto_ids:
            continue

        etapa_alvo = _resolver_etapa_para_risco(risco, etapa_map, etapa_fallback)

        item = ChecklistItem(
            etapa_id=etapa_alvo.id,
            titulo=risco.descricao,
            descricao=risco.traducao_leigo,
            origem="ia",
            severidade=risco.severidade,
            traducao_leigo=risco.traducao_leigo,
            norma_referencia=risco.norma_referencia,
            dado_projeto=risco.dado_projeto,
            verificacoes=risco.verificacoes,
            pergunta_engenheiro=risco.pergunta_engenheiro,
            documentos_a_exigir=risco.documentos_a_exigir,
            confianca=risco.confianca,
            requer_validacao_profissional=risco.requer_validacao_profissional,
        )
        session.add(item)
        criados += 1

    session.commit()
    return criados


def _resolver_etapa_para_risco(risco: Risco, etapa_map: dict, fallback: Etapa) -> Etapa:
    """Determina a etapa mais adequada para um risco via keywords."""
    desc_lower = risco.descricao.lower()
    for keyword, etapa_nomes in _RISCO_ETAPA_KEYWORDS.items():
        if keyword in desc_lower:
            for nome in etapa_nomes:
                if nome in etapa_map:
                    return etapa_map[nome]
            break
    return fallback


# ─── Detalhamento da obra (cômodos + m²) ────────────────────────────────────


def _normalize_comodos(comodos: list, pe_direito: float = 2.70) -> None:
    """Normaliza nomes de campos legados e calcula campos derivados ausentes."""
    PERDA = 0.15
    MOLHADOS = ("BANHO", "BANH", "LAVABO", "WC", "COZINHA", "LAVANDERIA", "VARANDA GOURMET")
    for c in comodos:
        if c.get("area_liquida_m2") is None and c.get("area_m2") is not None:
            c["area_liquida_m2"] = c["area_m2"]
        area = c.get("area_liquida_m2")
        if not area:
            continue
        if c.get("estimativa_piso_com_sobra_m2") is None:
            c["estimativa_piso_com_sobra_m2"] = round(area * (1 + PERDA), 2)
        if c.get("area_molhada") is None:
            nome = (c.get("nome") or "").upper()
            c["area_molhada"] = any(w in nome for w in MOLHADOS)
        if c.get("estimativa_azulejo_parede_com_sobra_m2") is None and c.get("area_molhada"):
            perimetro_est = round(4 * (area ** 0.5), 2)
            area_parede = max(perimetro_est * pe_direito - 2.0, 0)
            c["estimativa_azulejo_parede_com_sobra_m2"] = round(area_parede * (1 + PERDA), 2)


def _extrair_detalhamento_vision_pagina(
    page: tuple[str, int], prompt: str
) -> dict | None:
    """Analisa uma página com vision AI para extrair detalhamento."""
    img_b64, page_num = page
    content_parts = [
        {"type": "image", "media_type": "image/jpeg", "data": img_b64},
        {"type": "text", "text": f"[Pagina {page_num}]\n\n{prompt}"},
    ]
    try:
        return call_vision_with_fallback(
            providers=get_document_vision_chain(),
            content_parts=content_parts,
            task_label=f"Detalhamento pagina {page_num}",
        )
    except ValueError:
        return None


def extrair_detalhamento_obra(
    session: Session,
    obra: Obra,
    pe_direito: float = 2.70,
) -> dict:
    """Extrai cômodos, metragens e quantitativos dos documentos da obra.

    Returns:
        Dict com comodos, area_total_m2, resumo_projeto, totais_estimados.

    Raises:
        ValueError: Se nenhum documento contiver planta com cômodos.
    """
    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra.id)
    ).all()
    if not docs:
        raise ValueError("Nenhum documento enviado.")

    prompt = _build_detalhamento_prompt(pe_direito)

    fonte_doc = None
    bucket = os.getenv("S3_BUCKET", "")
    merged_comodos: dict[str, dict] = {}
    resumo_projeto = None
    pe_direito_utilizado = None
    area_total_override = None
    found_any = False

    for d in docs:
        try:
            object_key = extract_object_key(d.arquivo_url, bucket)
            pdf_bytes = download_by_url(d.arquivo_url, bucket, object_key)
            pages = extrair_paginas_como_imagens(pdf_bytes, dpi=150, max_pages=10)
        except Exception as exc:
            logger.warning("Falha ao baixar PDF %s: %s", d.arquivo_nome, exc)
            continue

        if fonte_doc is None:
            fonte_doc = d

        for page in pages:
            page_result = _extrair_detalhamento_vision_pagina(page, prompt)
            if not page_result:
                continue
            page_comodos = page_result.get("comodos", [])
            if not page_comodos:
                continue
            logger.info(
                "Detalhamento encontrado na pagina %d do doc %s (%d comodos)",
                page[1], d.arquivo_nome, len(page_comodos),
            )
            found_any = True
            if not resumo_projeto:
                resumo_projeto = page_result.get("resumo_projeto")
            if not pe_direito_utilizado:
                pe_direito_utilizado = page_result.get("pe_direito_utilizado")
            if area_total_override is None and page_result.get("area_total_m2"):
                area_total_override = page_result.get("area_total_m2")

            _merge_comodos(merged_comodos, page_comodos)

    if not found_any:
        raise ValueError("Nenhuma planta com comodos/metragens encontrada nos documentos.")

    comodos = list(merged_comodos.values())
    _normalize_comodos(comodos, pe_direito=pe_direito)

    totais = {
        "total_pisos_m2": sum(c.get("estimativa_piso_com_sobra_m2") or 0 for c in comodos),
        "total_azulejos_m2": sum(c.get("estimativa_azulejo_parede_com_sobra_m2") or 0 for c in comodos),
    }
    area_total = area_total_override
    if area_total is None:
        area_total = sum(c.get("area_liquida_m2") or c.get("area_m2") or 0 for c in comodos) or None

    # Upsert detalhamento
    det = session.exec(
        select(ObraDetalhamento).where(ObraDetalhamento.obra_id == obra.id)
    ).first()
    payload = json.dumps(comodos, ensure_ascii=False)
    if det:
        det.comodos = payload
        det.area_total_m2 = area_total
        det.fonte_doc_id = fonte_doc.id if fonte_doc else None
        det.fonte_doc_nome = fonte_doc.arquivo_nome if fonte_doc else None
        det.updated_at = datetime.now(timezone.utc)
    else:
        det = ObraDetalhamento(
            obra_id=obra.id,
            comodos=payload,
            area_total_m2=area_total,
            fonte_doc_id=fonte_doc.id if fonte_doc else None,
            fonte_doc_nome=fonte_doc.arquivo_nome if fonte_doc else None,
        )
    session.add(det)

    if area_total:
        obra.area_m2 = area_total
        session.add(obra)

    session.commit()
    return {
        "comodos": comodos,
        "area_total_m2": area_total,
        "resumo_projeto": resumo_projeto,
        "pe_direito_utilizado": pe_direito_utilizado,
        "totais_estimados": totais,
        "fonte_doc_nome": fonte_doc.arquivo_nome if fonte_doc else None,
    }


def _merge_comodos(merged: dict[str, dict], page_comodos: list[dict]) -> None:
    """Merge cômodos de uma página no dict acumulado, deduplicando por nome."""
    for c in page_comodos:
        key = (c.get("nome") or "").strip().upper()
        if not key:
            continue
        if key not in merged:
            merged[key] = c
        else:
            existing = merged[key]
            for field in (
                "area_liquida_m2", "estimativa_piso_com_sobra_m2",
                "area_molhada", "estimativa_azulejo_parede_com_sobra_m2",
            ):
                if existing.get(field) is None and c.get(field) is not None:
                    existing[field] = c[field]
            for list_field in ("itens_hidraulicos_e_metais", "itens_eletricos_e_iluminacao"):
                existing_list = existing.get(list_field) or []
                new_list = c.get(list_field) or []
                combined = list(existing_list)
                for item in new_list:
                    if item not in combined:
                        combined.append(item)
                if combined:
                    existing[list_field] = combined


def _build_detalhamento_prompt(pe_direito: float) -> str:
    """Constrói o prompt de detalhamento para a IA vision."""
    return f"""Voce e um Engenheiro de Custos e Orcamentista senior, especialista em analise de projetos arquitetonicos, eletricos e hidraulicos.
Sua missao e analisar os documentos anexados e extrair um levantamento quantitativo detalhado e preciso, formatado para um proprietario de obra leigo.

INFORMACOES DE CONTEXTO:
- Altura do pe-direito considerada para areas molhadas: {pe_direito:.2f} metros.
- Taxa de perda/sobra para pisos e revestimentos: Adicionar 15% sobre a area liquida para recortes e quebras.

REGRAS DE EXTRACAO:
1. Identifique todos os comodos legiveis na planta.
2. Extraia a area (m2) de cada comodo. Se a area nao estiver escrita, mas houver cotas, estime a area aproximada.
3. Para TODOS os comodos, calcule a estimativa de piso (Area + 15%).
4. Para AREAS MOLHADAS (banheiros, cozinhas, lavanderias, varandas gourmet), calcule a estimativa de revestimento de parede (Perimetro estimado * pe-direito + 15%). Desconte uma area padrao para portas e janelas.
5. Liste os itens de acabamento essenciais identificados na planta para cada ambiente (ex: 1 bacia sanitaria, 2 cubas, 1 chuveiro, bancada de x metros).
6. Se houver projeto eletrico/luminotecnico anexo, conte as tomadas, interruptores e pontos de luz por ambiente.

REGRAS NUMERICAS:
- Leia EXATAMENTE os nomes e metragens escritos na planta (ex: "SUITE MASTER 12,87 m2")
- NAO invente comodos ou areas que nao estejam claramente escritos
- Use o formato brasileiro de numeros (virgula como decimal) convertido para ponto (ex: 12,87 -> 12.87)
- Se esta pagina NAO contem planta baixa com comodos/metragens, retorne {{"comodos": [], "area_total_m2": null}}

FORMATO DE SAIDA (Obrigatorio JSON):
{{
  "resumo_projeto": "Breve descricao do que foi identificado nas pranchas.",
  "pe_direito_utilizado": "{pe_direito:.2f} metros",
  "comodos": [
    {{
      "nome": "Nome do ambiente",
      "area_liquida_m2": 0.0,
      "estimativa_piso_com_sobra_m2": 0.0,
      "area_molhada": true,
      "estimativa_azulejo_parede_com_sobra_m2": 0.0,
      "itens_hidraulicos_e_metais": ["1 bacia sanitaria", "2 torneiras de bancada"],
      "itens_eletricos_e_iluminacao": ["4 tomadas duplas", "1 interruptor simples", "3 spots de LED"]
    }}
  ],
  "totais_estimados": {{
    "total_pisos_m2": 0.0,
    "total_azulejos_m2": 0.0
  }}
}}
Retorne APENAS o JSON valido."""
