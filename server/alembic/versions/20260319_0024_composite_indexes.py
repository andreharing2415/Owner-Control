"""PERF-05v2: Add composite indexes for frequently queried columns.

Revision ID: 20260319_0024
Revises: 20260319_0023
Create Date: 2026-03-19
"""

from alembic import op

# revision identifiers
revision = "20260319_0024"
down_revision = "20260319_0023"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "idx_projetodoc_obra_status",
        "projetodoc",
        ["obra_id", "status"],
    )
    op.create_index(
        "idx_checklistitem_etapa_status",
        "checklistitem",
        ["etapa_id", "status"],
    )
    op.create_index(
        "idx_despesa_obra_data",
        "despesa",
        ["obra_id", "data"],
    )
    op.create_index(
        "idx_atividade_obra_nivel",
        "atividadecronograma",
        ["obra_id", "nivel"],
    )
    op.create_index(
        "idx_normalog_user_date",
        "normalog",
        ["user_id", "data_consulta"],
    )
    op.create_index(
        "idx_etapa_obra_ordem",
        "etapa",
        ["obra_id", "ordem"],
    )


def downgrade() -> None:
    op.drop_index("idx_projetodoc_obra_status", table_name="projetodoc")
    op.drop_index("idx_checklistitem_etapa_status", table_name="checklistitem")
    op.drop_index("idx_despesa_obra_data", table_name="despesa")
    op.drop_index("idx_atividade_obra_nivel", table_name="atividadecronograma")
    op.drop_index("idx_normalog_user_date", table_name="normalog")
    op.drop_index("idx_etapa_obra_ordem", table_name="etapa")
