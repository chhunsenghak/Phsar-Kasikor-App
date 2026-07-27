"""rename_contract_party_columns

Revision ID: 9db867ed1777
Revises: 57ef6dab145b
Create Date: 2026-07-27 03:38:02.004754

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9db867ed1777'
down_revision: Union[str, Sequence[str], None] = '57ef6dab145b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Drop old constraints
    op.drop_constraint('contracts_party_a_id_fkey', 'contracts', type_='foreignkey')
    op.drop_constraint('contracts_party_b_id_fkey', 'contracts', type_='foreignkey')
    
    # Rename columns
    op.alter_column('contracts', 'party_a_id', new_column_name='seller_id')
    op.alter_column('contracts', 'party_b_id', new_column_name='buyer_id')
    
    # Create new constraints
    op.create_foreign_key('contracts_seller_id_fkey', 'contracts', 'users', ['seller_id'], ['id'])
    op.create_foreign_key('contracts_buyer_id_fkey', 'contracts', 'users', ['buyer_id'], ['id'])


def downgrade() -> None:
    """Downgrade schema."""
    # Drop new constraints
    op.drop_constraint('contracts_seller_id_fkey', 'contracts', type_='foreignkey')
    op.drop_constraint('contracts_buyer_id_fkey', 'contracts', type_='foreignkey')
    
    # Rename columns back
    op.alter_column('contracts', 'seller_id', new_column_name='party_a_id')
    op.alter_column('contracts', 'buyer_id', new_column_name='party_b_id')
    
    # Recreate old constraints
    op.create_foreign_key('contracts_party_a_id_fkey', 'contracts', 'users', ['party_a_id'], ['id'])
    op.create_foreign_key('contracts_party_b_id_fkey', 'contracts', 'users', ['party_b_id'], ['id'])
