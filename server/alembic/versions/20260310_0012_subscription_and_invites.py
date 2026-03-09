"""subscription system, usage tracking, invites, etapa comments

Revision ID: 20260310_0012
Revises: 20260308_0011
Create Date: 2026-03-10 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260310_0012"
down_revision = "20260308_0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # User.plan column
    op.add_column("user", sa.Column("plan", sa.String(), nullable=False, server_default="gratuito"))

    # Subscription table
    op.create_table(
        "subscription",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("user.id"), unique=True, nullable=False),
        sa.Column("plan", sa.String(), nullable=False, server_default="gratuito"),
        sa.Column("status", sa.String(), nullable=False, server_default="active"),
        sa.Column("revenuecat_customer_id", sa.String(), nullable=True),
        sa.Column("store", sa.String(), nullable=True),
        sa.Column("product_id", sa.String(), nullable=True),
        sa.Column("original_purchase_date", sa.DateTime(), nullable=True),
        sa.Column("expires_at", sa.DateTime(), nullable=True),
        sa.Column("grace_period_expires_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_subscription_id", "subscription", ["id"])
    op.create_index("ix_subscription_user_id", "subscription", ["user_id"])
    op.create_index("ix_subscription_revenuecat_customer_id", "subscription", ["revenuecat_customer_id"])

    # UsageTracking table
    op.create_table(
        "usagetracking",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("user.id"), nullable=False),
        sa.Column("feature", sa.String(), nullable=False),
        sa.Column("period", sa.String(), nullable=False),
        sa.Column("count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_usagetracking_id", "usagetracking", ["id"])
    op.create_index("ix_usagetracking_user_id", "usagetracking", ["user_id"])
    op.create_unique_constraint(
        "uq_usagetracking_user_feature_period",
        "usagetracking",
        ["user_id", "feature", "period"],
    )

    # RevenueCatEvent table
    op.create_table(
        "revenuecatevent",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column("app_user_id", sa.String(), nullable=False),
        sa.Column("product_id", sa.String(), nullable=True),
        sa.Column("store", sa.String(), nullable=True),
        sa.Column("event_timestamp", sa.DateTime(), nullable=True),
        sa.Column("expiration_at", sa.DateTime(), nullable=True),
        sa.Column("raw_payload", sa.Text(), nullable=True),
        sa.Column("processed", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_revenuecatevent_id", "revenuecatevent", ["id"])
    op.create_index("ix_revenuecatevent_app_user_id", "revenuecatevent", ["app_user_id"])

    # ObraConvite table
    op.create_table(
        "obraconvite",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("obra_id", sa.Uuid(), sa.ForeignKey("obra.id"), nullable=False),
        sa.Column("dono_id", sa.Uuid(), sa.ForeignKey("user.id"), nullable=False),
        sa.Column("convidado_id", sa.Uuid(), sa.ForeignKey("user.id"), nullable=True),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("papel", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="pendente"),
        sa.Column("token", sa.String(), nullable=False),
        sa.Column("token_expires_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("accepted_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_obraconvite_id", "obraconvite", ["id"])
    op.create_index("ix_obraconvite_obra_id", "obraconvite", ["obra_id"])
    op.create_index("ix_obraconvite_token", "obraconvite", ["token"])

    # EtapaComentario table
    op.create_table(
        "etapacomentario",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("etapa_id", sa.Uuid(), sa.ForeignKey("etapa.id"), nullable=False),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("user.id"), nullable=False),
        sa.Column("texto", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_etapacomentario_id", "etapacomentario", ["id"])
    op.create_index("ix_etapacomentario_etapa_id", "etapacomentario", ["etapa_id"])


def downgrade() -> None:
    op.drop_table("etapacomentario")
    op.drop_table("obraconvite")
    op.drop_table("revenuecatevent")
    op.drop_constraint("uq_usagetracking_user_feature_period", "usagetracking", type_="unique")
    op.drop_table("usagetracking")
    op.drop_table("subscription")
    op.drop_column("user", "plan")
