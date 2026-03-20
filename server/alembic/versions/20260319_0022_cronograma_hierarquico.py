"""Add cronograma hierarquico tables and atividade_id FK

Revision ID: 20260319_0022
Revises: 20260312_0021
Create Date: 2026-03-19 00:00:00.000000
"""
import sqlalchemy as sa
from alembic import op

revision = "20260319_0022"
down_revision = "20260312_0021"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Add tipo to obra
    op.add_column("obra", sa.Column("tipo", sa.String(), nullable=False, server_default="construcao"))

    # 2. Create atividadecronograma table
    op.create_table(
        "atividadecronograma",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("obra_id", sa.Uuid(), sa.ForeignKey("obra.id"), nullable=False, index=True),
        sa.Column("parent_id", sa.Uuid(), sa.ForeignKey("atividadecronograma.id"), nullable=True, index=True),
        sa.Column("nome", sa.String(), nullable=False),
        sa.Column("descricao", sa.String(), nullable=True),
        sa.Column("ordem", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("nivel", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("status", sa.String(), nullable=False, server_default="pendente"),
        sa.Column("data_inicio_prevista", sa.Date(), nullable=True),
        sa.Column("data_fim_prevista", sa.Date(), nullable=True),
        sa.Column("data_inicio_real", sa.Date(), nullable=True),
        sa.Column("data_fim_real", sa.Date(), nullable=True),
        sa.Column("valor_previsto", sa.Float(), nullable=False, server_default="0"),
        sa.Column("valor_gasto", sa.Float(), nullable=False, server_default="0"),
        sa.Column("tipo_projeto", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_atividadecronograma_id", "atividadecronograma", ["id"])

    # 3. Create serviconecessario table
    op.create_table(
        "serviconecessario",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("atividade_id", sa.Uuid(), sa.ForeignKey("atividadecronograma.id"), nullable=False, index=True),
        sa.Column("descricao", sa.String(), nullable=False),
        sa.Column("categoria", sa.String(), nullable=False),
        sa.Column("prestador_id", sa.Uuid(), sa.ForeignKey("prestador.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_serviconecessario_id", "serviconecessario", ["id"])

    # 4. Add atividade_id to checklistitem
    op.add_column("checklistitem", sa.Column("atividade_id", sa.Uuid(), sa.ForeignKey("atividadecronograma.id"), nullable=True, index=True))

    # 5. Add atividade_id to despesa
    op.add_column("despesa", sa.Column("atividade_id", sa.Uuid(), sa.ForeignKey("atividadecronograma.id"), nullable=True, index=True))

    # 6. Make etapa_id nullable in checklistitem
    op.alter_column("checklistitem", "etapa_id", existing_type=sa.Uuid(), nullable=True)


def downgrade() -> None:
    # Reverse etapa_id nullable
    op.alter_column("checklistitem", "etapa_id", existing_type=sa.Uuid(), nullable=False)

    # Drop atividade_id from despesa
    op.drop_column("despesa", "atividade_id")

    # Drop atividade_id from checklistitem
    op.drop_column("checklistitem", "atividade_id")

    # Drop serviconecessario table
    op.drop_index("ix_serviconecessario_id", table_name="serviconecessario")
    op.drop_table("serviconecessario")

    # Drop atividadecronograma table
    op.drop_index("ix_atividadecronograma_id", table_name="atividadecronograma")
    op.drop_table("atividadecronograma")

    # Drop tipo from obra
    op.drop_column("obra", "tipo")
