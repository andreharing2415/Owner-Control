"""Add disciplina column to risco table

Revision ID: 20260312_0021
Revises: 20260312_0020
Create Date: 2026-03-12 21:00:00.000000
"""
import sqlalchemy as sa
from alembic import op

revision = "20260312_0021"
down_revision = "20260312_0020"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("risco", sa.Column("disciplina", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("risco", "disciplina")
