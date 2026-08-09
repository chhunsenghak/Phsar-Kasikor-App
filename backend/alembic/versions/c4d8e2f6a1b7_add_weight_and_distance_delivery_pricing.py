"""add product weight and order delivery distance/weight for pricing

Revision ID: c4d8e2f6a1b7
Revises: b3a7c1d9e4f2
Create Date: 2026-08-08 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c4d8e2f6a1b7'
down_revision: Union[str, Sequence[str], None] = 'b3a7c1d9e4f2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('products', sa.Column('weight_kg_per_unit', sa.Numeric(10, 2), nullable=True))
    op.add_column('orders', sa.Column('delivery_distance_km', sa.Numeric(8, 2), nullable=True))
    op.add_column('orders', sa.Column('delivery_weight_kg', sa.Numeric(10, 2), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('orders', 'delivery_weight_kg')
    op.drop_column('orders', 'delivery_distance_km')
    op.drop_column('products', 'weight_kg_per_unit')
