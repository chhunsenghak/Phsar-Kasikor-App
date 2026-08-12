"""add delivery notes, contact phone, and actual cost to deliveries

Revision ID: d2f6b8a4c7e1
Revises: c4f7a1e8b6d2
Create Date: 2026-08-12 00:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd2f6b8a4c7e1'
down_revision: Union[str, Sequence[str], None] = 'c4f7a1e8b6d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('deliveries', sa.Column('contact_phone', sa.String(), nullable=True))
    op.add_column('deliveries', sa.Column('delivery_notes', sa.Text(), nullable=True))
    op.add_column('deliveries', sa.Column('actual_delivery_cost', sa.Numeric(10, 2), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('deliveries', 'actual_delivery_cost')
    op.drop_column('deliveries', 'delivery_notes')
    op.drop_column('deliveries', 'contact_phone')
