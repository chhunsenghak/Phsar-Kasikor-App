"""add khqr_qr_string to orders

Revision ID: d5e9f3a7b2c1
Revises: c4d8e2f6a1b7
Create Date: 2026-08-10 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd5e9f3a7b2c1'
down_revision: Union[str, Sequence[str], None] = 'c4d8e2f6a1b7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('orders', sa.Column('khqr_qr_string', sa.String(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('orders', 'khqr_qr_string')
