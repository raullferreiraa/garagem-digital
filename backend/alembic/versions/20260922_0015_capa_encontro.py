"""Capa da comunidade de encontros."""
from alembic import op
import sqlalchemy as sa

revision = "20260922_0015"
down_revision = "20260922_0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("encontros", sa.Column("capa_url", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("encontros", "capa_url")
