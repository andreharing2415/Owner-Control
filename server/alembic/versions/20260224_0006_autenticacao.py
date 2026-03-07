"""fase 7 - autenticacao: tabela user + obra.user_id

Revision ID: 20260224_0006
Revises: 20260224_0005
Create Date: 2026-02-24 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "20260224_0006"
down_revision = "20260224_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Tabela de usuarios
    op.create_table(
        "user",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("password_hash", sa.String(), nullable=False),
        sa.Column("nome", sa.String(), nullable=False),
        sa.Column("telefone", sa.String(), nullable=True),
        sa.Column("role", sa.String(), nullable=False, server_default="owner"),
        sa.Column("ativo", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_user_id", "user", ["id"])
    op.create_index("ix_user_email", "user", ["email"], unique=True)

    # FK user_id na tabela obra (nullable para dados existentes)
    op.add_column("obra", sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.create_index("ix_obra_user_id", "obra", ["user_id"])
    op.create_foreign_key("fk_obra_user_id", "obra", "user", ["user_id"], ["id"])


def downgrade() -> None:
    op.drop_constraint("fk_obra_user_id", "obra", type_="foreignkey")
    op.drop_index("ix_obra_user_id", table_name="obra")
    op.drop_column("obra", "user_id")
    op.drop_index("ix_user_email", table_name="user")
    op.drop_index("ix_user_id", table_name="user")
    op.drop_table("user")
