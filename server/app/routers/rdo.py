"""RDO router — registro diário de obra com publicação e notificação."""

import json
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..auth import get_current_user, require_engineer
from ..db import get_session
from ..helpers import _verify_obra_access, _verify_obra_ownership
from ..models import RdoDiario, User
from ..notifications import notificar_publicacao_rdo
from ..schemas import RdoCreate, RdoRead

router = APIRouter(tags=["rdo"])


def _to_read(rdo: RdoDiario) -> RdoRead:
    fotos_urls: list[str] = []
    if rdo.fotos_urls:
        try:
            parsed = json.loads(rdo.fotos_urls)
            if isinstance(parsed, list):
                fotos_urls = [str(x) for x in parsed]
        except json.JSONDecodeError:
            fotos_urls = []
    return RdoRead(
        id=rdo.id,
        obra_id=rdo.obra_id,
        data_referencia=rdo.data_referencia,
        clima=rdo.clima,
        mao_obra_total=rdo.mao_obra_total,
        atividades_executadas=rdo.atividades_executadas,
        observacoes=rdo.observacoes,
        fotos_urls=fotos_urls,
        publicado=rdo.publicado,
        publicado_em=rdo.publicado_em,
        created_at=rdo.created_at,
        updated_at=rdo.updated_at,
    )


@router.post("/api/obras/{obra_id}/rdo", response_model=RdoRead)
def criar_rdo(
    obra_id: UUID,
    payload: RdoCreate,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
) -> RdoRead:
    _verify_obra_ownership(obra_id, current_user, session)

    rdo = RdoDiario(
        obra_id=obra_id,
        data_referencia=payload.data_referencia,
        clima=payload.clima,
        mao_obra_total=payload.mao_obra_total,
        atividades_executadas=payload.atividades_executadas,
        observacoes=payload.observacoes,
        fotos_urls=json.dumps(payload.fotos_urls, ensure_ascii=False),
    )
    session.add(rdo)
    session.commit()
    session.refresh(rdo)
    return _to_read(rdo)


@router.get("/api/obras/{obra_id}/rdo", response_model=list[RdoRead])
def listar_rdos(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> list[RdoRead]:
    _verify_obra_access(obra_id, current_user, session)
    itens = session.exec(
        select(RdoDiario)
        .where(RdoDiario.obra_id == obra_id)
        .order_by(RdoDiario.data_referencia.desc())
    ).all()
    return [_to_read(i) for i in itens]


@router.get("/api/rdo/{rdo_id}", response_model=RdoRead)
def detalhar_rdo(
    rdo_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
) -> RdoRead:
    rdo = session.get(RdoDiario, rdo_id)
    if not rdo:
        raise HTTPException(status_code=404, detail="RDO nao encontrado")
    _verify_obra_access(rdo.obra_id, current_user, session)
    return _to_read(rdo)


@router.post("/api/rdo/{rdo_id}/publicar", response_model=RdoRead)
def publicar_rdo(
    rdo_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
) -> RdoRead:
    rdo = session.get(RdoDiario, rdo_id)
    if not rdo:
        raise HTTPException(status_code=404, detail="RDO nao encontrado")

    _verify_obra_ownership(rdo.obra_id, current_user, session)

    if not rdo.publicado:
        rdo.publicado = True
        rdo.publicado_em = datetime.now(timezone.utc)
        rdo.updated_at = datetime.now(timezone.utc)
        session.add(rdo)
        session.commit()
        session.refresh(rdo)
        notificar_publicacao_rdo(session, rdo.obra_id, rdo.data_referencia.isoformat())

    return _to_read(rdo)
