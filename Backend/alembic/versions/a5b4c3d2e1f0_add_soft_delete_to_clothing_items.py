"""add soft delete to clothing items

Revision ID: a5b4c3d2e1f0
Revises: f0e1d2c3b4a5
Create Date: 2026-05-03 00:01:00.000000
"""
import sqlalchemy as sa
from alembic import op

revision = 'a5b4c3d2e1f0'
down_revision = 'f0e1d2c3b4a5'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'clothing_items',
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_clothing_items_deleted_at', 'clothing_items', ['deleted_at'])


def downgrade() -> None:
    op.drop_index('ix_clothing_items_deleted_at', table_name='clothing_items')
    op.drop_column('clothing_items', 'deleted_at')
