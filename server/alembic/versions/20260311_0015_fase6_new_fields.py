"""fase 6: obra area_m2, checklist new fields, obra_detalhamento table

Revision ID: 20260311_0015
Revises: 20260309_0014b
Create Date: 2026-03-11 12:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260311_0015"
down_revision = "20260309_0014b"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Obra: area_m2
    op.add_column("obra", sa.Column("area_m2", sa.Float(), nullable=True))

    # ChecklistItem: new fields
    op.add_column("checklistitem", sa.Column("projeto_doc_id", sa.Uuid(), nullable=True))
    op.add_column("checklistitem", sa.Column("projeto_doc_nome", sa.String(), nullable=True))
    op.add_column("checklistitem", sa.Column("como_verificar", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("medidas_minimas", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("explicacao_leigo", sa.Text(), nullable=True))

    # Foreign key for projeto_doc_id
    op.create_foreign_key(
        "fk_checklistitem_projetodoc",
        "checklistitem", "projetodoc",
        ["projeto_doc_id"], ["id"],
    )

    # ObraDetalhamento table
    op.create_table(
        "obradetalhamento",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("obra_id", sa.Uuid(), sa.ForeignKey("obra.id"), nullable=False, index=True),
        sa.Column("comodos", sa.Text(), nullable=True),
        sa.Column("area_total_m2", sa.Float(), nullable=True),
        sa.Column("fonte_doc_id", sa.Uuid(), sa.ForeignKey("projetodoc.id"), nullable=True),
        sa.Column("fonte_doc_nome", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("obradetalhamento")
    op.drop_constraint("fk_checklistitem_projetodoc", "checklistitem", type_="foreignkey")
    op.drop_column("checklistitem", "explicacao_leigo")
    op.drop_column("checklistitem", "medidas_minimas")
    op.drop_column("checklistitem", "como_verificar")
    op.drop_column("checklistitem", "projeto_doc_nome")
    op.drop_column("checklistitem", "projeto_doc_id")
    op.drop_column("obra", "area_m2")
