"""Adiciona fotos ao diario de evolucoes.

Revision ID: 20260905_0003
Revises: 20260905_0002
Create Date: 2026-09-05
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260905_0003"
down_revision: str | None = "20260905_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "midias_evolucao",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column(
            "evolucao_id",
            postgresql.UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column("url", sa.Text(), nullable=False),
        sa.Column(
            "tipo",
            sa.String(length=10),
            server_default="imagem",
            nullable=False,
        ),
        sa.Column(
            "ordem",
            sa.SmallInteger(),
            server_default="0",
            nullable=False,
        ),
        sa.Column(
            "criado_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["evolucao_id"],
            ["evolucoes_projeto.id"],
            ondelete="CASCADE",
        ),
        sa.CheckConstraint(
            "tipo IN ('imagem', 'video')",
            name="midias_evolucao_tipo_valido",
        ),
        sa.CheckConstraint(
            "ordem >= 0",
            name="midias_evolucao_ordem_valida",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "evolucao_id",
            "ordem",
            name="midias_evolucao_ordem_unica",
        ),
    )
    op.create_index(
        "ix_midias_evolucao_evolucao_id",
        "midias_evolucao",
        ["evolucao_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_midias_evolucao_evolucao_id",
        table_name="midias_evolucao",
    )
    op.drop_table("midias_evolucao")
