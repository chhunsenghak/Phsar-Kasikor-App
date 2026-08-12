"""drop one-open-contract-per-pair index — a buyer/seller pair may now have
any number of contracts open at once (e.g. separate contracts for different
crops or delivery windows)

Revision ID: f2a6c9d1e4b7
Revises: e1f4a8c3d6b9
Create Date: 2026-08-11 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f2a6c9d1e4b7'
down_revision: Union[str, Sequence[str], None] = 'e1f4a8c3d6b9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_index('ix_contracts_open_pair_unique', table_name='contracts')


def downgrade() -> None:
    """Downgrade schema."""
    op.create_index(
        'ix_contracts_open_pair_unique',
        'contracts',
        ['buyer_id', 'seller_id'],
        unique=True,
        postgresql_where=sa.text("contract_status IN ('DRAFT', 'PENDING_DEPOSIT', 'ACTIVE')"),
    )
