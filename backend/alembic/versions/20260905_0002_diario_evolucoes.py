"""Adiciona quilometragem ao diario de evolucoes.

Revision ID: 20260905_0002
Revises: 20260904_0001
Create Date: 2026-09-05
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "20260905_0002"
down_revision: str | None = "20260904_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "evolucoes_projeto",
        sa.Column("quilometragem_km", sa.Integer(), nullable=True),
    )
    op.create_check_constraint(
        "evolucoes_quilometragem_valida",
        "evolucoes_projeto",
        "quilometragem_km IS NULL OR quilometragem_km >= 0",
    )


def downgrade() -> None:
    op.drop_constraint(
        "evolucoes_quilometragem_valida",
        "evolucoes_projeto",
        type_="check",
    )
    op.drop_column("evolucoes_projeto", "quilometragem_km")
