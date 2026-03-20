"""rename revenuecat fields to stripe + rename revenuecatevent table

Revision ID: 20260312_0019
Revises: 20260312_0018
Create Date: 2026-03-12 18:00:00.000000
"""
from alembic import op

revision = "20260312_0019"
down_revision = "20260312_0018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rename column in subscription table
    op.alter_column("subscription", "revenuecat_customer_id", new_column_name="stripe_customer_id")
    op.alter_column("subscription", "product_id", new_column_name="stripe_subscription_id")

    # Rename table revenuecatevent -> stripewebhookevent
    op.rename_table("revenuecatevent", "stripewebhookevent")


def downgrade() -> None:
    op.rename_table("stripewebhookevent", "revenuecatevent")
    op.alter_column("subscription", "stripe_subscription_id", new_column_name="product_id")
    op.alter_column("subscription", "stripe_customer_id", new_column_name="revenuecat_customer_id")
