"""Registra quando um comentário de evolução foi editado."""

from alembic import op
import sqlalchemy as sa

revision = "20260929_0025"
down_revision = "20260926_0024"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "comentarios_evolucao",
        sa.Column("editado_em", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("comentarios_evolucao", "editado_em")
