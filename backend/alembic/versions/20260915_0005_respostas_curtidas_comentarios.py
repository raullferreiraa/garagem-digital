"""Adiciona respostas e curtidas aos comentarios de evolucao.

Revision ID: 20260915_0005
Revises: 20260914_0004
Create Date: 2026-09-15
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260915_0005"
down_revision: str | None = "20260914_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "comentarios_evolucao",
        sa.Column(
            "comentario_pai_id",
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.create_foreign_key(
        "fk_comentarios_evolucao_comentario_pai_id",
        "comentarios_evolucao",
        "comentarios_evolucao",
        ["comentario_pai_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_comentarios_evolucao_comentario_pai_id",
        "comentarios_evolucao",
        ["comentario_pai_id"],
    )
    op.create_table(
        "curtidas_comentario_evolucao",
        sa.Column("comentario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "criado_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["comentario_id"],
            ["comentarios_evolucao.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["usuario_id"],
            ["usuarios.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("comentario_id", "usuario_id"),
    )


def downgrade() -> None:
    op.drop_table("curtidas_comentario_evolucao")
    op.drop_index(
        "ix_comentarios_evolucao_comentario_pai_id",
        table_name="comentarios_evolucao",
    )
    op.drop_constraint(
        "fk_comentarios_evolucao_comentario_pai_id",
        "comentarios_evolucao",
        type_="foreignkey",
    )
    op.drop_column("comentarios_evolucao", "comentario_pai_id")
