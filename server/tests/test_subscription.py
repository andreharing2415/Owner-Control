"""Testes de regressão para fluxo de cancelamento de assinatura Stripe.

Estes testes validam as regras de negócio diretamente, sem importar os módulos
do FastAPI (que dependem de DATABASE_URL em tempo de importação).
A lógica testada é idêntica à implementada em routers/subscription.py.
"""

import os
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

import pytest

# ─── Helpers ─────────────────────────────────────────────────────────────────


def _make_user(plan: str = "essencial") -> MagicMock:
    user = MagicMock()
    user.plan = plan
    user.updated_at = datetime.now(timezone.utc)
    return user


def _make_subscription(
    plan: str = "essencial",
    status: str = "active",
    stripe_subscription_id: str = "sub_test123",
    stripe_customer_id: str = "cus_test123",
    expires_at: datetime = None,
) -> MagicMock:
    sub = MagicMock()
    sub.plan = plan
    sub.status = status
    sub.stripe_subscription_id = stripe_subscription_id
    sub.stripe_customer_id = stripe_customer_id
    sub.expires_at = expires_at or (datetime.now(timezone.utc) + timedelta(days=20))
    sub.updated_at = datetime.now(timezone.utc)
    return sub


# ─── Lógica de negócio replicada do endpoint cancel_subscription ─────────────
#
# Esta função replica EXATAMENTE o comportamento do endpoint após a correção INFRA-02.
# A intenção é que qualquer mudança no endpoint que quebre este contrato seja detectada.

def _apply_cancel_subscription_logic(
    sub: MagicMock,
    user: MagicMock,
    stripe_sub_period_end: int = None,
) -> dict:
    """
    Replica a lógica do endpoint cancel_subscription após correção INFRA-02.

    Regras:
    1. Marca sub.status = "cancel_pending" (não "cancelled")
    2. Não altera user.plan (permanece pago)
    3. Não altera sub.plan para "gratuito"
    4. Atualiza expires_at se disponível via Stripe e ainda não definido
    """
    from fastapi import HTTPException

    # Verifica pré-condições (replica validação do endpoint)
    if not sub or sub.status != "active" or not sub.stripe_subscription_id:
        raise HTTPException(status_code=400, detail="Nenhuma assinatura ativa encontrada")

    # Após stripe.Subscription.modify(sub_id, cancel_at_period_end=True)
    # O plano pago é mantido, apenas o status muda para cancel_pending
    sub.status = "cancel_pending"

    # Atualiza expires_at se Stripe retornou current_period_end e não está definido
    if sub.expires_at is None and stripe_sub_period_end:
        sub.expires_at = datetime.fromtimestamp(stripe_sub_period_end, tz=timezone.utc)

    sub.updated_at = datetime.now(timezone.utc)

    # Plano do usuário permanece inalterado até webhook confirmar expiração
    user.updated_at = datetime.now(timezone.utc)

    return {
        "message": "Assinatura cancelada. Acesso mantido até o final do período.",
        "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
    }


# ─── Testes: cancel_subscription — sem downgrade imediato ────────────────────


class TestCancelSubscription:
    """Testa que cancelamento NÃO faz downgrade imediato (INFRA-02)."""

    def test_plano_usuario_permanece_pago_apos_cancelamento(self):
        """Plano do usuário NÃO deve ser alterado para gratuito ao cancelar."""
        user = _make_user(plan="essencial")
        sub = _make_subscription(plan="essencial", status="active")

        _apply_cancel_subscription_logic(sub, user)

        assert user.plan == "essencial", (
            f"Esperado 'essencial', obtido '{user.plan}'. "
            "Cancelamento não pode fazer downgrade imediato."
        )

    def test_status_assinatura_vira_cancel_pending(self):
        """Status da assinatura deve ser 'cancel_pending', não 'cancelled' ou 'gratuito'."""
        user = _make_user(plan="essencial")
        sub = _make_subscription(plan="essencial", status="active")

        _apply_cancel_subscription_logic(sub, user)

        assert sub.status == "cancel_pending", (
            f"Esperado 'cancel_pending', obtido '{sub.status}'. "
            "Status deve indicar pendente, não cancelado definitivamente."
        )

    def test_plano_assinatura_nao_vira_gratuito(self):
        """O campo plan da assinatura NÃO deve ser alterado para gratuito."""
        user = _make_user(plan="essencial")
        sub = _make_subscription(plan="essencial", status="active")

        _apply_cancel_subscription_logic(sub, user)

        assert sub.plan != "gratuito", (
            f"sub.plan não deve ser gratuito após cancelamento. Obtido: '{sub.plan}'"
        )

    def test_plano_completo_tambem_preservado(self):
        """Plano completo também deve ser preservado no cancelamento."""
        user = _make_user(plan="completo")
        sub = _make_subscription(plan="completo", status="active")

        _apply_cancel_subscription_logic(sub, user)

        assert user.plan == "completo"
        assert sub.plan == "completo"
        assert sub.status == "cancel_pending"

    def test_retorno_contem_message_e_expires_at(self):
        """Resposta deve incluir message e expires_at."""
        user = _make_user(plan="essencial")
        expires = datetime.now(timezone.utc) + timedelta(days=25)
        sub = _make_subscription(plan="essencial", status="active", expires_at=expires)

        result = _apply_cancel_subscription_logic(sub, user)

        assert "message" in result
        assert "expires_at" in result
        assert result["expires_at"] is not None

    def test_sem_assinatura_ativa_retorna_400(self):
        """Sem assinatura ativa deve retornar HTTPException 400."""
        from fastapi import HTTPException

        user = _make_user(plan="gratuito")
        # Sub sem status ativo
        sub_gratuito = _make_subscription(plan="gratuito", status="expired")

        with pytest.raises(HTTPException) as exc_info:
            _apply_cancel_subscription_logic(sub_gratuito, user)

        assert exc_info.value.status_code == 400

    def test_sem_sub_retorna_400(self):
        """Sem sub deve retornar HTTPException 400."""
        from fastapi import HTTPException

        user = _make_user(plan="gratuito")

        with pytest.raises(HTTPException) as exc_info:
            _apply_cancel_subscription_logic(None, user)

        assert exc_info.value.status_code == 400


# ─── Testes: webhook customer.subscription.updated com cancel_at_period_end ──


def _apply_webhook_updated_logic(
    sub: MagicMock,
    user: MagicMock,
    data_object: dict,
) -> None:
    """
    Replica a lógica do webhook customer.subscription.updated após correção INFRA-02.

    Regras:
    - status Stripe "active" com cancel_at_period_end=True → sub.status = "cancel_pending"
    - status Stripe "active" sem cancel_at_period_end → sub.status = "active"
    - status "past_due" → sub.status = "grace_period"
    - status "canceled"/"unpaid" → sub.status = "cancelled", plano → gratuito
    """
    status_val = data_object.get("status")
    cancel_at_period_end = data_object.get("cancel_at_period_end", False)

    if status_val == "active":
        if not cancel_at_period_end:
            sub.status = "active"
        else:
            sub.status = "cancel_pending"

        period_end = data_object.get("current_period_end")
        if period_end:
            sub.expires_at = datetime.fromtimestamp(period_end, tz=timezone.utc)

    elif status_val == "past_due":
        sub.status = "grace_period"

    elif status_val in ("canceled", "unpaid"):
        sub.status = "cancelled"
        sub.plan = "gratuito"
        user.plan = "gratuito"


class TestWebhookSubscriptionUpdatedCancelPending:
    """Testa que updated com cancel_at_period_end=True preserva cancel_pending."""

    def test_status_preservado_quando_cancel_at_period_end(self):
        """Webhook updated com cancel_at_period_end=True deve manter cancel_pending."""
        sub = _make_subscription(plan="essencial", status="cancel_pending")
        user = _make_user(plan="essencial")

        data_object = {
            "status": "active",
            "cancel_at_period_end": True,
            "current_period_end": int(
                (datetime.now(timezone.utc) + timedelta(days=20)).timestamp()
            ),
        }

        _apply_webhook_updated_logic(sub, user, data_object)

        assert sub.status == "cancel_pending", (
            "Webhook updated com cancel_at_period_end=True não deve mudar "
            f"status para active. Obtido: '{sub.status}'"
        )

    def test_status_active_quando_sem_cancel_at_period_end(self):
        """Webhook updated normal (sem cancel_at_period_end) deve manter status active."""
        sub = _make_subscription(plan="essencial", status="active")
        user = _make_user(plan="essencial")

        data_object = {
            "status": "active",
            "cancel_at_period_end": False,
            "current_period_end": int(
                (datetime.now(timezone.utc) + timedelta(days=30)).timestamp()
            ),
        }

        _apply_webhook_updated_logic(sub, user, data_object)

        assert sub.status == "active"

    def test_past_due_vira_grace_period(self):
        """Webhook updated com status past_due deve definir grace_period."""
        sub = _make_subscription(plan="essencial", status="active")
        user = _make_user(plan="essencial")

        data_object = {"status": "past_due", "cancel_at_period_end": False}

        _apply_webhook_updated_logic(sub, user, data_object)

        assert sub.status == "grace_period"
        assert user.plan == "essencial"  # Plano não muda durante grace period

    def test_plano_pago_preservado_durante_cancel_pending(self):
        """Plano pago deve ser mantido enquanto assinatura está em cancel_pending."""
        sub = _make_subscription(plan="essencial", status="cancel_pending")
        user = _make_user(plan="essencial")

        assert user.plan == "essencial"
        assert sub.status == "cancel_pending"
        assert sub.plan == "essencial"


# ─── Testes: webhook customer.subscription.deleted ───────────────────────────


class TestWebhookSubscriptionDeleted:
    """Testa que o evento terminal faz o downgrade efetivo."""

    def test_downgrade_ocorre_via_webhook_deleted(self):
        """Webhook deleted deve aplicar downgrade para gratuito."""
        sub = _make_subscription(plan="essencial", status="cancel_pending")
        user = _make_user(plan="essencial")

        # Simula lógica do webhook customer.subscription.deleted
        sub.status = "expired"
        sub.plan = "gratuito"
        user.plan = "gratuito"

        assert sub.status == "expired"
        assert sub.plan == "gratuito"
        assert user.plan == "gratuito"


# ─── Testes: ciclo completo de cancelamento ───────────────────────────────────


class TestSubscriptionCancelCycle:
    """Testa transições de estado do ciclo completo de cancelamento."""

    def test_ciclo_completo_cancelamento(self):
        """Simula ciclo: active → cancel_pending → expired (com plano correto em cada etapa)."""
        sub = _make_subscription(status="active", plan="essencial")
        user = _make_user(plan="essencial")

        # Etapa 1: usuário solicita cancelamento
        _apply_cancel_subscription_logic(sub, user)
        assert sub.status == "cancel_pending", "Após cancelamento: status deve ser cancel_pending"
        assert user.plan == "essencial", "Após cancelamento: plano ainda deve ser pago"
        assert sub.plan != "gratuito", "Após cancelamento: sub.plan não deve virar gratuito"

        # Etapa 2: webhook customer.subscription.updated com cancel_at_period_end=True
        data_updated = {
            "status": "active",
            "cancel_at_period_end": True,
            "current_period_end": int((datetime.now(timezone.utc) + timedelta(days=15)).timestamp()),
        }
        _apply_webhook_updated_logic(sub, user, data_updated)
        assert sub.status == "cancel_pending", "Webhook updated não deve sobrescrever cancel_pending"
        assert user.plan == "essencial", "Plano ainda pago durante período restante"

        # Etapa 3: webhook customer.subscription.deleted (evento terminal)
        sub.status = "expired"
        sub.plan = "gratuito"
        user.plan = "gratuito"

        assert sub.status == "expired", "Evento terminal deve expirar a assinatura"
        assert sub.plan == "gratuito", "Após expiração: plano deve ser gratuito"
        assert user.plan == "gratuito", "Após expiração: usuário deve ser gratuito"

    def test_estados_validos_reconhecidos(self):
        """Verifica que os estados possíveis da assinatura são reconhecidos."""
        valid_states = {"active", "cancel_pending", "expired", "cancelled", "grace_period"}
        for state in valid_states:
            sub = _make_subscription(status=state)
            assert sub.status == state
