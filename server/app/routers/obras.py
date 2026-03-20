"""Obras router — CRUD and PDF export."""

import logging
import os
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import func as sa_func
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, Etapa, ChecklistItem, OrcamentoEtapa, Despesa,
    ProjetoDoc, Risco, AlertaConfig, DeviceToken, AnaliseVisual, Achado,
    ChecklistGeracaoLog, ChecklistGeracaoItem, ObraConvite, ObraDetalhamento,
    Evidencia, AtividadeCronograma, ServicoNecessario, EtapaComentario,
)
from ..schemas import (
    ObraCreate, ObraRead, ObraDetailResponse, EtapaEnrichedRead, OkResponse,
)
from ..enums import EtapaStatus, ChecklistStatus
from ..auth import get_current_user
from ..subscription import check_obra_limit
from ..pdf import render_obra_pdf
from ..seed_checklists import get_itens_padrao
from ..helpers import ETAPAS_PADRAO, _verify_obra_ownership

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/obras", tags=["obras"])


@router.post("", response_model=ObraRead)
def criar_obra(
    payload: ObraCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> Obra:
    check_obra_limit(session, current_user)
    obra = Obra(user_id=current_user.id, **payload.model_dump())
    session.add(obra)
    session.commit()
    session.refresh(obra)

    if obra.tipo != "construcao":
        etapas = [
            Etapa(obra_id=obra.id, nome=nome, ordem=index + 1, status=EtapaStatus.PENDENTE.value)
            for index, nome in enumerate(ETAPAS_PADRAO)
        ]
        session.add_all(etapas)
        session.commit()
        for etapa in etapas:
            session.refresh(etapa)

        itens_seed: list[ChecklistItem] = []
        for etapa in etapas:
            for item_data in get_itens_padrao(etapa.nome):
                itens_seed.append(
                    ChecklistItem(
                        etapa_id=etapa.id,
                        titulo=item_data["titulo"],
                        descricao=item_data.get("descricao"),
                        critico=item_data.get("critico", False),
                        status=ChecklistStatus.PENDENTE.value,
                    )
                )
        if itens_seed:
            session.add_all(itens_seed)
            session.commit()

    return obra


@router.get("", response_model=List[ObraRead])
def listar_obras(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[Obra]:
    return session.exec(select(Obra).where(Obra.user_id == current_user.id)).all()


@router.get("/{obra_id}", response_model=ObraDetailResponse)
def obter_obra(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> ObraDetailResponse:
    obra = _verify_obra_ownership(obra_id, current_user, session)
    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id).order_by(Etapa.ordem)).all()

    obra_read = ObraRead.model_validate(obra)

    if not etapas:
        return ObraDetailResponse(obra=obra_read, etapas=[])

    etapa_ids = [e.id for e in etapas]

    # Buscar todos os orçamentos em 1 query
    orcamentos = session.exec(
        select(OrcamentoEtapa).where(OrcamentoEtapa.etapa_id.in_(etapa_ids))
    ).all()
    orcamento_map = {o.etapa_id: o.valor_previsto for o in orcamentos}

    # Buscar totais de despesas em 1 query agregada
    gastos_rows = session.exec(
        select(
            Despesa.etapa_id,
            sa_func.coalesce(sa_func.sum(Despesa.valor), 0).label("total")
        )
        .where(Despesa.etapa_id.in_(etapa_ids))
        .group_by(Despesa.etapa_id)
    ).all()
    gasto_map = {row[0]: float(row[1]) for row in gastos_rows}

    etapas_enriched = []
    for etapa in etapas:
        etapa_read = EtapaEnrichedRead(
            **etapa.model_dump(),
            valor_previsto=orcamento_map.get(etapa.id),
            valor_gasto=gasto_map.get(etapa.id, 0.0),
        )
        etapas_enriched.append(etapa_read)

    return ObraDetailResponse(obra=obra_read, etapas=etapas_enriched)


@router.get("/{obra_id}/export-pdf")
def exportar_pdf(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> StreamingResponse:
    obra = _verify_obra_ownership(obra_id, current_user, session)
    etapas = session.exec(select(Etapa).where(Etapa.obra_id == obra_id).order_by(Etapa.ordem)).all()
    etapa_ids = [etapa.id for etapa in etapas]
    itens = session.exec(select(ChecklistItem).where(ChecklistItem.etapa_id.in_(etapa_ids))).all() if etapa_ids else []
    itens_map: dict[str, list[ChecklistItem]] = {}
    for item in itens:
        itens_map.setdefault(str(item.etapa_id), []).append(item)
    pdf_bytes = render_obra_pdf(obra, etapas, itens_map)
    return StreamingResponse(
        content=iter([pdf_bytes]),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="obra-{obra_id}.pdf"'},
    )


def _collect_storage_keys(session: Session, obra_id: UUID, bucket: str) -> list[str]:
    """Extrai object keys dos arquivos de projetos para limpeza no storage."""
    from ..storage import extract_object_key
    projetos = session.exec(
        select(ProjetoDoc.arquivo_url).where(ProjetoDoc.obra_id == obra_id)
    ).all()
    keys: list[str] = []
    for url in projetos:
        if url:
            try:
                keys.append(extract_object_key(url, bucket))
            except Exception:
                pass
    return keys


def _subquery_ids(session: Session, model, id_col, condition):
    """Retorna lista de IDs para uso em subconsultas de cascade."""
    return [row for row in session.exec(select(id_col).where(condition)).all()]


def _cascade_delete_obra_data(session: Session, obra_id: UUID) -> list[str]:
    """Remove todos os dados associados a uma obra com bulk DELETEs.
    Retorna storage keys para limpeza."""
    from sqlalchemy import delete

    bucket = os.getenv("S3_BUCKET")
    storage_keys: list[str] = []

    # Coletar storage keys ANTES de deletar ProjetoDoc
    if bucket:
        storage_keys = _collect_storage_keys(session, obra_id, bucket)

    # ProjetoDoc → Risco (bulk)
    projeto_ids = _subquery_ids(session, ProjetoDoc, ProjetoDoc.id, ProjetoDoc.obra_id == obra_id)
    if projeto_ids:
        session.exec(delete(Risco).where(Risco.projeto_id.in_(projeto_ids)))
    session.exec(delete(ProjetoDoc).where(ProjetoDoc.obra_id == obra_id))

    # Etapa → ChecklistItem → Evidencia, AnaliseVisual → Achado, EtapaComentario
    etapa_ids = _subquery_ids(session, Etapa, Etapa.id, Etapa.obra_id == obra_id)
    if etapa_ids:
        # ChecklistItem → Evidencia
        item_ids = _subquery_ids(session, ChecklistItem, ChecklistItem.id, ChecklistItem.etapa_id.in_(etapa_ids))
        if item_ids:
            session.exec(delete(Evidencia).where(Evidencia.checklist_item_id.in_(item_ids)))
        session.exec(delete(ChecklistItem).where(ChecklistItem.etapa_id.in_(etapa_ids)))

        # AnaliseVisual → Achado
        analise_ids = _subquery_ids(session, AnaliseVisual, AnaliseVisual.id, AnaliseVisual.etapa_id.in_(etapa_ids))
        if analise_ids:
            session.exec(delete(Achado).where(Achado.analise_id.in_(analise_ids)))
        session.exec(delete(AnaliseVisual).where(AnaliseVisual.etapa_id.in_(etapa_ids)))

        session.exec(delete(EtapaComentario).where(EtapaComentario.etapa_id.in_(etapa_ids)))
    session.exec(delete(Etapa).where(Etapa.obra_id == obra_id))

    # Financeiro e config (bulk direto — FK aponta para obra)
    session.exec(delete(OrcamentoEtapa).where(OrcamentoEtapa.obra_id == obra_id))
    session.exec(delete(Despesa).where(Despesa.obra_id == obra_id))
    session.exec(delete(AlertaConfig).where(AlertaConfig.obra_id == obra_id))

    # Misc
    session.exec(delete(DeviceToken).where(DeviceToken.obra_id == obra_id))
    session.exec(delete(ObraConvite).where(ObraConvite.obra_id == obra_id))
    session.exec(delete(ObraDetalhamento).where(ObraDetalhamento.obra_id == obra_id))

    # ChecklistGeracaoLog → ChecklistGeracaoItem
    log_ids = _subquery_ids(session, ChecklistGeracaoLog, ChecklistGeracaoLog.id, ChecklistGeracaoLog.obra_id == obra_id)
    if log_ids:
        session.exec(delete(ChecklistGeracaoItem).where(ChecklistGeracaoItem.log_id.in_(log_ids)))
    session.exec(delete(ChecklistGeracaoLog).where(ChecklistGeracaoLog.obra_id == obra_id))

    # AtividadeCronograma → ServicoNecessario + ChecklistItem + Despesa (FK atividade_id)
    atividade_ids = _subquery_ids(session, AtividadeCronograma, AtividadeCronograma.id, AtividadeCronograma.obra_id == obra_id)
    if atividade_ids:
        session.exec(delete(ServicoNecessario).where(ServicoNecessario.atividade_id.in_(atividade_ids)))
    session.exec(delete(AtividadeCronograma).where(AtividadeCronograma.obra_id == obra_id))

    return storage_keys


@router.delete("/{obra_id}", response_model=OkResponse)
def deletar_obra(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Remove uma obra e todos os dados associados (cascata)."""
    obra = _verify_obra_ownership(obra_id, current_user, session)

    try:
        storage_keys = _cascade_delete_obra_data(session, obra_id)
        session.delete(obra)
        session.commit()
    except Exception as exc:
        session.rollback()
        logger.error("Erro ao deletar obra %s: %s", obra_id, exc)
        raise HTTPException(status_code=500, detail="Erro ao remover obra")

    # Remove storage files after successful commit
    bucket = os.getenv("S3_BUCKET")
    if bucket and storage_keys:
        from ..storage import delete_file
        for key in storage_keys:
            try:
                delete_file(bucket, key)
            except Exception as exc:
                logger.warning("Falha ao remover arquivo %s do storage: %s", key, exc)

    return {"ok": True}
