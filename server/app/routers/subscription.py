"""Subscription router — me, create-checkout, reward-usage, success, cancel, sync, cancel-sub, delete-account, webhook."""

import json
import os
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from sqlalchemy import func as sa_func
from sqlmodel import Session, select

from ..db import get_session
from ..models import (
    User, Obra, ProjetoDoc, Subscription, UsageTracking,
    StripeWebhookEvent, ObraConvite,
)
from ..schemas import (
    SubscriptionInfoResponse, RewardUsageRequest, RewardUsageResponse,
)
from ..auth import get_current_user
from ..enums import ConviteStatus
from ..subscription import get_plan_config, grant_rewarded_usage, REWARDED_BONUS
from ..helpers import _read_template

router = APIRouter(tags=["subscription"])


class NativePurchaseValidationRequest(BaseModel):
    plan: str
    platform: str
    product_id: str
    purchase_id: str
    purchase_token: str | None = None


@router.get("/api/subscription/me", response_model=SubscriptionInfoResponse)
def get_subscription_info(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Retorna plano atual, configuração de limites e uso do mês."""
    config = get_plan_config(current_user)
    period = datetime.now(timezone.utc).strftime("%Y-%m")

    usages = session.exec(
        select(UsageTracking).where(
            UsageTracking.user_id == current_user.id,
            UsageTracking.period.in_([period, "lifetime"]),
        )
    ).all()
    usage_map = {u.feature: u.count for u in usages}

    obra_count = session.exec(
        select(sa_func.count(Obra.id)).where(Obra.user_id == current_user.id)
    ).one()

    doc_count = session.exec(
        select(sa_func.count(ProjetoDoc.id))
        .join(Obra, Obra.id == ProjetoDoc.obra_id)
        .where(Obra.user_id == current_user.id)
    ).one()

    convite_count = session.exec(
        select(sa_func.count(ObraConvite.id))
        .join(Obra, Obra.id == ObraConvite.obra_id)
        .where(
            Obra.user_id == current_user.id,
            ObraConvite.status.in_([ConviteStatus.PENDENTE, ConviteStatus.ACEITO]),
        )
    ).one()

    subscription = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    return SubscriptionInfoResponse(
        plan=current_user.plan,
        plan_config=config,
        usage=usage_map,
        obra_count=obra_count,
        doc_count=doc_count,
        convite_count=convite_count,
        expires_at=subscription.expires_at if subscription else None,
        status=subscription.status if subscription else "active",
        show_ads=config.get("show_ads", True),
        can_watch_rewarded=config.get("can_watch_rewarded", False),
    )


PLAN_PRICE_ENV = {
    "essencial": "STRIPE_PRICE_ID_ESSENCIAL",
    "completo": "STRIPE_PRICE_ID_COMPLETO",
}


@router.post("/api/subscription/create-checkout")
def create_checkout_session(
    plan: str = "essencial",
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Cria uma sessão Stripe Checkout para assinatura Essencial ou Completo."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="STRIPE_SECRET_KEY não configurado")

    env_key = PLAN_PRICE_ENV.get(plan)
    if not env_key:
        # Fallback: plano legado usa STRIPE_PRICE_ID
        price_id = os.getenv("STRIPE_PRICE_ID")
    else:
        price_id = os.getenv(env_key) or os.getenv("STRIPE_PRICE_ID")

    if not price_id:
        raise HTTPException(status_code=500, detail=f"STRIPE_PRICE_ID para plano '{plan}' não configurado")

    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    checkout_params = {
        "mode": "subscription",
        "line_items": [{"price": price_id, "quantity": 1}],
        "success_url": os.getenv("STRIPE_SUCCESS_URL", "https://mestreobra-backend-530484413221.us-central1.run.app/api/subscription/success?session_id={CHECKOUT_SESSION_ID}"),
        "cancel_url": os.getenv("STRIPE_CANCEL_URL", "https://mestreobra-backend-530484413221.us-central1.run.app/api/subscription/cancel"),
        "client_reference_id": str(current_user.id),
        "metadata": {"user_id": str(current_user.id), "plan": plan},
    }

    if sub and sub.stripe_customer_id:
        checkout_params["customer"] = sub.stripe_customer_id
    else:
        checkout_params["customer_email"] = current_user.email

    try:
        checkout_session = stripe.checkout.Session.create(**checkout_params)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro Stripe: {exc}")

    return {"checkout_url": checkout_session.url, "session_id": checkout_session.id}


@router.post("/api/subscription/reward-usage", response_model=RewardUsageResponse)
def reward_usage(
    body: RewardUsageRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Concede usos extras de uma feature após o usuário assistir um vídeo rewarded."""
    config = get_plan_config(current_user)
    if not config.get("can_watch_rewarded", False):
        raise HTTPException(
            status_code=403,
            detail="Rewarded ads disponíveis apenas para o plano gratuito",
        )

    new_count = grant_rewarded_usage(session, current_user.id, body.feature)
    return RewardUsageResponse(
        feature=body.feature,
        new_count=new_count,
        bonus_granted=REWARDED_BONUS,
    )


@router.post("/api/subscription/validate-purchase")
def validate_native_purchase(
    body: NativePurchaseValidationRequest,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Valida compra nativa (Play/App Store) e atualiza plano do usuário."""
    if body.plan not in ("essencial", "completo"):
        raise HTTPException(status_code=400, detail="Plano invalido")

    if body.platform not in ("play_store", "app_store"):
        raise HTTPException(status_code=400, detail="Plataforma invalida")

    # Validação criptográfica com loja pode ser plugada aqui por provider.
    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    now = datetime.now(timezone.utc)
    if not sub:
        sub = Subscription(
            user_id=current_user.id,
            plan=body.plan,
            status="active",
            store=body.platform,
            stripe_subscription_id=body.purchase_id,
            updated_at=now,
        )
    else:
        sub.plan = body.plan
        sub.status = "active"
        sub.store = body.platform
        sub.stripe_subscription_id = body.purchase_id
        sub.updated_at = now

    current_user.plan = body.plan
    current_user.updated_at = now
    session.add(sub)
    session.add(current_user)
    session.commit()

    return {
        "status": "validated",
        "plan": current_user.plan,
        "platform": body.platform,
        "product_id": body.product_id,
    }


@router.get("/api/subscription/success")
def subscription_success(session_id: str):
    """Redirect page after successful Stripe Checkout."""
    return HTMLResponse(content=_read_template("subscription_success.html"))


@router.get("/api/subscription/cancel")
def subscription_cancel():
    """Redirect page after cancelled Stripe Checkout."""
    return HTMLResponse(content=_read_template("subscription_cancel.html"))


@router.post("/api/subscription/sync")
def sync_subscription(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Consulta Stripe para verificar status da assinatura."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="STRIPE_SECRET_KEY não configurado")

    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    if not sub or not sub.stripe_customer_id:
        return {"plan": current_user.plan}

    try:
        subscriptions = stripe.Subscription.list(
            customer=sub.stripe_customer_id,
            status="active",
            limit=1,
        )
        if subscriptions.data:
            stripe_sub = subscriptions.data[0]
            resolved_plan = _resolve_plan_from_stripe(stripe_sub)
            current_user.plan = resolved_plan
            sub.plan = resolved_plan
            sub.status = "active"
            sub.expires_at = datetime.fromtimestamp(stripe_sub.current_period_end, tz=timezone.utc)
        else:
            current_user.plan = "gratuito"
            sub.plan = "gratuito"
            sub.status = "expired"
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro Stripe: {exc}")

    current_user.updated_at = datetime.now(timezone.utc)
    sub.updated_at = datetime.now(timezone.utc)
    session.add(current_user)
    session.commit()

    return {"plan": current_user.plan}


@router.post("/api/subscription/cancel-subscription")
def cancel_subscription(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Cancela a assinatura do usuário no final do período atual."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="STRIPE_SECRET_KEY não configurado")

    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    if not sub or sub.status != "active" or not sub.stripe_subscription_id:
        raise HTTPException(status_code=400, detail="Nenhuma assinatura ativa encontrada")

    try:
        stripe_sub = stripe.Subscription.modify(sub.stripe_subscription_id, cancel_at_period_end=True)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Erro Stripe: {exc}")

    # Marca como pendente de cancelamento, mas mantém plano pago até o fim do período.
    # O downgrade efetivo (plan→gratuito) ocorre apenas via webhook customer.subscription.deleted.
    sub.status = "cancel_pending"
    if sub.expires_at is None and hasattr(stripe_sub, "current_period_end") and stripe_sub.current_period_end:
        sub.expires_at = datetime.fromtimestamp(stripe_sub.current_period_end, tz=timezone.utc)
    sub.updated_at = datetime.now(timezone.utc)
    session.add(sub)

    # Plano do usuário permanece inalterado até webhook confirmar expiração.
    current_user.updated_at = datetime.now(timezone.utc)
    session.add(current_user)

    session.commit()

    return {
        "message": "Assinatura cancelada. Acesso mantido até o final do período.",
        "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
    }


@router.delete("/api/auth/me")
def delete_account(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Exclui a conta do usuário: anonimiza dados pessoais, mantém dados de obra."""
    import stripe

    # 1. Cancel Stripe subscription if active
    sub = session.exec(
        select(Subscription).where(Subscription.user_id == current_user.id)
    ).first()

    if sub and sub.status == "active" and sub.stripe_subscription_id:
        stripe_key = os.getenv("STRIPE_SECRET_KEY")
        if stripe_key:
            stripe.api_key = stripe_key
            try:
                stripe.Subscription.modify(sub.stripe_subscription_id, cancel_at_period_end=True)
            except Exception:
                pass  # Best effort
        sub.status = "cancelled"
        sub.updated_at = datetime.now(timezone.utc)
        session.add(sub)

    # 2. Anonymize user data
    current_user.nome = "Usuário removido"
    current_user.email = f"{current_user.id}@deleted.local"
    current_user.telefone = None
    current_user.google_id = None
    current_user.password_hash = None
    current_user.ativo = False
    current_user.plan = "gratuito"
    current_user.updated_at = datetime.now(timezone.utc)
    session.add(current_user)

    # 3. Cancel pending invites where user is owner
    pending_convites = session.exec(
        select(ObraConvite).where(
            ObraConvite.dono_id == current_user.id,
            ObraConvite.status == ConviteStatus.PENDENTE,
        )
    ).all()
    for convite in pending_convites:
        convite.status = ConviteStatus.REMOVIDO
        session.add(convite)

    session.commit()
    return {"message": "Conta excluída com sucesso"}


def _resolve_plan_from_stripe(data_object: dict) -> str:
    """Resolve o plano a partir do metadata ou price_id do evento Stripe."""
    # 1. Metadata explícito (set during checkout)
    metadata = data_object.get("metadata") or {}
    plan = metadata.get("plan")
    if plan in ("essencial", "completo"):
        return plan

    # 2. Price ID mapping
    price_essencial = os.getenv("STRIPE_PRICE_ID_ESSENCIAL")
    price_completo = os.getenv("STRIPE_PRICE_ID_COMPLETO")
    price_legacy = os.getenv("STRIPE_PRICE_ID")

    # Check subscription items for price_id
    items = data_object.get("items", {}).get("data", [])
    for item in items:
        price_id = item.get("price", {}).get("id", "")
        if price_id == price_essencial:
            return "essencial"
        if price_id == price_completo:
            return "completo"
        if price_id == price_legacy:
            return "completo"  # Legacy subscribers get completo

    # 3. Default to completo (safe — gives full access)
    return "completo"


def _revogar_convites_por_expiracao(session: Session, user_id: UUID) -> None:
    """Remove convites ativos quando dono perde assinatura."""
    obras = session.exec(select(Obra).where(Obra.user_id == user_id)).all()
    for obra in obras:
        convites = session.exec(
            select(ObraConvite).where(
                ObraConvite.obra_id == obra.id,
                ObraConvite.status.in_([ConviteStatus.PENDENTE, ConviteStatus.ACEITO]),
            )
        ).all()
        for c in convites:
            c.status = "removido"
            c.accepted_at = None
            session.add(c)


@router.post("/api/webhooks/stripe")
async def stripe_webhook(
    request: Request,
    session: Session = Depends(get_session),
):
    """Webhook handler para eventos do Stripe."""
    import stripe

    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
    webhook_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    if not webhook_secret:
        raise HTTPException(status_code=503, detail="Webhook nao configurado")

    payload = await request.body()
    sig_header = request.headers.get("stripe-signature", "")

    try:
        event = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
    except (ValueError, stripe.error.SignatureVerificationError):
        raise HTTPException(status_code=400, detail="Assinatura do webhook inválida")

    event_type = event["type"]
    data_object = event["data"]["object"]

    stripe_event = StripeWebhookEvent(
        event_type=event_type,
        app_user_id=data_object.get("client_reference_id", data_object.get("customer", "")),
        product_id=data_object.get("id", ""),
        store="stripe",
        event_timestamp=datetime.now(timezone.utc),
        raw_payload=json.dumps(event, default=str),
    )
    session.add(stripe_event)

    if event_type == "checkout.session.completed":
        user_id = data_object.get("client_reference_id")
        customer_id = data_object.get("customer")
        stripe_sub_id = data_object.get("subscription")

        if user_id:
            try:
                user = session.get(User, UUID(user_id))
            except (ValueError, TypeError):
                user = None

            if user:
                resolved_plan = _resolve_plan_from_stripe(data_object)
                user.plan = resolved_plan
                user.updated_at = datetime.now(timezone.utc)
                session.add(user)

                sub = session.exec(
                    select(Subscription).where(Subscription.user_id == user.id)
                ).first()
                if not sub:
                    sub = Subscription(user_id=user.id)
                    session.add(sub)

                sub.plan = resolved_plan
                sub.status = "active"
                sub.stripe_customer_id = customer_id
                sub.store = "stripe"
                sub.stripe_subscription_id = stripe_sub_id
                sub.original_purchase_date = datetime.now(timezone.utc)
                sub.updated_at = datetime.now(timezone.utc)

                if stripe_sub_id:
                    try:
                        stripe_sub = stripe.Subscription.retrieve(stripe_sub_id)
                        sub.expires_at = datetime.fromtimestamp(stripe_sub.current_period_end, tz=timezone.utc)
                    except Exception:
                        pass

                stripe_event.processed = True

    elif event_type in ("customer.subscription.updated", "customer.subscription.created"):
        customer_id = data_object.get("customer")
        status_val = data_object.get("status")

        sub = session.exec(
            select(Subscription).where(Subscription.stripe_customer_id == customer_id)
        ).first()

        if sub:
            user = session.get(User, sub.user_id)
            cancel_at_period_end = data_object.get("cancel_at_period_end", False)
            if status_val == "active":
                resolved_plan = _resolve_plan_from_stripe(data_object)
                # Se cancel_at_period_end=True, mantém cancel_pending para não sobrescrever.
                if not cancel_at_period_end:
                    sub.status = "active"
                else:
                    sub.status = "cancel_pending"
                sub.plan = resolved_plan
                period_end = data_object.get("current_period_end")
                if period_end:
                    sub.expires_at = datetime.fromtimestamp(period_end, tz=timezone.utc)
                if user:
                    user.plan = resolved_plan
                    user.updated_at = datetime.now(timezone.utc)
                    session.add(user)
            elif status_val == "past_due":
                sub.status = "grace_period"
            elif status_val in ("canceled", "unpaid"):
                sub.status = "cancelled"
                sub.plan = "gratuito"
                if user:
                    user.plan = "gratuito"
                    user.updated_at = datetime.now(timezone.utc)
                    session.add(user)
            sub.updated_at = datetime.now(timezone.utc)
            stripe_event.processed = True

    elif event_type == "customer.subscription.deleted":
        customer_id = data_object.get("customer")
        sub = session.exec(
            select(Subscription).where(Subscription.stripe_customer_id == customer_id)
        ).first()
        if sub:
            user = session.get(User, sub.user_id)
            sub.status = "expired"
            sub.plan = "gratuito"
            sub.updated_at = datetime.now(timezone.utc)
            if user:
                user.plan = "gratuito"
                user.updated_at = datetime.now(timezone.utc)
                session.add(user)
                _revogar_convites_por_expiracao(session, user.id)
            stripe_event.processed = True

    elif event_type == "invoice.payment_failed":
        customer_id = data_object.get("customer")
        sub = session.exec(
            select(Subscription).where(Subscription.stripe_customer_id == customer_id)
        ).first()
        if sub:
            sub.status = "grace_period"
            sub.updated_at = datetime.now(timezone.utc)
            stripe_event.processed = True

    session.commit()
    return {"ok": True}
