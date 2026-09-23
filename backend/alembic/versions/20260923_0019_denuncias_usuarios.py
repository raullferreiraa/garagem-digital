"""Registra denúncias de perfis."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20260923_0019"
down_revision = "20260922_0018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "denuncias_usuarios",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("denunciante_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("denunciado_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("motivo", sa.String(length=40), nullable=False),
        sa.Column("detalhes", sa.String(length=500), nullable=True),
        sa.Column("status", sa.String(length=20), server_default="pendente", nullable=False),
        sa.Column("criada_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["denunciante_id"], ["usuarios.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["denunciado_id"], ["usuarios.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("denunciante_id", "denunciado_id", name="uq_denuncias_usuarios_par"),
    )
    op.create_index("ix_denuncias_usuarios_denunciante_id", "denuncias_usuarios", ["denunciante_id"])
    op.create_index("ix_denuncias_usuarios_denunciado_id", "denuncias_usuarios", ["denunciado_id"])


def downgrade() -> None:
    op.drop_index("ix_denuncias_usuarios_denunciado_id", table_name="denuncias_usuarios")
    op.drop_index("ix_denuncias_usuarios_denunciante_id", table_name="denuncias_usuarios")
    op.drop_table("denuncias_usuarios")
