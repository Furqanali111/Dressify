"""add size_label and fit_notes to clothing_items

Revision ID: f7a8b9c0d1e2
Revises: e6f7a8b9c0d1
Create Date: 2026-04-29

"""
from alembic import op
import sqlalchemy as sa

revision = "f7a8b9c0d1e2"
down_revision = "e6f7a8b9c0d1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("clothing_items", sa.Column("size_label", sa.String(10), nullable=True))
    op.add_column("clothing_items", sa.Column("fit_notes", sa.Text, nullable=True))


def downgrade() -> None:
    op.drop_column("clothing_items", "fit_notes")
    op.drop_column("clothing_items", "size_label")
