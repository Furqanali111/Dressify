"""add performance indexes

Revision ID: f0e1d2c3b4a5
Revises: e5f6a7b8c9d0
Create Date: 2026-05-03 00:00:00.000000
"""
from alembic import op

revision = 'f0e1d2c3b4a5'
down_revision = 'e5f6a7b8c9d0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index('ix_clothing_items_user_id',   'clothing_items',       ['user_id'],   if_not_exists=True)
    op.create_index('ix_clothing_items_created_at', 'clothing_items',      ['created_at'], if_not_exists=True)
    op.create_index('ix_outfits_user_id',           'outfits',             ['user_id'],   if_not_exists=True)
    op.create_index('ix_wear_logs_user_id',         'wear_logs',           ['user_id'],   if_not_exists=True)
    op.create_index('ix_wear_logs_logged_at',       'wear_logs',           ['logged_at'], if_not_exists=True)
    op.create_index('ix_notifications_user_id',     'notifications',       ['user_id'],   if_not_exists=True)
    op.create_index('ix_notifications_created_at',  'notifications',       ['created_at'], if_not_exists=True)
    op.create_index('ix_upload_retry_queue_next_retry_at', 'upload_retry_queue', ['next_retry_at'], if_not_exists=True)


def downgrade() -> None:
    op.drop_index('ix_upload_retry_queue_next_retry_at', table_name='upload_retry_queue')
    op.drop_index('ix_notifications_created_at',  table_name='notifications')
    op.drop_index('ix_notifications_user_id',     table_name='notifications')
    op.drop_index('ix_wear_logs_logged_at',       table_name='wear_logs')
    op.drop_index('ix_wear_logs_user_id',         table_name='wear_logs')
    op.drop_index('ix_outfits_user_id',           table_name='outfits')
    op.drop_index('ix_clothing_items_created_at', table_name='clothing_items')
    op.drop_index('ix_clothing_items_user_id',    table_name='clothing_items')
