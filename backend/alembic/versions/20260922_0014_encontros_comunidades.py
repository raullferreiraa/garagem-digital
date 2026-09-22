"""Transforma encontros em comunidades com edições.

Revision ID: 20260922_0014
Revises: 20260922_0013
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260922_0014"
down_revision: str | None = "20260922_0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "encontros",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("organizador_usuario_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("organizador_equipe_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("nome", sa.String(length=140), nullable=False),
        sa.Column("descricao", sa.Text(), nullable=True),
        sa.Column("cidade", sa.String(length=120), nullable=True),
        sa.Column("estado", sa.String(length=120), nullable=True),
        sa.Column("visibilidade", sa.String(length=20), server_default="publico", nullable=False),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["organizador_usuario_id"], ["usuarios.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["organizador_equipe_id"], ["equipes.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint(
            "organizador_usuario_id IS NOT NULL OR organizador_equipe_id IS NOT NULL",
            name="encontros_organizador_obrigatorio",
        ),
        sa.CheckConstraint(
            "visibilidade IN ('publico', 'somente_equipe')",
            name="encontros_visibilidade_valida",
        ),
    )
    op.create_table(
        "seguidores_encontro",
        sa.Column("encontro_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("seguido_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["encontro_id"], ["encontros.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuarios.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("encontro_id", "usuario_id"),
    )
    op.add_column("eventos", sa.Column("encontro_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.execute(
        """
        INSERT INTO encontros (
            id, organizador_usuario_id, organizador_equipe_id, nome, descricao,
            cidade, estado, visibilidade, criado_em
        )
        SELECT id, organizador_usuario_id, organizador_equipe_id, nome, descricao,
               cidade, estado, visibilidade, criado_em
        FROM eventos
        """
    )
    op.execute("UPDATE eventos SET encontro_id = id")
    op.alter_column("eventos", "encontro_id", nullable=False)
    op.create_foreign_key(
        "eventos_encontro_id_fkey", "eventos", "encontros", ["encontro_id"], ["id"], ondelete="CASCADE"
    )
    op.create_index("eventos_encontro_id_idx", "eventos", ["encontro_id"])


def downgrade() -> None:
    op.drop_index("eventos_encontro_id_idx", table_name="eventos")
    op.drop_constraint("eventos_encontro_id_fkey", "eventos", type_="foreignkey")
    op.drop_column("eventos", "encontro_id")
    op.drop_table("seguidores_encontro")
    op.drop_table("encontros")
