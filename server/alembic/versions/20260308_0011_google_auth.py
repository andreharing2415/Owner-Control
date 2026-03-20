"""add google_id to user, make password_hash nullable

Revision ID: 20260308_0011
Revises: 20260308_0010
Create Date: 2026-03-08 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260308_0011"
down_revision = "20260308_0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("user", sa.Column("google_id", sa.String(), nullable=True))
    op.create_unique_constraint("uq_user_google_id", "user", ["google_id"])
    op.create_index("ix_user_google_id", "user", ["google_id"])
    op.alter_column("user", "password_hash", nullable=True)


def downgrade() -> None:
    op.alter_column("user", "password_hash", nullable=False)
    op.drop_index("ix_user_google_id", table_name="user")
    op.drop_constraint("uq_user_google_id", "user", type_="unique")
    op.drop_column("user", "google_id")
