"""Vincula respostas à mensagem original, sem duplicar seu conteúdo."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20260926_0024"
down_revision = "20260925_0023"
branch_labels = None
depends_on = None


def upgrade() -> None:
    for tabela in ("mensagens_diretas", "mensagens_equipe"):
        op.add_column(tabela, sa.Column("resposta_a_id", postgresql.UUID(as_uuid=True), nullable=True))
        op.create_foreign_key(
            f"fk_{tabela}_resposta", tabela, tabela,
            ["resposta_a_id"], ["id"], ondelete="SET NULL",
        )


def downgrade() -> None:
    for tabela in ("mensagens_diretas", "mensagens_equipe"):
        op.drop_constraint(f"fk_{tabela}_resposta", tabela, type_="foreignkey")
        op.drop_column(tabela, "resposta_a_id")
