"""Padroniza os campos técnicos dos carros.

Revision ID: 20260919_0010
Revises: 20260917_0009
Create Date: 2026-09-19
"""

from collections.abc import Sequence

from alembic import op


revision: str = "20260919_0010"
down_revision: str | None = "20260917_0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("UPDATE carros SET modelo = UPPER(modelo)")
    op.execute("UPDATE carros SET cor = UPPER(cor) WHERE cor IS NOT NULL")
    op.execute("UPDATE carros SET motor = UPPER(motor) WHERE motor IS NOT NULL")
    op.execute(
        "UPDATE carros SET tipo_suspensao = UPPER(tipo_suspensao) "
        "WHERE tipo_suspensao IS NOT NULL"
    )


def downgrade() -> None:
    # Não é possível recuperar a capitalização original com segurança.
    pass
