"""Adiciona edição e remoção visível de mensagens."""

from alembic import op
import sqlalchemy as sa

revision = "20260925_0023"
down_revision = "20260925_0022"
branch_labels = None
depends_on = None


def upgrade() -> None:
    for tabela in ("mensagens_diretas", "mensagens_equipe"):
        op.add_column(tabela, sa.Column("editada_em", sa.DateTime(timezone=True), nullable=True))
        op.add_column(tabela, sa.Column("excluida_em", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    for tabela in ("mensagens_diretas", "mensagens_equipe"):
        op.drop_column(tabela, "excluida_em")
        op.drop_column(tabela, "editada_em")
