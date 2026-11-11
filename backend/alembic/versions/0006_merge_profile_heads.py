"""Merge the profile photo and user profile detail migration branches."""

from alembic import op

revision = "0006_merge_profile_heads"
down_revision = ("0002_profile_photos", "0005_user_profile_details")


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
