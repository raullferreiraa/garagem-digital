"""Adiciona relacionamentos de seguidores.

Revision ID: 20260914_0003
Revises: 20260905_0002
Create Date: 2026-09-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260914_0003"
down_revision: str | None = "20260905_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "seguidores",
        sa.Column("seguidor_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("seguido_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "criado_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "seguidor_id <> seguido_id",
            name="seguidor_nao_pode_seguir_a_si",
        ),
        sa.ForeignKeyConstraint(
            ["seguido_id"], ["usuarios.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["seguidor_id"], ["usuarios.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("seguidor_id", "seguido_id"),
    )
    op.create_index(
        "ix_seguidores_seguido_id",
        "seguidores",
        ["seguido_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_seguidores_seguido_id", table_name="seguidores")
    op.drop_table("seguidores")
