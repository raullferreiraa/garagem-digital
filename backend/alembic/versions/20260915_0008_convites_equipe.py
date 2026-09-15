"""Adiciona convites para equipes.

Revision ID: 20260915_0008
Revises: 20260915_0007
Create Date: 2026-09-15
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260915_0008"
down_revision: str | None = "20260915_0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "convites_equipe",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("equipe_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("convidado_por", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("criada_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("respondida_em", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["convidado_por"], ["usuarios.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["equipe_id"], ["equipes.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuarios.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("equipe_id", "usuario_id", name="uq_convites_equipe_usuario"),
    )
    op.create_index("ix_convites_equipe_equipe_id", "convites_equipe", ["equipe_id"])
    op.create_index("ix_convites_equipe_usuario_id", "convites_equipe", ["usuario_id"])


def downgrade() -> None:
    op.drop_index("ix_convites_equipe_usuario_id", table_name="convites_equipe")
    op.drop_index("ix_convites_equipe_equipe_id", table_name="convites_equipe")
    op.drop_table("convites_equipe")
