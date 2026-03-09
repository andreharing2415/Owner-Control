"""checklist grupo/ordem + etapa prazo

Revision ID: 20260308_0010
Revises: 20260307_0009
Create Date: 2026-03-08 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260308_0010"
down_revision = "20260307_0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("checklistitem",
        sa.Column("grupo", sa.String(), nullable=False, server_default="Geral"))
    op.add_column("checklistitem",
        sa.Column("ordem", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("etapa",
        sa.Column("prazo_previsto", sa.Date(), nullable=True))
    op.add_column("etapa",
        sa.Column("prazo_executado", sa.Date(), nullable=True))


def downgrade() -> None:
    op.drop_column("etapa", "prazo_executado")
    op.drop_column("etapa", "prazo_previsto")
    op.drop_column("checklistitem", "ordem")
    op.drop_column("checklistitem", "grupo")
