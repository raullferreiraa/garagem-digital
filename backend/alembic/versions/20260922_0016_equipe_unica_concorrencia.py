"""Garante equipe única também sob inserções concorrentes."""
from alembic import op

revision = "20260922_0016"
down_revision = "20260922_0015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Duplicidades, se existirem, interrompem a migração sem descartar dados.
    op.create_unique_constraint("uq_membros_equipe_usuario", "membros_equipe", ["usuario_id"])


def downgrade() -> None:
    op.drop_constraint("uq_membros_equipe_usuario", "membros_equipe", type_="unique")
