"""AI-02: Add fonte_doc_trecho to ChecklistGeracaoItem for traceability.

Revision ID: 20260406_0025
Revises: 20260319_0024
Create Date: 2026-04-06
"""

import sqlalchemy as sa
from alembic import op

# revision identifiers
revision = "20260406_0025"
down_revision = "20260319_0024"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "checklistgeracaoitem",
        sa.Column("fonte_doc_trecho", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("checklistgeracaoitem", "fonte_doc_trecho")
