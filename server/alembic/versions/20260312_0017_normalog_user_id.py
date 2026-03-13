"""normalog: add user_id for LGPD scoping

Revision ID: 20260312_0017
Revises: 20260311_0016
Create Date: 2026-03-12 10:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260312_0017"
down_revision = "20260311_0016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("normalog", sa.Column("user_id", sa.Uuid(), nullable=True))
    op.create_index(op.f("ix_normalog_user_id"), "normalog", ["user_id"], unique=False)
    op.create_foreign_key("fk_normalog_user_id", "normalog", "user", ["user_id"], ["id"])


def downgrade() -> None:
    op.drop_constraint("fk_normalog_user_id", "normalog", type_="foreignkey")
    op.drop_index(op.f("ix_normalog_user_id"), table_name="normalog")
    op.drop_column("normalog", "user_id")
