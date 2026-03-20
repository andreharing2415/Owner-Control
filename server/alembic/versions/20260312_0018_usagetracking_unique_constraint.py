"""usagetracking: add unique constraint on (user_id, feature, period)

Revision ID: 20260312_0018
Revises: 20260312_0017
Create Date: 2026-03-12 14:00:00.000000
"""
from alembic import op

revision = "20260312_0018"
down_revision = "20260312_0017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_usage_user_feature_period",
        "usagetracking",
        ["user_id", "feature", "period"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_usage_user_feature_period", "usagetracking", type_="unique")
