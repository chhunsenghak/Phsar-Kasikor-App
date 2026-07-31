"""create address change requests table and normalize user addresses

Revision ID: d0bf68eb892c
Revises: 71985fe089bb
Create Date: 2026-07-30 15:53:46.077555

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd0bf68eb892c'
down_revision: Union[str, Sequence[str], None] = '71985fe089bb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # 1. Create address_change_requests table
    op.create_table(
        'address_change_requests',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('status', sa.String(), nullable=False, server_default='PENDING'),
        sa.Column('province', sa.String(), nullable=True),
        sa.Column('district', sa.String(), nullable=True),
        sa.Column('commune', sa.String(), nullable=True),
        sa.Column('village', sa.String(), nullable=True),
        sa.Column('street_address', sa.String(), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=True),
        sa.Column('longitude', sa.Float(), nullable=True),
        sa.Column('proof_document_url', sa.String(), nullable=True),
        sa.Column('admin_feedback', sa.Text(), nullable=True),
        sa.Column('reviewed_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_address_change_requests_user_id', 'address_change_requests', ['user_id'], unique=False)

    # 2. Add address_id column to users table
    op.add_column('users', sa.Column('address_id', sa.String(length=36), nullable=True))
    op.create_foreign_key('fk_user_address', 'users', 'address_change_requests', ['address_id'], ['id'], use_alter=True)

    # 3. Drop obsolete location columns from users table
    op.drop_column('users', 'province')
    op.drop_column('users', 'district')
    op.drop_column('users', 'commune')
    op.drop_column('users', 'village')
    op.drop_column('users', 'street_address')
    op.drop_column('users', 'latitude')
    op.drop_column('users', 'longitude')
    op.drop_column('users', 'location_name')


def downgrade() -> None:
    """Downgrade schema."""
    # 1. Re-add location columns to users
    op.add_column('users', sa.Column('location_name', sa.String(), nullable=True))
    op.add_column('users', sa.Column('longitude', sa.Numeric(precision=11, scale=8), nullable=True))
    op.add_column('users', sa.Column('latitude', sa.Numeric(precision=10, scale=8), nullable=True))
    op.add_column('users', sa.Column('street_address', sa.String(), nullable=True))
    op.add_column('users', sa.Column('village', sa.String(), nullable=True))
    op.add_column('users', sa.Column('commune', sa.String(), nullable=True))
    op.add_column('users', sa.Column('district', sa.String(), nullable=True))
    op.add_column('users', sa.Column('province', sa.String(), nullable=True))

    # 2. Drop foreign key and column from users
    op.drop_constraint('fk_user_address', 'users', type_='foreignkey')
    op.drop_column('users', 'address_id')

    # 3. Drop address_change_requests table
    op.drop_index('ix_address_change_requests_user_id', table_name='address_change_requests')
    op.drop_table('address_change_requests')
