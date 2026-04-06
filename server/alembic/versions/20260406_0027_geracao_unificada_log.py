"""geracao_unificada_log

Revision ID: 20260406_0027
Revises: 20260406_0026
Create Date: 2026-04-06

Cria tabela geracaounificadalog para state machine de geracao assincrona
(cronograma + checklist). Estados: PENDENTE → ANALISANDO → GERANDO → CONCLUIDO | ERRO | CANCELADO.
"""
from alembic import op
import sqlalchemy as sa

revision = "20260406_0027"
down_revision = "20260406_0026"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "geracaounificadalog",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("obra_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="pendente"),
        sa.Column("etapa_atual", sa.String(), nullable=True),
        sa.Column("total_atividades", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("atividades_geradas", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_itens_checklist", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("erro_detalhe", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["obra_id"], ["obra.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_geracaounificadalog_obra_id", "geracaounificadalog", ["obra_id"])


def downgrade() -> None:
    op.drop_index("ix_geracaounificadalog_obra_id", table_name="geracaounificadalog")
    op.drop_table("geracaounificadalog")
