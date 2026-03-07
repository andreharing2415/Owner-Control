"""avaliacao: add user_id + unique constraint (prestador_id, user_id)

Revision ID: 20260227_0008
Revises: 20260225_0007
Create Date: 2026-02-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260227_0008"
down_revision = "20260225_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "avaliacao",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_avaliacao_user_id",
        "avaliacao",
        "user",
        ["user_id"],
        ["id"],
    )
    op.create_index(
        "ix_avaliacao_user_id",
        "avaliacao",
        ["user_id"],
    )
    # Partial unique: only enforced where user_id IS NOT NULL (preserves legacy rows)
    op.execute(
        "CREATE UNIQUE INDEX uq_avaliacao_prestador_user "
        "ON avaliacao (prestador_id, user_id) "
        "WHERE user_id IS NOT NULL"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_avaliacao_prestador_user")
    op.drop_index("ix_avaliacao_user_id", table_name="avaliacao")
    op.drop_constraint("fk_avaliacao_user_id", "avaliacao", type_="foreignkey")
    op.drop_column("avaliacao", "user_id")
