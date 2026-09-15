"""Adiciona destino de comentario nas notificacoes.

Revision ID: 20260915_0007
Revises: 20260915_0006
Create Date: 2026-09-15
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260915_0007"
down_revision: str | None = "20260915_0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "notificacoes",
        sa.Column(
            "comentario_id",
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("notificacoes", "comentario_id")
