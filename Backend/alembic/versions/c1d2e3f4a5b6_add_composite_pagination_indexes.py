"""add composite pagination indexes

Replaces the single-column (user_id) and (created_at) indexes on
clothing_items and outfits with composite (user_id, created_at DESC) indexes.

PostgreSQL can only use one index per table per query; a composite index
covers the WHERE user_id = $1 AND created_at < $2 ORDER BY created_at DESC
pattern used by both pagination endpoints in a single index scan — no heap
fetches needed for the sort key.

Revision ID: c1d2e3f4a5b6
Revises: b8c7d6e5f4a3
Create Date: 2026-05-09
"""
from alembic import op

revision = 'c1d2e3f4a5b6'
down_revision = 'b8c7d6e5f4a3'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # clothing_items — pagination: WHERE user_id = ? AND created_at </> ?
    #                             ORDER BY created_at DESC/ASC
    op.create_index(
        'ix_clothing_items_user_created',
        'clothing_items',
        ['user_id', 'created_at'],
        postgresql_ops={'created_at': 'DESC'},
        if_not_exists=True,
    )

    # outfits — same pagination pattern
    op.create_index(
        'ix_outfits_user_created',
        'outfits',
        ['user_id', 'created_at'],
        postgresql_ops={'created_at': 'DESC'},
        if_not_exists=True,
    )

    # wear_logs — queried by user_id + logged_at range
    op.create_index(
        'ix_wear_logs_user_logged',
        'wear_logs',
        ['user_id', 'logged_at'],
        postgresql_ops={'logged_at': 'DESC'},
        if_not_exists=True,
    )

    # notifications — queried by user_id + created_at order
    op.create_index(
        'ix_notifications_user_created',
        'notifications',
        ['user_id', 'created_at'],
        postgresql_ops={'created_at': 'DESC'},
        if_not_exists=True,
    )


def downgrade() -> None:
    op.drop_index('ix_notifications_user_created', table_name='notifications')
    op.drop_index('ix_wear_logs_user_logged', table_name='wear_logs')
    op.drop_index('ix_outfits_user_created', table_name='outfits')
    op.drop_index('ix_clothing_items_user_created', table_name='clothing_items')
