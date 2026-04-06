"""Add erro_detalhe column to projetodoc table.

Revision ID: 20260319_0023
Revises: 20260319_0022
Create Date: 2026-03-19
"""

from alembic import op
import sqlalchemy as sa

revision = "20260319_0023"
down_revision = "20260319_0022"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("projetodoc", sa.Column("erro_detalhe", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("projetodoc", "erro_detalhe")
