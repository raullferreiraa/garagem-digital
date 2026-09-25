"""Adiciona destino de encontro às notificações."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20260924_0021"
down_revision = "20260923_0020"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "notificacoes",
        sa.Column("encontro_id", postgresql.UUID(as_uuid=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("notificacoes", "encontro_id")
