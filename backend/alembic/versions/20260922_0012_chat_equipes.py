"""Adiciona chat de equipes.

Revision ID: 20260922_0012
Revises: 20260922_0011
"""
from collections.abc import Sequence
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20260922_0012"
down_revision: str | None = "20260922_0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

def upgrade() -> None:
    op.create_table(
        "leituras_chat_equipe",
        sa.Column("equipe_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("usuario_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "ultima_leitura_em",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["equipe_id"], ["equipes.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuarios.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("equipe_id", "usuario_id"),
    )
    op.create_index(
        "ix_leituras_chat_equipe_usuario_id",
        "leituras_chat_equipe",
        ["usuario_id"],
    )
    op.create_table("mensagens_equipe", sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("equipe_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("autor_id", postgresql.UUID(as_uuid=True), nullable=False), sa.Column("conteudo", sa.String(length=2000), nullable=False), sa.Column("criada_em", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False), sa.ForeignKeyConstraint(["equipe_id"], ["equipes.id"], ondelete="CASCADE"), sa.ForeignKeyConstraint(["autor_id"], ["usuarios.id"], ondelete="CASCADE"), sa.PrimaryKeyConstraint("id"))
    op.create_index("ix_mensagens_equipe_equipe_id", "mensagens_equipe", ["equipe_id"])
    op.create_index("ix_mensagens_equipe_autor_id", "mensagens_equipe", ["autor_id"])
    op.create_index("ix_mensagens_equipe_equipe_criada_id", "mensagens_equipe", ["equipe_id", "criada_em", "id"])
    op.execute(
        """
        CREATE FUNCTION impedir_multiplas_equipes_por_usuario()
        RETURNS trigger AS $$
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM membros_equipe
                WHERE usuario_id = NEW.usuario_id
                  AND equipe_id <> NEW.equipe_id
            ) THEN
                RAISE EXCEPTION 'Um usuário só pode participar de uma equipe.';
            END IF;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;

        CREATE TRIGGER membros_equipe_uma_equipe_por_usuario
        BEFORE INSERT OR UPDATE OF usuario_id, equipe_id ON membros_equipe
        FOR EACH ROW EXECUTE FUNCTION impedir_multiplas_equipes_por_usuario();
        """
    )

def downgrade() -> None:
    op.execute("DROP TRIGGER membros_equipe_uma_equipe_por_usuario ON membros_equipe")
    op.execute("DROP FUNCTION impedir_multiplas_equipes_por_usuario()")
    op.drop_index("ix_mensagens_equipe_equipe_criada_id", table_name="mensagens_equipe")
    op.drop_index("ix_mensagens_equipe_autor_id", table_name="mensagens_equipe")
    op.drop_index("ix_mensagens_equipe_equipe_id", table_name="mensagens_equipe")
    op.drop_table("mensagens_equipe")
    op.drop_index("ix_leituras_chat_equipe_usuario_id", table_name="leituras_chat_equipe")
    op.drop_table("leituras_chat_equipe")
