"""Lógica de planos, feature gates e helpers de monetização."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import Depends, HTTPException, status
from sqlmodel import Session, select, func

from .auth import get_current_user
from .db import get_session
from .models import User, Obra, ObraConvite, UsageTracking

# ─── Configuração de Planos ──────────────────────────────────────────────────

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
        "prestadores_limit": 3,
        "prestadores_show_contact": False,
        "doc_analysis_pages_limit": 2,
        "max_convites": 0,
    },
    "dono_da_obra": {
        "max_obras": 1,
        "max_doc_uploads": None,  # ilimitado
        "max_doc_size_mb": None,
        "max_doc_pages_viewable": None,
        "can_delete_doc": True,
        "can_create_etapas": True,
        "can_create_checklist_items": True,
        "can_create_comentarios": True,
        "ai_visual_monthly_limit": None,
        "checklist_inteligente_lifetime_limit": None,
        "normas_results_limit": None,
        "prestadores_limit": None,
        "prestadores_show_contact": True,
        "doc_analysis_pages_limit": None,
        "max_convites": 3,
    },
}

# RevenueCat product_id → plan mapping
PRODUCT_TO_PLAN = {
    "dono_da_obra_monthly": "dono_da_obra",
}


# ─── Helpers ─────────────────────────────────────────────────────────────────

def get_plan_config(user: User) -> dict:
    """Retorna a configuração de limites do plano do usuário."""
    return PLAN_CONFIG.get(user.plan, PLAN_CONFIG["gratuito"])


def require_paid(
    current_user: User = Depends(get_current_user),
) -> User:
    """Dependency que bloqueia usuários do plano gratuito."""
    if current_user.plan == "gratuito":
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
        period = datetime.utcnow().strftime("%Y-%m")

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
        usage.updated_at = datetime.utcnow()
    else:
        usage = UsageTracking(
            user_id=user_id,
            feature=feature,
            period=period,
            count=1,
        )
        session.add(usage)
    session.commit()


def get_usage_count(
    session: Session,
    user_id: UUID,
    feature: str,
    period: Optional[str] = None,
) -> int:
    """Retorna a contagem de uso de uma feature no período."""
    if period is None:
        period = datetime.utcnow().strftime("%Y-%m")

    usage = session.exec(
        select(UsageTracking).where(
            UsageTracking.user_id == user_id,
            UsageTracking.feature == feature,
            UsageTracking.period == period,
        )
    ).first()
    return usage.count if usage else 0


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
            ObraConvite.status == "aceito",
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
            ObraConvite.status.in_(["pendente", "aceito"]),
        )
    ).one()
    if active_count >= max_convites:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de {max_convites} convidado(s) atingido",
        )
