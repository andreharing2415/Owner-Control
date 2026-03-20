"""Lógica de planos, feature gates e helpers de monetização."""

from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select, func

from .auth import get_current_user
from .db import get_session
from .enums import ConviteStatus
from .models import User, Obra, ObraConvite, UsageTracking

# ─── Configuração de Planos ──────────────────────────────────────────────────

_UNLIMITED_FEATURES = {
    "max_obras": None,
    "max_doc_uploads": None,
    "max_doc_size_mb": None,
    "max_doc_pages_viewable": None,
    "can_delete_doc": True,
    "can_create_etapas": True,
    "can_create_checklist_items": True,
    "can_create_comentarios": True,
    "ai_visual_monthly_limit": None,
    "checklist_inteligente_lifetime_limit": None,
    "normas_results_limit": None,
    "normas_monthly_limit": None,
    "prestadores_limit": None,
    "prestadores_show_contact": True,
    "doc_analysis_pages_limit": None,
    "max_convites": 3,
}

PLAN_CONFIG = {
    "gratuito": {
        "max_obras": 1,
        "max_doc_uploads": 1,
        "max_doc_size_mb": 3,
        "max_doc_pages_viewable": 2,
        "can_delete_doc": False,
        "can_create_etapas": False,
        "can_create_checklist_items": False,
        "can_create_comentarios": False,
        "ai_visual_monthly_limit": 1,
        "checklist_inteligente_lifetime_limit": 1,
        "normas_results_limit": 3,
        "normas_monthly_limit": 3,
        "prestadores_limit": 3,
        "prestadores_show_contact": False,
        "doc_analysis_pages_limit": 2,
        "max_convites": 0,
        "show_ads": True,
        "can_watch_rewarded": True,
    },
    "essencial": {
        **_UNLIMITED_FEATURES,
        "show_ads": True,
        "can_watch_rewarded": False,
    },
    "completo": {
        **_UNLIMITED_FEATURES,
        "show_ads": False,
        "can_watch_rewarded": False,
    },
    # Legacy — mapeia para completo (mesmos recursos)
    "dono_da_obra": {
        **_UNLIMITED_FEATURES,
        "show_ads": False,
        "can_watch_rewarded": False,
    },
}


# ─── Helpers ─────────────────────────────────────────────────────────────────

def get_plan_config(user: User) -> dict:
    """Retorna a configuração de limites do plano do usuário."""
    return PLAN_CONFIG.get(user.plan, PLAN_CONFIG["gratuito"])


PAID_PLANS = {"dono_da_obra", "essencial", "completo"}


def require_paid(
    current_user: User = Depends(get_current_user),
) -> User:
    """Dependency que bloqueia usuários do plano gratuito."""
    if current_user.plan not in PAID_PLANS:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Recurso disponível apenas para assinantes",
        )
    return current_user


def require_dono(
    current_user: User = Depends(get_current_user),
) -> User:
    """Dependency que exige role owner (não convidado)."""
    if current_user.role == "convidado":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Recurso disponível apenas para o proprietário da obra",
        )
    return current_user


def check_and_increment_usage(
    session: Session,
    user_id: UUID,
    feature: str,
    limit: Optional[int],
    period: Optional[str] = None,
) -> None:
    """Verifica e incrementa uso de uma feature. Levanta 403 se limite atingido.

    Se period=None, usa o mês atual (YYYY-MM).
    Se limit=None, não há limite (ilimitado).
    """
    if limit is None:
        return  # ilimitado

    if period is None:
        period = datetime.now(timezone.utc).strftime("%Y-%m")

    usage = session.exec(
        select(UsageTracking).where(
            UsageTracking.user_id == user_id,
            UsageTracking.feature == feature,
            UsageTracking.period == period,
        )
    ).first()

    if usage and usage.count >= limit:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de uso atingido para '{feature}' no seu plano",
        )

    if usage:
        usage.count += 1
        usage.updated_at = datetime.now(timezone.utc)
        session.commit()
    else:
        try:
            usage = UsageTracking(
                user_id=user_id,
                feature=feature,
                period=period,
                count=1,
            )
            session.add(usage)
            session.commit()
        except IntegrityError:
            session.rollback()
            usage = session.exec(
                select(UsageTracking).where(
                    UsageTracking.user_id == user_id,
                    UsageTracking.feature == feature,
                    UsageTracking.period == period,
                )
            ).first()
            if usage:
                usage.count += 1
                usage.updated_at = datetime.now(timezone.utc)
                session.commit()


def get_usage_count(
    session: Session,
    user_id: UUID,
    feature: str,
    period: Optional[str] = None,
) -> int:
    """Retorna a contagem de uso de uma feature no período."""
    if period is None:
        period = datetime.now(timezone.utc).strftime("%Y-%m")

    usage = session.exec(
        select(UsageTracking).where(
            UsageTracking.user_id == user_id,
            UsageTracking.feature == feature,
            UsageTracking.period == period,
        )
    ).first()
    return usage.count if usage else 0


REWARDED_FEATURES = {"ai_visual", "checklist_inteligente", "doc_upload", "normas"}
REWARDED_BONUS = 3  # usos extras por vídeo assistido


def grant_rewarded_usage(
    session: Session,
    user_id: UUID,
    feature: str,
) -> int:
    """Concede usos extras após assistir vídeo rewarded. Retorna novo count."""
    if feature not in REWARDED_FEATURES:
        raise HTTPException(
            status_code=400,
            detail=f"Feature '{feature}' não suporta rewarded ads",
        )

    period = (
        "lifetime" if feature == "checklist_inteligente"
        else datetime.now(timezone.utc).strftime("%Y-%m")
    )

    usage = session.exec(
        select(UsageTracking).where(
            UsageTracking.user_id == user_id,
            UsageTracking.feature == feature,
            UsageTracking.period == period,
        )
    ).first()

    if usage:
        # Subtract bonus from count (effectively granting more uses)
        usage.count = max(0, usage.count - REWARDED_BONUS)
        usage.updated_at = datetime.now(timezone.utc)
    else:
        # No usage yet — nothing to reset
        return 0

    session.commit()
    return usage.count


def check_obra_access(
    session: Session,
    user: User,
    obra_id: UUID,
) -> str:
    """Verifica se o usuário tem acesso à obra. Retorna 'dono' ou 'convidado'.

    Levanta 403 se não tem acesso.
    """
    # Verifica se é dono
    obra = session.get(Obra, obra_id)
    if not obra:
        raise HTTPException(status_code=404, detail="Obra não encontrada")

    if obra.user_id == user.id:
        return "dono"

    # Verifica se é convidado aceito
    convite = session.exec(
        select(ObraConvite).where(
            ObraConvite.obra_id == obra_id,
            ObraConvite.convidado_id == user.id,
            ObraConvite.status == ConviteStatus.ACEITO,
        )
    ).first()

    if convite:
        return "convidado"

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Você não tem acesso a esta obra",
    )


def check_obra_limit(session: Session, user: User) -> None:
    """Verifica se o usuário pode criar mais obras."""
    config = get_plan_config(user)
    max_obras = config["max_obras"]
    if max_obras is None:
        return

    count = session.exec(
        select(func.count(Obra.id)).where(Obra.user_id == user.id)
    ).one()
    if count >= max_obras:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de {max_obras} obra(s) atingido para seu plano",
        )


def check_convite_limit(session: Session, user: User, obra_id: UUID) -> None:
    """Verifica se o dono pode enviar mais convites."""
    config = get_plan_config(user)
    max_convites = config["max_convites"]
    if max_convites == 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Convites disponíveis apenas para assinantes",
        )

    active_count = session.exec(
        select(func.count(ObraConvite.id)).where(
            ObraConvite.obra_id == obra_id,
            ObraConvite.status.in_([ConviteStatus.PENDENTE, ConviteStatus.ACEITO]),
        )
    ).one()
    if active_count >= max_convites:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de {max_convites} convidado(s) atingido",
        )
