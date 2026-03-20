"""Migrate existing dono_da_obra users to completo plan (3-tier model)

Revision ID: 20260312_0020
Revises: 20260312_0019
Create Date: 2026-03-12 20:00:00.000000
"""
from alembic import op

revision = "20260312_0020"
down_revision = "20260312_0019"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Migrate existing paid users from dono_da_obra to completo
    # They keep all their features — completo is the superset plan
    op.execute("UPDATE \"user\" SET plan = 'completo' WHERE plan = 'dono_da_obra'")
    op.execute("UPDATE subscription SET plan = 'completo' WHERE plan = 'dono_da_obra'")


def downgrade() -> None:
    # Revert back to dono_da_obra
    op.execute("UPDATE \"user\" SET plan = 'dono_da_obra' WHERE plan = 'completo'")
    op.execute("UPDATE subscription SET plan = 'dono_da_obra' WHERE plan = 'completo'")
    # Note: essencial users would need manual handling on downgrade
    op.execute("UPDATE \"user\" SET plan = 'dono_da_obra' WHERE plan = 'essencial'")
    op.execute("UPDATE subscription SET plan = 'dono_da_obra' WHERE plan = 'essencial'")
