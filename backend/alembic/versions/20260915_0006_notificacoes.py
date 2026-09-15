"""Adiciona central de notificacoes.

Revision ID: 20260915_0006
Revises: 20260915_0005
Create Date: 2026-09-15
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260915_0006"
down_revision: str | None = "20260915_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "notificacoes",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("destinatario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("ator_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("tipo", sa.String(length=50), nullable=False),
        sa.Column("mensagem", sa.String(length=240), nullable=False),
        sa.Column("carro_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("evolucao_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("equipe_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("lida_em", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "criada_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["ator_id"],
            ["usuarios.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["destinatario_id"],
            ["usuarios.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_notificacoes_destinatario_id",
        "notificacoes",
        ["destinatario_id"],
    )
    op.create_index("ix_notificacoes_tipo", "notificacoes", ["tipo"])


def downgrade() -> None:
    op.drop_index("ix_notificacoes_tipo", table_name="notificacoes")
    op.drop_index(
        "ix_notificacoes_destinatario_id",
        table_name="notificacoes",
    )
    op.drop_table("notificacoes")
