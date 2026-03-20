"""add valor_realizado to orcamentoetapa

Revision ID: 20260309_0014
Revises: 20260311_0013
Create Date: 2026-03-09 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260309_0014"
down_revision = "20260311_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("orcamentoetapa", sa.Column("valor_realizado", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("orcamentoetapa", "valor_realizado")
