"""Obras router — CRUD and PDF export."""

from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy import func as sa_func
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, Etapa, ChecklistItem, OrcamentoEtapa, Despesa,
)
from ..schemas import (
    ObraCreate, ObraRead, ObraDetailResponse, EtapaEnrichedRead,
)
from ..enums import EtapaStatus, ChecklistStatus
from ..auth import get_current_user
from ..subscription import check_obra_limit
from ..pdf import render_obra_pdf
from ..seed_checklists import get_itens_padrao
from ..helpers import ETAPAS_PADRAO, _verify_obra_ownership

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
