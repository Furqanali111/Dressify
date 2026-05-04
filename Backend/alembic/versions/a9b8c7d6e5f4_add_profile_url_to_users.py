"""add profile_url to users

Revision ID: a9b8c7d6e5f4
Revises: f0e1d2c3b4a5
Create Date: 2026-05-04

"""
from alembic import op
import sqlalchemy as sa

revision = 'a9b8c7d6e5f4'
down_revision = 'a5b4c3d2e1f0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('users', sa.Column('profile_url', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'profile_url')
