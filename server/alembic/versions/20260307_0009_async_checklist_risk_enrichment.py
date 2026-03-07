"""async checklist processing + risk enrichment fields

Revision ID: 20260307_0009
Revises: 20260227_0008
Create Date: 2026-03-07 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260307_0009"
down_revision = "20260227_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. New table: checklistgeracaoitem — stores suggested items per generation log
    op.create_table(
        "checklistgeracaoitem",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("log_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("etapa_nome", sa.String(), nullable=False),
        sa.Column("titulo", sa.String(), nullable=False),
        sa.Column("descricao", sa.Text(), nullable=False),
        sa.Column("norma_referencia", sa.String(), nullable=True),
        sa.Column("critico", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("risco_nivel", sa.String(), nullable=False, server_default="baixo"),
        sa.Column("requer_validacao_profissional", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("confianca", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("como_verificar", sa.Text(), nullable=False, server_default=""),
        sa.Column("medidas_minimas", sa.Text(), nullable=True),
        sa.Column("explicacao_leigo", sa.Text(), nullable=False, server_default=""),
        sa.Column("caracteristica_origem", sa.String(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["log_id"], ["checklistgeracaolog.id"]),
    )
    op.create_index("ix_checklistgeracaoitem_id", "checklistgeracaoitem", ["id"])
    op.create_index("ix_checklistgeracaoitem_log_id", "checklistgeracaoitem", ["log_id"])

    # 2. New columns on checklistgeracaolog for progress tracking
    op.add_column("checklistgeracaolog", sa.Column("total_paginas", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("checklistgeracaolog", sa.Column("paginas_processadas", sa.Integer(), nullable=False, server_default="0"))

    # 3. New columns on risco for owner-oriented guidance
    op.add_column("risco", sa.Column("norma_url", sa.String(), nullable=True))
    op.add_column("risco", sa.Column("acao_proprietario", sa.Text(), nullable=True))
    op.add_column("risco", sa.Column("perguntas_para_profissional", sa.Text(), nullable=True))  # JSON string
    op.add_column("risco", sa.Column("documentos_a_exigir", sa.Text(), nullable=True))  # JSON string


def downgrade() -> None:
    op.drop_column("risco", "documentos_a_exigir")
    op.drop_column("risco", "perguntas_para_profissional")
    op.drop_column("risco", "acao_proprietario")
    op.drop_column("risco", "norma_url")
    op.drop_column("checklistgeracaolog", "paginas_processadas")
    op.drop_column("checklistgeracaolog", "total_paginas")
    op.drop_index("ix_checklistgeracaoitem_log_id", table_name="checklistgeracaoitem")
    op.drop_index("ix_checklistgeracaoitem_id", table_name="checklistgeracaoitem")
    op.drop_table("checklistgeracaoitem")
