"""fase 2 - tabelas de normas

Revision ID: 20260219_0002
Revises: 20260216_0001
Create Date: 2026-02-19 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260219_0002"
down_revision = "20260216_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "normalog",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("etapa_nome", sa.String(), nullable=False),
        sa.Column("disciplina", sa.String(), nullable=True),
        sa.Column("localizacao", sa.String(), nullable=True),
        sa.Column("query_texto", sa.Text(), nullable=False),
        sa.Column("data_consulta", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    op.create_table(
        "normaresultado",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("norma_log_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("titulo", sa.String(), nullable=False),
        sa.Column("fonte_nome", sa.String(), nullable=False),
        sa.Column("fonte_url", sa.String(), nullable=True),
        sa.Column("fonte_tipo", sa.String(), nullable=False),
        sa.Column("versao", sa.String(), nullable=True),
        sa.Column("data_norma", sa.String(), nullable=True),
        sa.Column("trecho_relevante", sa.Text(), nullable=True),
        sa.Column("traducao_leigo", sa.Text(), nullable=False),
        sa.Column("nivel_confianca", sa.Integer(), nullable=False),
        sa.Column("risco_nivel", sa.String(), nullable=True),
        sa.Column("requer_validacao_profissional", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["norma_log_id"], ["normalog.id"]),
    )
    op.create_index("ix_normaresultado_norma_log_id", "normaresultado", ["norma_log_id"])


def downgrade() -> None:
    op.drop_index("ix_normaresultado_norma_log_id", table_name="normaresultado")
    op.drop_table("normaresultado")
    op.drop_table("normalog")
