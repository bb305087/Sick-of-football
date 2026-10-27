from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
revision = "0002_backend_features"
down_revision = "0001_initial"

def upgrade():
    op.add_column("users", sa.Column("failed_login_attempts", sa.Integer(), server_default="0", nullable=False))
    op.add_column("users", sa.Column("locked_until", sa.DateTime(timezone=True)))
    op.add_column("users", sa.Column("last_login_at", sa.DateTime(timezone=True)))
    op.create_table("medical_reports",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("club_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("clubs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("player_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("diagnosis", sa.String(200), nullable=False), sa.Column("details", sa.Text()),
        sa.Column("occurred_on", sa.Date()), sa.Column("cleared_on", sa.Date()),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL")))
    op.create_index("ix_medical_reports_club_id", "medical_reports", ["club_id"])
    op.create_index("ix_medical_reports_player_id", "medical_reports", ["player_id"])

def downgrade():
    op.drop_table("medical_reports")
    op.drop_column("users", "last_login_at"); op.drop_column("users", "locked_until"); op.drop_column("users", "failed_login_attempts")
