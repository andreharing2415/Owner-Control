"""fase 5 - tabelas de prestadores e avaliacoes

Revision ID: 20260222_0004
Revises: 20260221_0003
Create Date: 2026-02-22 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260222_0004"
down_revision = "20260221_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "prestador",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("nome", sa.String(), nullable=False),
        sa.Column("categoria", sa.String(), nullable=False),
        sa.Column("subcategoria", sa.String(), nullable=False),
        sa.Column("regiao", sa.String(), nullable=True),
        sa.Column("telefone", sa.String(), nullable=True),
        sa.Column("email", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_prestador_id", "prestador", ["id"])
    op.create_index("ix_prestador_categoria", "prestador", ["categoria"])
    op.create_index("ix_prestador_regiao", "prestador", ["regiao"])

    op.create_table(
        "avaliacao",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("prestador_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("nota_qualidade_servico", sa.Integer(), nullable=True),
        sa.Column("nota_cumprimento_prazos", sa.Integer(), nullable=True),
        sa.Column("nota_fidelidade_projeto", sa.Integer(), nullable=True),
        sa.Column("nota_prazo_entrega", sa.Integer(), nullable=True),
        sa.Column("nota_qualidade_material", sa.Integer(), nullable=True),
        sa.Column("comentario", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["prestador_id"], ["prestador.id"]),
    )
    op.create_index("ix_avaliacao_id", "avaliacao", ["id"])
    op.create_index("ix_avaliacao_prestador_id", "avaliacao", ["prestador_id"])


def downgrade() -> None:
    op.drop_index("ix_avaliacao_prestador_id", table_name="avaliacao")
    op.drop_index("ix_avaliacao_id", table_name="avaliacao")
    op.drop_table("avaliacao")
    op.drop_index("ix_prestador_regiao", table_name="prestador")
    op.drop_index("ix_prestador_categoria", table_name="prestador")
    op.drop_index("ix_prestador_id", table_name="prestador")
    op.drop_table("prestador")
