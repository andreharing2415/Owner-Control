"""fix missing updated_at in checklistitem and evidencia

Revision ID: 20260225_0007
Revises: 20260224_0006
Create Date: 2026-02-25
"""

import sqlalchemy as sa
from alembic import op

revision = "20260225_0007"
down_revision = "20260224_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("checklistitem", sa.Column("updated_at", sa.DateTime(), nullable=True))
    op.execute("UPDATE checklistitem SET updated_at = created_at WHERE updated_at IS NULL")
    op.alter_column("checklistitem", "updated_at", nullable=False)

    op.add_column("evidencia", sa.Column("updated_at", sa.DateTime(), nullable=True))
    op.execute("UPDATE evidencia SET updated_at = created_at WHERE updated_at IS NULL")
    op.alter_column("evidencia", "updated_at", nullable=False)


def downgrade() -> None:
    op.drop_column("evidencia", "updated_at")
    op.drop_column("checklistitem", "updated_at")
