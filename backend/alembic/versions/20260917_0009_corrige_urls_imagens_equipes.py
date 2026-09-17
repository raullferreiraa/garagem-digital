"""Corrige URLs das imagens de equipes enviadas com prefixo inválido.

Revision ID: 20260917_0009
Revises: 20260915_0008
Create Date: 2026-09-17
"""

from collections.abc import Sequence

from alembic import op


revision: str = "20260917_0009"
down_revision: str | None = "20260915_0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        "UPDATE equipes SET avatar_url = substring(avatar_url from 2) "
        "WHERE avatar_url LIKE '$/media/%'"
    )
    op.execute(
        "UPDATE equipes SET capa_url = substring(capa_url from 2) "
        "WHERE capa_url LIKE '$/media/%'"
    )


def downgrade() -> None:
    # Os endereços já corrigidos devem continuar válidos.
    pass
