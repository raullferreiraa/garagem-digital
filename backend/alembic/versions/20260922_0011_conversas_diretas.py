"""Adiciona conversas e mensagens diretas.

Revision ID: 20260922_0011
Revises: 20260919_0010
Create Date: 2026-09-22
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql


revision: str = "20260922_0011"
down_revision: str | None = "20260919_0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "conversas_diretas",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usuario_a_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usuario_b_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usuario_a_leu_em", sa.DateTime(timezone=True), nullable=True),
        sa.Column("usuario_b_leu_em", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "criada_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "atualizada_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "usuario_a_id <> usuario_b_id",
            name="ck_conversas_diretas_usuarios_distintos",
        ),
        sa.CheckConstraint(
            "usuario_a_id < usuario_b_id",
            name="ck_conversas_diretas_ordem_usuarios",
        ),
        sa.ForeignKeyConstraint(
            ["usuario_a_id"], ["usuarios.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["usuario_b_id"], ["usuarios.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "usuario_a_id",
            "usuario_b_id",
            name="uq_conversas_diretas_usuarios",
        ),
    )
    op.create_index(
        "ix_conversas_diretas_usuario_a_id",
        "conversas_diretas",
        ["usuario_a_id"],
    )
    op.create_index(
        "ix_conversas_diretas_usuario_b_id",
        "conversas_diretas",
        ["usuario_b_id"],
    )
    op.create_table(
        "mensagens_diretas",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("conversa_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("remetente_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("conteudo", sa.String(length=2000), nullable=False),
        sa.Column(
            "criada_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["conversa_id"], ["conversas_diretas.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["remetente_id"], ["usuarios.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_mensagens_diretas_conversa_id",
        "mensagens_diretas",
        ["conversa_id"],
    )
    op.create_index(
        "ix_mensagens_diretas_remetente_id",
        "mensagens_diretas",
        ["remetente_id"],
    )
    op.create_index(
        "ix_mensagens_diretas_conversa_criada_id",
        "mensagens_diretas",
        ["conversa_id", "criada_em", "id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_mensagens_diretas_conversa_criada_id",
        table_name="mensagens_diretas",
    )
    op.drop_index(
        "ix_mensagens_diretas_remetente_id",
        table_name="mensagens_diretas",
    )
    op.drop_index(
        "ix_mensagens_diretas_conversa_id",
        table_name="mensagens_diretas",
    )
    op.drop_table("mensagens_diretas")
    op.drop_index(
        "ix_conversas_diretas_usuario_b_id",
        table_name="conversas_diretas",
    )
    op.drop_index(
        "ix_conversas_diretas_usuario_a_id",
        table_name="conversas_diretas",
    )
    op.drop_table("conversas_diretas")
