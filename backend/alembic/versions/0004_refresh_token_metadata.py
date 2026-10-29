"""Add refresh token request metadata."""

from alembic import op
import sqlalchemy as sa

revision = "0004_refresh_token_metadata"
down_revision = "0003_event_metadata"


def upgrade() -> None:
    op.add_column("refresh_tokens", sa.Column("user_agent", sa.String(200)))
    op.add_column("refresh_tokens", sa.Column("ip", sa.String(45)))


def downgrade() -> None:
    op.drop_column("refresh_tokens", "ip")
    op.drop_column("refresh_tokens", "user_agent")
