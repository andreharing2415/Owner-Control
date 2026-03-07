"""initial schema

Revision ID: 20260216_0001
Revises: 
Create Date: 2026-02-16 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260216_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "obra",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("nome", sa.String(), nullable=False),
        sa.Column("data_inicio", sa.Date(), nullable=True),
        sa.Column("data_fim", sa.Date(), nullable=True),
        sa.Column("orcamento", sa.Float(), nullable=True),
        sa.Column("localizacao", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    op.create_table(
        "etapa",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("obra_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("nome", sa.String(), nullable=False),
        sa.Column("ordem", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("score", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["obra_id"], ["obra.id"]),
    )
    op.create_index("ix_etapa_obra_id", "etapa", ["obra_id"])

    op.create_table(
        "checklistitem",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("etapa_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("titulo", sa.String(), nullable=False),
        sa.Column("descricao", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("critico", sa.Boolean(), nullable=False),
        sa.Column("observacao", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["etapa_id"], ["etapa.id"]),
    )
    op.create_index("ix_checklistitem_etapa_id", "checklistitem", ["etapa_id"])

    op.create_table(
        "evidencia",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("checklist_item_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("arquivo_url", sa.String(), nullable=False),
        sa.Column("arquivo_nome", sa.String(), nullable=False),
        sa.Column("mime_type", sa.String(), nullable=True),
        sa.Column("tamanho_bytes", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["checklist_item_id"], ["checklistitem.id"]),
    )
    op.create_index("ix_evidencia_checklist_item_id", "evidencia", ["checklist_item_id"])


def downgrade() -> None:
    op.drop_index("ix_evidencia_checklist_item_id", table_name="evidencia")
    op.drop_table("evidencia")
    op.drop_index("ix_checklistitem_etapa_id", table_name="checklistitem")
    op.drop_table("checklistitem")
    op.drop_index("ix_etapa_obra_id", table_name="etapa")
    op.drop_table("etapa")
    op.drop_table("obra")
