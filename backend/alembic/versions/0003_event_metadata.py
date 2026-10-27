"""Add event metadata required by the v1 API."""

from alembic import op
import sqlalchemy as sa

revision = "0003_event_metadata"
down_revision = "0002_backend_features"


def upgrade() -> None:
    op.add_column("events", sa.Column("opponent", sa.String(120)))
    op.add_column("events", sa.Column("notes", sa.String(5000)))


def downgrade() -> None:
    op.drop_column("events", "notes")
    op.drop_column("events", "opponent")
