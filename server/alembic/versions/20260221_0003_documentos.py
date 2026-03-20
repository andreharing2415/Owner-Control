"""fase 3 - tabelas de projetos e riscos (Document AI)

Revision ID: 20260221_0003
Revises: 20260219_0002
Create Date: 2026-02-21 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260221_0003"
down_revision = "20260219_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "projetodoc",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("obra_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("arquivo_url", sa.String(), nullable=False),
        sa.Column("arquivo_nome", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="pendente"),
        sa.Column("resumo_geral", sa.Text(), nullable=True),
        sa.Column("aviso_legal", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["obra_id"], ["obra.id"]),
    )
    op.create_index("ix_projetodoc_obra_id", "projetodoc", ["obra_id"])

    op.create_table(
        "risco",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("projeto_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("descricao", sa.Text(), nullable=False),
        sa.Column("severidade", sa.String(), nullable=False),
        sa.Column("norma_referencia", sa.String(), nullable=True),
        sa.Column("traducao_leigo", sa.Text(), nullable=False),
        sa.Column("requer_validacao_profissional", sa.Boolean(), nullable=False),
        sa.Column("confianca", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["projeto_id"], ["projetodoc.id"]),
    )
    op.create_index("ix_risco_projeto_id", "risco", ["projeto_id"])


def downgrade() -> None:
    op.drop_index("ix_risco_projeto_id", table_name="risco")
    op.drop_table("risco")
    op.drop_index("ix_projetodoc_obra_id", table_name="projetodoc")
    op.drop_table("projetodoc")
