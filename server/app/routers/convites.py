"""Convites router — criar, listar, remover, aceitar, minhas-obras, comentarios."""

import secrets
from datetime import datetime, timedelta, timezone
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, Etapa, ObraConvite, EtapaComentario,
)
from ..schemas import (
    ConviteCreateRequest, ConviteRead, ConviteAceitarRequest,
    ObraConvidadaRead, ComentarioCreateRequest, ComentarioRead,
    UserRead,
)
from ..auth import get_current_user, create_access_token, create_refresh_token, require_engineer
from ..enums import ConviteStatus
from ..subscription import get_plan_config, check_convite_limit
from ..email_service import enviar_email_convite
from ..helpers import (
    _verify_obra_ownership, _verify_etapa_access,
    _notificar_dono_atualizacao,
)

import logging
logger = logging.getLogger(__name__)

router = APIRouter(tags=["convites"])


@router.post("/api/obras/{obra_id}/convites", response_model=ConviteRead)
def criar_convite(
    obra_id: UUID,
    payload: ConviteCreateRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    """Dono cria convite para profissional acessar a obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    check_convite_limit(session, current_user, obra_id)

    existing = session.exec(
        select(ObraConvite).where(
            ObraConvite.obra_id == obra_id,
            ObraConvite.email == payload.email.lower().strip(),
            ObraConvite.status.in_([ConviteStatus.PENDENTE, ConviteStatus.ACEITO]),
        )
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Já existe um convite ativo para este e-mail")

    token = secrets.token_urlsafe(32)

    convite = ObraConvite(
        obra_id=obra_id,
        dono_id=current_user.id,
        email=payload.email.lower().strip(),
        papel=payload.papel,
        token=token,
        token_expires_at=datetime.now(timezone.utc) + timedelta(days=7),
    )
    session.add(convite)
    session.commit()
    session.refresh(convite)

    email_enviado = enviar_email_convite(
        destinatario=convite.email,
        obra_nome=obra.nome,
        dono_nome=current_user.nome,
        papel=convite.papel,
        token=token,
    )
    if not email_enviado:
        logger.error("Falha ao enviar email de convite para %s", convite.email)

    return ConviteRead(
        id=convite.id,
        obra_id=convite.obra_id,
        email=convite.email,
        papel=convite.papel,
        status=convite.status,
        created_at=convite.created_at,
        accepted_at=convite.accepted_at,
    )


@router.get("/api/obras/{obra_id}/convites", response_model=List[ConviteRead])
def listar_convites(
    obra_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Dono lista convites de uma obra."""
    obra = _verify_obra_ownership(obra_id, current_user, session)
    convites = session.exec(
        select(ObraConvite).where(
            ObraConvite.obra_id == obra_id,
            ObraConvite.status.in_([ConviteStatus.PENDENTE, ConviteStatus.ACEITO]),
        ).order_by(ObraConvite.created_at.desc())
    ).all()

    result = []
    for c in convites:
        convidado_nome = None
        if c.convidado_id:
            convidado = session.get(User, c.convidado_id)
            convidado_nome = convidado.nome if convidado else None
        result.append(ConviteRead(
            id=c.id,
            obra_id=c.obra_id,
            email=c.email,
            papel=c.papel,
            status=c.status,
            convidado_nome=convidado_nome,
            created_at=c.created_at,
            accepted_at=c.accepted_at,
        ))
    return result


@router.delete("/api/convites/{convite_id}")
def remover_convite(
    convite_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(require_engineer),
):
    """Dono remove convidado (acesso revogado instantaneamente)."""
    convite = session.get(ObraConvite, convite_id)
    if not convite:
        raise HTTPException(status_code=404, detail="Convite não encontrado")
    if convite.dono_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso negado")

    convite.status = ConviteStatus.REMOVIDO
    session.add(convite)
    session.commit()
    return {"ok": True}


@router.post("/api/convites/aceitar")
def aceitar_convite(
    payload: ConviteAceitarRequest,
    session: Session = Depends(get_session),
):
    """Convidado aceita convite via token do magic link. Cria conta se não existe."""
    convite = session.exec(
        select(ObraConvite).where(
            ObraConvite.token == payload.token,
            ObraConvite.status == ConviteStatus.PENDENTE,
        )
    ).first()
    if not convite:
        raise HTTPException(status_code=404, detail="Convite não encontrado ou já utilizado")

    if convite.token_expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=410, detail="Link expirado. Solicite um novo convite ao proprietário.")

    user = session.exec(
        select(User).where(User.email == convite.email)
    ).first()

    if not user:
        user = User(
            email=convite.email,
            nome=payload.nome,
            role="convidado",
            plan="gratuito",
        )
        session.add(user)
        session.commit()
        session.refresh(user)

    convite.convidado_id = user.id
    convite.status = ConviteStatus.ACEITO
    convite.accepted_at = datetime.now(timezone.utc)
    convite.token = None  # SEC-07v2: invalidar token após uso
    session.add(convite)
    session.commit()

    return {
        "access_token": create_access_token(str(user.id)),
        "refresh_token": create_refresh_token(str(user.id)),
        "user": UserRead.from_user(user).model_dump(),
        "obra_id": str(convite.obra_id),
    }


@router.get("/api/convites/minhas-obras", response_model=List[ObraConvidadaRead])
def listar_obras_convidadas(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Convidado lista obras onde foi convidado."""
    rows = session.exec(
        select(ObraConvite, Obra, User)
        .join(Obra, Obra.id == ObraConvite.obra_id)
        .outerjoin(User, User.id == ObraConvite.dono_id)
        .where(
            ObraConvite.convidado_id == current_user.id,
            ObraConvite.status == ConviteStatus.ACEITO,
        )
    ).all()

    return [
        ObraConvidadaRead(
            obra_id=obra.id,
            obra_nome=obra.nome,
            dono_nome=dono.nome if dono else "",
            papel=convite.papel,
            convite_id=convite.id,
        )
        for convite, obra, dono in rows
    ]


# ─── Comentários em Etapas ───────────────────────────────────────────────────

@router.post("/api/etapas/{etapa_id}/comentarios", response_model=ComentarioRead)
def criar_comentario(
    etapa_id: UUID,
    payload: ComentarioCreateRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Dono ou convidado cria comentário em uma etapa."""
    etapa, role = _verify_etapa_access(etapa_id, current_user, session)

    if role == "dono" and not get_plan_config(current_user).get("can_create_comentarios"):
        raise HTTPException(status_code=403, detail="Comentários disponíveis apenas para assinantes")

    comentario = EtapaComentario(
        etapa_id=etapa_id,
        user_id=current_user.id,
        texto=payload.texto,
    )
    session.add(comentario)
    session.commit()
    session.refresh(comentario)

    if role == "convidado":
        _notificar_dono_atualizacao(session, etapa.obra_id, current_user.nome)

    return ComentarioRead(
        id=comentario.id,
        etapa_id=comentario.etapa_id,
        user_id=comentario.user_id,
        user_nome=current_user.nome,
        texto=comentario.texto,
        created_at=comentario.created_at,
    )


@router.get("/api/etapas/{etapa_id}/comentarios", response_model=List[ComentarioRead])
def listar_comentarios(
    etapa_id: UUID,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Lista comentários de uma etapa."""
    _verify_etapa_access(etapa_id, current_user, session)

    rows = session.exec(
        select(EtapaComentario, User)
        .outerjoin(User, User.id == EtapaComentario.user_id)
        .where(EtapaComentario.etapa_id == etapa_id)
        .order_by(EtapaComentario.created_at.desc())
    ).all()

    return [
        ComentarioRead(
            id=c.id,
            etapa_id=c.etapa_id,
            user_id=c.user_id,
            user_nome=user.nome if user else "",
            texto=c.texto,
            created_at=c.created_at,
        )
        for c, user in rows
    ]
