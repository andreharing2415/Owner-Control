"""atividadecronograma_flags_modificacao

Revision ID: 20260406_0026
Revises: 20260406_0025
Create Date: 2026-04-06

Adiciona colunas is_modified e locked em AtividadeCronograma para
preservar edicoes manuais do engenheiro durante reprocessamento de cronograma.
"""
from alembic import op
import sqlalchemy as sa

revision = "20260406_0026"
down_revision = "20260406_0025"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "atividadecronograma",
        sa.Column("is_modified", sa.Boolean(), nullable=False, server_default="false"),
    )
    op.add_column(
        "atividadecronograma",
        sa.Column("locked", sa.Boolean(), nullable=False, server_default="false"),
    )


def downgrade() -> None:
    op.drop_column("atividadecronograma", "locked")
    op.drop_column("atividadecronograma", "is_modified")
