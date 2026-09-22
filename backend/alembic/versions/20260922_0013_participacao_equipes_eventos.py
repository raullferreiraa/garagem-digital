"""Permite participação de equipes em encontros.

Revision ID: 20260922_0013
Revises: 20260922_0012
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260922_0013"
down_revision: str | None = "20260922_0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column("eventos", "localizacao", existing_type=sa.Text(), nullable=True)
    op.create_table(
        "participacoes_equipe_evento",
        sa.Column("evento_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("equipe_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("registrada_por", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", sa.String(length=20), server_default="confirmada", nullable=False),
        sa.Column("registrada_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["evento_id"], ["eventos.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["equipe_id"], ["equipes.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["registrada_por"], ["usuarios.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("evento_id", "equipe_id"),
        sa.CheckConstraint("status IN ('interessada', 'confirmada')", name="participacoes_equipe_evento_status_valido"),
    )


def downgrade() -> None:
    op.drop_table("participacoes_equipe_evento")
    op.alter_column("eventos", "localizacao", existing_type=sa.Text(), nullable=False)
