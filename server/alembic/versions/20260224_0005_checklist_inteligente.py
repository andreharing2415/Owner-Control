"""fase 6 - checklist inteligente: campos origem/norma_referencia + tabela log

Revision ID: 20260224_0005
Revises: 20260222_0004
Create Date: 2026-02-24 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260224_0005"
down_revision = "20260222_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Novos campos em checklistitem
    op.add_column("checklistitem", sa.Column("norma_referencia", sa.String(), nullable=True))
    op.add_column("checklistitem", sa.Column("origem", sa.String(), nullable=False, server_default="padrao"))

    # Tabela de log de geracoes de checklist inteligente
    op.create_table(
        "checklistgeracaolog",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("obra_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="processando"),
        sa.Column("total_docs_analisados", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("caracteristicas_identificadas", sa.Text(), nullable=True),
        sa.Column("total_itens_sugeridos", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_itens_aplicados", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("resumo_geral", sa.Text(), nullable=True),
        sa.Column("aviso_legal", sa.Text(), nullable=True),
        sa.Column("erro_detalhe", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["obra_id"], ["obra.id"]),
    )
    op.create_index("ix_checklistgeracaolog_id", "checklistgeracaolog", ["id"])
    op.create_index("ix_checklistgeracaolog_obra_id", "checklistgeracaolog", ["obra_id"])


def downgrade() -> None:
    op.drop_index("ix_checklistgeracaolog_obra_id", table_name="checklistgeracaolog")
    op.drop_index("ix_checklistgeracaolog_id", table_name="checklistgeracaolog")
    op.drop_table("checklistgeracaolog")
    op.drop_column("checklistitem", "origem")
    op.drop_column("checklistitem", "norma_referencia")
