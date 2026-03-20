"""risco 3 camadas: dado_projeto, verificacoes, pergunta_engenheiro, registro, cruzamento

Revision ID: 20260311_0013
Revises: 20260310_0012
Create Date: 2026-03-11 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260311_0013"
down_revision = "20260310_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("risco", sa.Column("dado_projeto", sa.Text(), nullable=True))
    op.add_column("risco", sa.Column("verificacoes", sa.Text(), nullable=True))
    op.add_column("risco", sa.Column("pergunta_engenheiro", sa.Text(), nullable=True))
    op.add_column("risco", sa.Column("registro_proprietario", sa.Text(), nullable=True))
    op.add_column("risco", sa.Column("resultado_cruzamento", sa.Text(), nullable=True))
    op.add_column("risco", sa.Column("status_verificacao", sa.String(), nullable=False, server_default="pendente"))


def downgrade() -> None:
    op.drop_column("risco", "status_verificacao")
    op.drop_column("risco", "resultado_cruzamento")
    op.drop_column("risco", "registro_proprietario")
    op.drop_column("risco", "pergunta_engenheiro")
    op.drop_column("risco", "verificacoes")
    op.drop_column("risco", "dado_projeto")
