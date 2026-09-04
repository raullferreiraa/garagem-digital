"""Cria o esquema inicial PostgreSQL/PostGIS.

Revision ID: 20260904_0001
Revises:
Create Date: 2026-09-04
"""

from collections.abc import Sequence
from pathlib import Path

from alembic import op


revision: str = "20260904_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _schema_path() -> Path:
    return Path(__file__).resolve().parents[3] / "database" / "schema.sql"


def _schema_statements() -> list[str]:
    schema = _schema_path().read_text(encoding="utf-8")
    return [statement.strip() for statement in schema.split(";") if statement.strip()]


def upgrade() -> None:
    for statement in _schema_statements():
        op.execute(statement)


def downgrade() -> None:
    tables = (
        "presencas_evento",
        "eventos",
        "carros_equipe",
        "solicitacoes_equipe",
        "membros_equipe",
        "equipes",
        "midias_evolucao",
        "evolucoes_projeto",
        "carros",
        "sessoes_refresh",
        "usuarios",
    )
    for table in tables:
        op.execute(f'DROP TABLE IF EXISTS "{table}" CASCADE')
