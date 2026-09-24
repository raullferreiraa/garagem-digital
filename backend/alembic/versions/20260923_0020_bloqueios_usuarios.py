"""Permite bloquear interações entre usuários."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20260923_0020"
down_revision = "20260923_0019"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "bloqueios_usuarios",
        sa.Column("bloqueador_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("bloqueado_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("criado_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("bloqueador_id <> bloqueado_id", name="ck_bloqueio_usuarios_distintos"),
        sa.ForeignKeyConstraint(["bloqueador_id"], ["usuarios.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["bloqueado_id"], ["usuarios.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("bloqueador_id", "bloqueado_id"),
    )
    op.create_index("ix_bloqueios_usuarios_bloqueado_id", "bloqueios_usuarios", ["bloqueado_id"])


def downgrade() -> None:
    op.drop_index("ix_bloqueios_usuarios_bloqueado_id", table_name="bloqueios_usuarios")
    op.drop_table("bloqueios_usuarios")
