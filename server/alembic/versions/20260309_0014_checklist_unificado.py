"""Checklist unificado: adiciona campos de 3 camadas ao ChecklistItem."""
from alembic import op
import sqlalchemy as sa

revision = "20260309_0014"
down_revision = "20260311_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ChecklistItem - 3 Camadas
    op.add_column("checklistitem", sa.Column("severidade", sa.String(), nullable=True))
    op.add_column("checklistitem", sa.Column("traducao_leigo", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("dado_projeto", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("verificacoes", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("pergunta_engenheiro", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("documentos_a_exigir", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("registro_proprietario", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("resultado_cruzamento", sa.Text(), nullable=True))
    op.add_column("checklistitem", sa.Column("status_verificacao", sa.String(), server_default="pendente", nullable=False))
    op.add_column("checklistitem", sa.Column("confianca", sa.Integer(), nullable=True))
    op.add_column("checklistitem", sa.Column("requer_validacao_profissional", sa.Boolean(), server_default="false", nullable=False))

    # ChecklistGeracaoItem - 3 Camadas
    op.add_column("checklistgeracaoitem", sa.Column("dado_projeto", sa.Text(), nullable=True))
    op.add_column("checklistgeracaoitem", sa.Column("verificacoes", sa.Text(), nullable=True))
    op.add_column("checklistgeracaoitem", sa.Column("pergunta_engenheiro", sa.Text(), nullable=True))
    op.add_column("checklistgeracaoitem", sa.Column("documentos_a_exigir", sa.Text(), nullable=True))


def downgrade() -> None:
    # ChecklistGeracaoItem
    op.drop_column("checklistgeracaoitem", "documentos_a_exigir")
    op.drop_column("checklistgeracaoitem", "pergunta_engenheiro")
    op.drop_column("checklistgeracaoitem", "verificacoes")
    op.drop_column("checklistgeracaoitem", "dado_projeto")

    # ChecklistItem
    op.drop_column("checklistitem", "requer_validacao_profissional")
    op.drop_column("checklistitem", "confianca")
    op.drop_column("checklistitem", "status_verificacao")
    op.drop_column("checklistitem", "resultado_cruzamento")
    op.drop_column("checklistitem", "registro_proprietario")
    op.drop_column("checklistitem", "documentos_a_exigir")
    op.drop_column("checklistitem", "pergunta_engenheiro")
    op.drop_column("checklistitem", "verificacoes")
    op.drop_column("checklistitem", "dado_projeto")
    op.drop_column("checklistitem", "traducao_leigo")
    op.drop_column("checklistitem", "severidade")
