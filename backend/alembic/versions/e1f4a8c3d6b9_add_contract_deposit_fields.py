"""add contract deposit fields and one-open-contract-per-pair index

Revision ID: e1f4a8c3d6b9
Revises: d5e9f3a7b2c1
Create Date: 2026-08-10 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e1f4a8c3d6b9'
down_revision: Union[str, Sequence[str], None] = 'd5e9f3a7b2c1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('contracts', sa.Column('deposit_percentage', sa.Numeric(5, 2), nullable=True))
    op.add_column('contracts', sa.Column('deposit_amount', sa.Numeric(10, 2), nullable=True))
    op.add_column('contracts', sa.Column('deposit_status', sa.String(), nullable=True))
    op.add_column('contracts', sa.Column('deposit_currency', sa.String(), nullable=True))
    op.add_column('contracts', sa.Column('deposit_khqr_md5', sa.String(), nullable=True))
    op.add_column('contracts', sa.Column('deposit_khqr_qr_string', sa.String(), nullable=True))
    op.create_index(op.f('ix_contracts_deposit_khqr_md5'), 'contracts', ['deposit_khqr_md5'], unique=False)

    # Only one open (not yet resolved) contract allowed per buyer/seller pair
    # at a time — the real safety net against a create-then-check race,
    # client-side "disable after tap" alone isn't enough.
    op.create_index(
        'ix_contracts_open_pair_unique',
        'contracts',
        ['buyer_id', 'seller_id'],
        unique=True,
        postgresql_where=sa.text("contract_status IN ('DRAFT', 'PENDING_DEPOSIT', 'ACTIVE')"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_contracts_open_pair_unique', table_name='contracts')
    op.drop_index(op.f('ix_contracts_deposit_khqr_md5'), table_name='contracts')
    op.drop_column('contracts', 'deposit_khqr_qr_string')
    op.drop_column('contracts', 'deposit_khqr_md5')
    op.drop_column('contracts', 'deposit_currency')
    op.drop_column('contracts', 'deposit_status')
    op.drop_column('contracts', 'deposit_amount')
    op.drop_column('contracts', 'deposit_percentage')
