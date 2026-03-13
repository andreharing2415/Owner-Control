"""Checklist Inteligente router — stream, iniciar, status, aplicar, historico, enriquecer."""

import json
import logging
import os
import threading
from datetime import datetime, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, Etapa, ChecklistItem, ProjetoDoc, Risco,
    ChecklistGeracaoLog, ChecklistGeracaoItem,
)
from ..schemas import (
    ChecklistItemRead, IniciarChecklistRequest,
    AplicarChecklistRequest, AplicarChecklistResponse,
    ChecklistGeracaoLogRead, ChecklistGeracaoItemRead,
    ChecklistGeracaoStatusRead,
)
from ..enums import ChecklistStatus
from ..auth import get_current_user
from ..subscription import get_plan_config, check_and_increment_usage, require_paid
from ..storage import download_by_url, extract_object_key
from ..checklist_inteligente import gerar_checklist_stream, processar_checklist_background, enriquecer_item_unico
from ..helpers import (
    _verify_obra_ownership, _verify_obra_access,
    _apply_enrichment,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["checklist_inteligente"])


@router.get("/api/obras/{obra_id}/checklist-inteligente/stream")
def stream_checklist_inteligente(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    SSE endpoint que gera checklist inteligente em tempo real.
    Processa pagina por pagina, emitindo eventos de progresso.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)

    projetos = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    if not projetos:
        raise HTTPException(
            status_code=400,
            detail="Nenhum documento de projeto enviado para esta obra. "
                   "Envie pelo menos um PDF antes de gerar o checklist inteligente.",
        )

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    pdfs: list[tuple[bytes, str]] = []
    for projeto in projetos:
        object_key = extract_object_key(projeto.arquivo_url, bucket)
        pdf_bytes = download_by_url(projeto.arquivo_url, bucket, object_key)
        pdfs.append((pdf_bytes, projeto.arquivo_nome))

    return StreamingResponse(
        gerar_checklist_stream(pdfs=pdfs, localizacao=obra.localizacao),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@router.post(
    "/api/obras/{obra_id}/checklist-inteligente/iniciar",
    response_model=ChecklistGeracaoLogRead,
)
def iniciar_checklist_inteligente(
    obra_id: UUID,
    payload: IniciarChecklistRequest | None = None,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Inicia o processamento do checklist inteligente em background.
    Retorna imediatamente o log_id para acompanhamento.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)
    config = get_plan_config(current_user)
    check_and_increment_usage(
        session, current_user.id, "checklist_inteligente",
        config["checklist_inteligente_lifetime_limit"],
        period="lifetime",
    )

    existing = session.exec(
        select(ChecklistGeracaoLog)
        .where(ChecklistGeracaoLog.obra_id == obra_id)
        .where(ChecklistGeracaoLog.status == "processando")
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail="Ja existe um processamento em andamento para esta obra.",
        )

    projetos = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    if not projetos:
        raise HTTPException(
            status_code=400,
            detail="Nenhum documento de projeto enviado para esta obra. "
                   "Envie pelo menos um PDF antes de gerar o checklist inteligente.",
        )

    selected_ids = payload.projeto_ids if payload else None
    if selected_ids:
        selected_uuids = {UUID(str(pid)) for pid in selected_ids}
        projetos = [p for p in projetos if p.id in selected_uuids]
        if not projetos:
            raise HTTPException(status_code=400, detail="Nenhum documento selecionado encontrado.")

    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        raise HTTPException(status_code=500, detail="S3_BUCKET nao configurado")

    projetos_info = [(p.arquivo_url, p.arquivo_nome, str(p.id)) for p in projetos]

    log = ChecklistGeracaoLog(
        obra_id=obra_id,
        status="processando",
        total_docs_analisados=len(projetos),
    )
    session.add(log)
    session.commit()
    session.refresh(log)

    thread = threading.Thread(
        target=processar_checklist_background,
        args=(log.id, projetos_info, obra.localizacao, "", bucket),
        daemon=True,
    )
    thread.start()

    return log


@router.get(
    "/api/obras/{obra_id}/checklist-inteligente/{log_id}/status",
    response_model=ChecklistGeracaoStatusRead,
)
def status_checklist_inteligente(
    obra_id: UUID,
    log_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Retorna o status atual do processamento e os itens ja gerados.
    Frontend faz polling neste endpoint.
    """
    _verify_obra_ownership(obra_id, current_user, session)

    log = session.get(ChecklistGeracaoLog, log_id)
    if not log or log.obra_id != obra_id:
        raise HTTPException(status_code=404, detail="Log de geracao nao encontrado")

    itens = session.exec(
        select(ChecklistGeracaoItem)
        .where(ChecklistGeracaoItem.log_id == log_id)
        .order_by(ChecklistGeracaoItem.created_at)
    ).all()

    return ChecklistGeracaoStatusRead(
        log=ChecklistGeracaoLogRead.model_validate(log),
        itens=[ChecklistGeracaoItemRead.model_validate(i) for i in itens],
    )


@router.post(
    "/api/obras/{obra_id}/checklist-inteligente/aplicar",
    response_model=AplicarChecklistResponse,
)
def aplicar_checklist_inteligente(
    obra_id: UUID,
    payload: AplicarChecklistRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> AplicarChecklistResponse:
    """
    Aplica os itens selecionados pelo usuario ao checklist real.
    Etapa 2 do fluxo: gerar -> revisar -> aplicar.
    """
    obra = _verify_obra_ownership(obra_id, current_user, session)

    log = None
    if payload.log_id:
        log = session.get(ChecklistGeracaoLog, payload.log_id)
        if not log or log.obra_id != obra_id:
            raise HTTPException(status_code=404, detail="Log de geracao nao encontrado")

    etapas = session.exec(
        select(Etapa).where(Etapa.obra_id == obra_id)
    ).all()
    etapa_map: dict[str, UUID] = {e.nome: e.id for e in etapas}

    itens_criados: list[ChecklistItem] = []
    for item_data in payload.itens:
        etapa_id = etapa_map.get(item_data.etapa_nome)
        if not etapa_id:
            continue

        grupo = getattr(item_data, "grupo", "Geral") or "Geral"
        grupo = grupo.replace("_", " ").title()

        novo_item = ChecklistItem(
            etapa_id=etapa_id,
            titulo=item_data.titulo,
            descricao=item_data.descricao,
            critico=item_data.critico,
            norma_referencia=item_data.norma_referencia,
            origem="ia",
            status=ChecklistStatus.PENDENTE.value,
            grupo=grupo,
            ordem=getattr(item_data, "ordem", 0),
            severidade=getattr(item_data, "severidade", None),
            traducao_leigo=getattr(item_data, "traducao_leigo", None),
            dado_projeto=getattr(item_data, "dado_projeto", None),
            verificacoes=getattr(item_data, "verificacoes", None),
            pergunta_engenheiro=getattr(item_data, "pergunta_engenheiro", None),
            documentos_a_exigir=getattr(item_data, "documentos_a_exigir", None),
            confianca=getattr(item_data, "confianca", None),
            requer_validacao_profissional=getattr(item_data, "requer_validacao_profissional", False),
            como_verificar=getattr(item_data, "como_verificar", None),
            medidas_minimas=getattr(item_data, "medidas_minimas", None),
            explicacao_leigo=getattr(item_data, "explicacao_leigo", None),
            projeto_doc_id=getattr(item_data, "projeto_doc_id", None),
            projeto_doc_nome=getattr(item_data, "projeto_doc_nome", None),
        )
        session.add(novo_item)
        itens_criados.append(novo_item)

    if log:
        log.total_itens_aplicados = len(itens_criados)
        log.updated_at = datetime.now(timezone.utc)
        session.add(log)

    session.commit()
    for item in itens_criados:
        session.refresh(item)

    return AplicarChecklistResponse(
        total_aplicados=len(itens_criados),
        itens_criados=[ChecklistItemRead.model_validate(i) for i in itens_criados],
    )


@router.get(
    "/api/obras/{obra_id}/checklist-inteligente/historico",
    response_model=List[ChecklistGeracaoLogRead],
)
def historico_checklist_inteligente(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[ChecklistGeracaoLog]:
    """Lista o historico de geracoes de checklist inteligente para a obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    return session.exec(
        select(ChecklistGeracaoLog)
        .where(ChecklistGeracaoLog.obra_id == obra_id)
        .order_by(ChecklistGeracaoLog.created_at.desc())
    ).all()


@router.post("/api/admin/migrar-riscos-para-checklist")
def migrar_riscos_para_checklist(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """One-time migration: converts Risco records into ChecklistItems."""
    if current_user.role != "admin" and current_user.role != "owner":
        raise HTTPException(status_code=403, detail="Sem permissao")

    riscos = session.exec(select(Risco)).all()
    migrados = 0

    for risco in riscos:
        projeto = session.get(ProjetoDoc, risco.projeto_id)
        if not projeto:
            continue

        etapas = session.exec(
            select(Etapa).where(Etapa.obra_id == projeto.obra_id)
        ).all()
        etapa_alvo = None
        for e in etapas:
            if e.nome == "Fundacoes e Estrutura":
                etapa_alvo = e
                break
        if not etapa_alvo and etapas:
            etapa_alvo = etapas[0]
        if not etapa_alvo:
            continue

        novo = ChecklistItem(
            etapa_id=etapa_alvo.id,
            titulo=risco.descricao[:120] if risco.descricao else "Risco importado",
            descricao=risco.descricao,
            critico=risco.severidade == "alto",
            norma_referencia=risco.norma_referencia,
            origem="ia",
            severidade=risco.severidade,
            traducao_leigo=risco.traducao_leigo,
            dado_projeto=risco.dado_projeto,
            verificacoes=risco.verificacoes,
            pergunta_engenheiro=risco.pergunta_engenheiro,
            documentos_a_exigir=risco.documentos_a_exigir,
            registro_proprietario=risco.registro_proprietario,
            resultado_cruzamento=risco.resultado_cruzamento,
            status_verificacao=risco.status_verificacao,
            confianca=risco.confianca,
            requer_validacao_profissional=risco.requer_validacao_profissional,
        )
        session.add(novo)
        migrados += 1

    session.commit()
    return {"migrados": migrados, "total_riscos": len(riscos)}


# ─── Enriquecimento IA ──────────────────────────────────────────────────────


def _enriquecer_items_background(
    item_data: list[dict],
    contexto: str,
) -> None:
    """Executa enriquecimento IA em background thread com session própria."""
    from ..db import engine

    with Session(engine) as bg_session:
        count = 0
        for data in item_data:
            try:
                enrichment = enriquecer_item_unico(
                    titulo=data["titulo"],
                    descricao=data["descricao"],
                    etapa_nome=data["etapa_nome"],
                    contexto_docs=contexto,
                )
                item = bg_session.get(ChecklistItem, data["item_id"])
                if item:
                    _apply_enrichment(item, enrichment)
                    bg_session.add(item)
                    count += 1
            except Exception as e:
                logger.warning(f"Falha ao enriquecer item {data['item_id']}: {e}")
        bg_session.commit()
        logger.info(f"Enriquecimento background concluído: {count}/{len(item_data)} itens")


@router.post("/api/checklist-items/{item_id}/enriquecer", response_model=ChecklistItemRead)
def enriquecer_item(
    item_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Enriquece um item de checklist padrão com análise IA (3 blocos)."""
    item = session.get(ChecklistItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item nao encontrado")

    etapa = session.get(Etapa, item.etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")

    _verify_obra_access(etapa.obra_id, current_user, session)

    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == etapa.obra_id)
    ).all()
    doc_parts = []
    for d in docs:
        if d.resumo_geral:
            doc_parts.append(f"[{d.arquivo_nome}] {d.resumo_geral}")
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == d.id)
        ).all()
        for r in riscos:
            doc_parts.append(f"  Risco ({r.severidade}): {r.descricao}")
    contexto = "\n".join(doc_parts)

    enrichment = enriquecer_item_unico(
        titulo=item.titulo,
        descricao=item.descricao or "",
        etapa_nome=etapa.nome,
        contexto_docs=contexto,
    )

    _apply_enrichment(item, enrichment)
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@router.post("/api/etapas/{etapa_id}/enriquecer-checklist")
def enriquecer_checklist_etapa(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Enriquece em batch todos os itens padrão de uma etapa com IA (background)."""
    etapa = session.get(Etapa, etapa_id)
    if not etapa:
        raise HTTPException(status_code=404, detail="Etapa nao encontrada")

    _verify_obra_access(etapa.obra_id, current_user, session)

    items = session.exec(
        select(ChecklistItem)
        .where(ChecklistItem.etapa_id == etapa_id)
        .where(ChecklistItem.origem == "padrao")
        .where(ChecklistItem.dado_projeto.is_(None))
    ).all()

    if not items:
        return {"enriquecidos": 0, "total": 0, "mensagem": "Todos os itens ja foram enriquecidos."}

    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == etapa.obra_id)
    ).all()
    doc_parts = []
    for d in docs:
        if d.resumo_geral:
            doc_parts.append(f"[{d.arquivo_nome}] {d.resumo_geral}")
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == d.id)
        ).all()
        for r in riscos:
            doc_parts.append(f"  Risco ({r.severidade}): {r.descricao}")
    contexto = "\n".join(doc_parts)

    item_data = [
        {"item_id": item.id, "titulo": item.titulo, "descricao": item.descricao or "", "etapa_nome": etapa.nome}
        for item in items
    ]

    thread = threading.Thread(
        target=_enriquecer_items_background,
        args=(item_data, contexto),
        daemon=True,
    )
    thread.start()

    return {"enriquecidos": 0, "total": len(items), "mensagem": f"Enriquecimento de {len(items)} itens iniciado em background."}


@router.post("/api/obras/{obra_id}/enriquecer-todos")
def enriquecer_todos_checklist(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_paid),
):
    """Enriquece em batch todos os itens padrão de TODAS as etapas da obra (background)."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    etapas = session.exec(
        select(Etapa).where(Etapa.obra_id == obra_id)
    ).all()

    docs = session.exec(
        select(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    doc_parts = []
    for d in docs:
        if d.resumo_geral:
            doc_parts.append(f"[{d.arquivo_nome}] {d.resumo_geral}")
        riscos = session.exec(
            select(Risco).where(Risco.projeto_id == d.id)
        ).all()
        for r in riscos:
            doc_parts.append(f"  Risco ({r.severidade}): {r.descricao}")
    contexto = "\n".join(doc_parts)

    item_data = []
    for etapa in etapas:
        items = session.exec(
            select(ChecklistItem)
            .where(ChecklistItem.etapa_id == etapa.id)
            .where(ChecklistItem.origem == "padrao")
            .where(ChecklistItem.dado_projeto.is_(None))
        ).all()
        for item in items:
            item_data.append({
                "item_id": item.id,
                "titulo": item.titulo,
                "descricao": item.descricao or "",
                "etapa_nome": etapa.nome,
            })

    if not item_data:
        return {"enriquecidos": 0, "total": 0, "etapas": len(etapas), "mensagem": "Todos os itens ja foram enriquecidos."}

    thread = threading.Thread(
        target=_enriquecer_items_background,
        args=(item_data, contexto),
        daemon=True,
    )
    thread.start()

    return {"enriquecidos": 0, "total": len(item_data), "etapas": len(etapas), "mensagem": f"Enriquecimento de {len(item_data)} itens iniciado em background."}
