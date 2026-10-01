"""Permite guardar projetos para consulta posterior."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20260925_0022"
down_revision = "20260924_0021"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "projetos_salvos",
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("carro_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuarios.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["carro_id"], ["carros.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("usuario_id", "carro_id"),
    )
    op.create_index(
        "ix_projetos_salvos_usuario_criacao",
        "projetos_salvos",
        ["usuario_id", "criado_em", "carro_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_projetos_salvos_usuario_criacao", table_name="projetos_salvos")
    op.drop_table("projetos_salvos")
