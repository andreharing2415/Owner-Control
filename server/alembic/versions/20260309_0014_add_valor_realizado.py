"""add valor_realizado to orcamentoetapa

Revision ID: 20260309_0014b
Revises: 20260309_0014
Create Date: 2026-03-09 01:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260309_0014b"
down_revision = "20260309_0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("orcamentoetapa", sa.Column("valor_realizado", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("orcamentoetapa", "valor_realizado")
