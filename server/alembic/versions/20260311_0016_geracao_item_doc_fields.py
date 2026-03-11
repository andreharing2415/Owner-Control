"""checklistgeracaoitem: add projeto_doc_id and projeto_doc_nome

Revision ID: 20260311_0016
Revises: 20260311_0015
Create Date: 2026-03-11 18:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = "20260311_0016"
down_revision = "20260311_0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("checklistgeracaoitem", sa.Column("projeto_doc_id", sa.String(), nullable=True))
    op.add_column("checklistgeracaoitem", sa.Column("projeto_doc_nome", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("checklistgeracaoitem", "projeto_doc_nome")
    op.drop_column("checklistgeracaoitem", "projeto_doc_id")
