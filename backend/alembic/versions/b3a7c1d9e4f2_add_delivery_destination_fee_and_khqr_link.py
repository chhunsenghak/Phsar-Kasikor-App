"""add delivery destination, delivery fee, and khqr link to orders

Revision ID: b3a7c1d9e4f2
Revises: fe74db34cd92
Create Date: 2026-08-07 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b3a7c1d9e4f2'
down_revision: Union[str, Sequence[str], None] = 'fe74db34cd92'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        'orders',
        sa.Column('delivery_fee', sa.Numeric(10, 2), nullable=False, server_default='0'),
    )
    op.alter_column('orders', 'delivery_fee', server_default=None)
    op.add_column('orders', sa.Column('delivery_address_text', sa.String(), nullable=True))
    op.add_column('orders', sa.Column('delivery_lat', sa.Numeric(10, 8), nullable=True))
    op.add_column('orders', sa.Column('delivery_lng', sa.Numeric(11, 8), nullable=True))
    op.add_column('orders', sa.Column('khqr_md5', sa.String(), nullable=True))
    op.create_index(op.f('ix_orders_khqr_md5'), 'orders', ['khqr_md5'], unique=False)

    op.execute("UPDATE deliveries SET delivery_status = 'pending' WHERE delivery_status = 'dispatched'")


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("UPDATE deliveries SET delivery_status = 'dispatched' WHERE delivery_status = 'pending'")

    op.drop_index(op.f('ix_orders_khqr_md5'), table_name='orders')
    op.drop_column('orders', 'khqr_md5')
    op.drop_column('orders', 'delivery_lng')
    op.drop_column('orders', 'delivery_lat')
    op.drop_column('orders', 'delivery_address_text')
    op.drop_column('orders', 'delivery_fee')
