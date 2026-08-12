"""add contract final payment and delivery fields

Revision ID: a3d8e5f0c2b4
Revises: f2a6c9d1e4b7
Create Date: 2026-08-11 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a3d8e5f0c2b4'
down_revision: Union[str, Sequence[str], None] = 'f2a6c9d1e4b7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('contracts', sa.Column('delivery_method', sa.String(), nullable=True))
    op.add_column('contracts', sa.Column('delivery_fee', sa.Numeric(10, 2), nullable=True))
    op.add_column('contracts', sa.Column('final_amount', sa.Numeric(10, 2), nullable=True))
    op.add_column('contracts', sa.Column('final_payment_status', sa.String(), nullable=True))
    op.add_column('contracts', sa.Column('final_khqr_md5', sa.String(), nullable=True))
    op.add_column('contracts', sa.Column('final_khqr_qr_string', sa.String(), nullable=True))
    op.create_index(op.f('ix_contracts_final_khqr_md5'), 'contracts', ['final_khqr_md5'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_contracts_final_khqr_md5'), table_name='contracts')
    op.drop_column('contracts', 'final_khqr_qr_string')
    op.drop_column('contracts', 'final_khqr_md5')
    op.drop_column('contracts', 'final_payment_status')
    op.drop_column('contracts', 'final_amount')
    op.drop_column('contracts', 'delivery_fee')
    op.drop_column('contracts', 'delivery_method')
