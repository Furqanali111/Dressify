"""remove soft delete from clothing items

Revision ID: b8c7d6e5f4a3
Revises: a9b8c7d6e5f4
Create Date: 2026-05-04

"""
from alembic import op
import sqlalchemy as sa

revision = 'b8c7d6e5f4a3'
down_revision = 'a9b8c7d6e5f4'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_index('ix_clothing_items_deleted_at', table_name='clothing_items', if_exists=True)
    op.drop_column('clothing_items', 'deleted_at')


def downgrade() -> None:
    op.add_column('clothing_items', sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True))
    op.create_index('ix_clothing_items_deleted_at', 'clothing_items', ['deleted_at'])
