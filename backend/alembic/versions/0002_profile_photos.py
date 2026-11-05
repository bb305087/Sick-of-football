"""Store profile photos per user."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0002_profile_photos"
down_revision = "0004_refresh_token_metadata"


def upgrade():
    op.create_table(
        "profile_photos",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("content", sa.LargeBinary(), nullable=False),
        sa.Column("content_type", sa.String(50), nullable=False),
    )
    op.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON profile_photos TO sof_app")


def downgrade():
    op.drop_table("profile_photos")
