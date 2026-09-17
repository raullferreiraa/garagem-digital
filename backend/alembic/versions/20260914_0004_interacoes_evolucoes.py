"""Adiciona curtidas e comentarios nas evolucoes.

Revision ID: 20260914_0004
Revises: 20260914_0003
Create Date: 2026-09-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260914_0004"
down_revision: str | None = "20260914_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "curtidas_evolucao",
        sa.Column("evolucao_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "criado_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["evolucao_id"], ["evolucoes_projeto.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["usuario_id"], ["usuarios.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("evolucao_id", "usuario_id"),
    )
    op.create_table(
        "comentarios_evolucao",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("evolucao_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("autor_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("conteudo", sa.Text(), nullable=False),
        sa.Column(
            "criado_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "atualizado_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["autor_id"], ["usuarios.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["evolucao_id"], ["evolucoes_projeto.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_comentarios_evolucao_evolucao_id",
        "comentarios_evolucao",
        ["evolucao_id"],
    )
    op.create_index(
        "ix_comentarios_evolucao_autor_id",
        "comentarios_evolucao",
        ["autor_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_comentarios_evolucao_autor_id",
        table_name="comentarios_evolucao",
    )
    op.drop_index(
        "ix_comentarios_evolucao_evolucao_id",
        table_name="comentarios_evolucao",
    )
    op.drop_table("comentarios_evolucao")
    op.drop_table("curtidas_evolucao")
