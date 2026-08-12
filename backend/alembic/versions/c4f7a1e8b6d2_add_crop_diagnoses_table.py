"""add crop_diagnoses table

Revision ID: c4f7a1e8b6d2
Revises: b7e2c4a9f1d3
Create Date: 2026-08-12 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c4f7a1e8b6d2'
down_revision: Union[str, Sequence[str], None] = 'b7e2c4a9f1d3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'crop_diagnoses',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('disease_name', sa.String(), nullable=False),
        sa.Column('disease_name_kh', sa.String(), nullable=True),
        sa.Column('crop_type', sa.String(), nullable=False),
        sa.Column('keywords', sa.String(), nullable=False),
        sa.Column('symptoms_description', sa.Text(), nullable=False),
        sa.Column('symptoms_description_kh', sa.Text(), nullable=True),
        sa.Column('treatment_advice', sa.Text(), nullable=False),
        sa.Column('treatment_advice_kh', sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('crop_diagnoses')
