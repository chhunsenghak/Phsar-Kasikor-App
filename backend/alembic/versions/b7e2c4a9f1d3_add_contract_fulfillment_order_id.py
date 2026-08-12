"""add contract fulfillment_order_id

Revision ID: b7e2c4a9f1d3
Revises: a3d8e5f0c2b4
Create Date: 2026-08-11 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b7e2c4a9f1d3'
down_revision: Union[str, Sequence[str], None] = 'a3d8e5f0c2b4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('contracts', sa.Column('fulfillment_order_id', sa.String(36), nullable=True))
    op.create_index(op.f('ix_contracts_fulfillment_order_id'), 'contracts', ['fulfillment_order_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_contracts_fulfillment_order_id'), table_name='contracts')
    op.drop_column('contracts', 'fulfillment_order_id')
