"""Adiciona status para preservar edições canceladas no histórico."""
from alembic import op
import sqlalchemy as sa

revision = "20260922_0017"
down_revision = "20260922_0016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "eventos",
        sa.Column("status", sa.String(length=20), nullable=False, server_default="agendada"),
    )
    op.create_check_constraint(
        "ck_eventos_status", "eventos", "status IN ('agendada', 'cancelada')"
    )


def downgrade() -> None:
    op.drop_constraint("ck_eventos_status", "eventos", type_="check")
    op.drop_column("eventos", "status")
