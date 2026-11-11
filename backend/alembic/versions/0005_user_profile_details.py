"""Add optional user profile details."""

from alembic import op
import sqlalchemy as sa

revision = "0005_user_profile_details"
down_revision = "0004_refresh_token_metadata"


def upgrade() -> None:
    op.add_column("users", sa.Column("nationality", sa.String(80), nullable=True))
    op.add_column("users", sa.Column("date_of_birth", sa.DateTime(), nullable=True))
    op.add_column("users", sa.Column("position", sa.String(40), nullable=True))
    op.add_column("users", sa.Column("preferred_foot", sa.String(10), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "preferred_foot")
    op.drop_column("users", "position")
    op.drop_column("users", "date_of_birth")
    op.drop_column("users", "nationality")
