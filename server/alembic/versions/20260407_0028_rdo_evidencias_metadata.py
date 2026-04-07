"""rdo_evidencias_metadata

Revision ID: 20260407_0028
Revises: 20260406_0027
Create Date: 2026-04-07

Cria tabela de RDO diário e adiciona metadados de geotag/timestamp/vínculo de atividade em evidências.
"""

from alembic import op
import sqlalchemy as sa


revision = "20260407_0028"
down_revision = "20260406_0027"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "rdodiario",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("obra_id", sa.Uuid(), nullable=False),
        sa.Column("data_referencia", sa.Date(), nullable=False),
        sa.Column("clima", sa.String(), nullable=False),
        sa.Column("mao_obra_total", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("atividades_executadas", sa.String(), nullable=False),
        sa.Column("observacoes", sa.String(), nullable=True),
        sa.Column("fotos_urls", sa.String(), nullable=True),
        sa.Column("publicado", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("publicado_em", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["obra_id"], ["obra.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_rdodiario_obra_id", "rdodiario", ["obra_id"])
    op.create_index("ix_rdodiario_data_referencia", "rdodiario", ["data_referencia"])

    op.add_column("evidencia", sa.Column("atividade_id", sa.Uuid(), nullable=True))
    op.add_column("evidencia", sa.Column("latitude", sa.Float(), nullable=True))
    op.add_column("evidencia", sa.Column("longitude", sa.Float(), nullable=True))
    op.add_column("evidencia", sa.Column("capturado_em", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_evidencia_atividade_id", "evidencia", ["atividade_id"])
    op.create_foreign_key(
        "fk_evidencia_atividade_id_atividadecronograma",
        "evidencia",
        "atividadecronograma",
        ["atividade_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint("fk_evidencia_atividade_id_atividadecronograma", "evidencia", type_="foreignkey")
    op.drop_index("ix_evidencia_atividade_id", table_name="evidencia")
    op.drop_column("evidencia", "capturado_em")
    op.drop_column("evidencia", "longitude")
    op.drop_column("evidencia", "latitude")
    op.drop_column("evidencia", "atividade_id")

    op.drop_index("ix_rdodiario_data_referencia", table_name="rdodiario")
    op.drop_index("ix_rdodiario_obra_id", table_name="rdodiario")
    op.drop_table("rdodiario")
