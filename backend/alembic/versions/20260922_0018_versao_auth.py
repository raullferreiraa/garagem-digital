"""Revoga tokens de acesso anteriores à troca de senha."""
from alembic import op
import sqlalchemy as sa

revision = "20260922_0018"
down_revision = "20260922_0017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("usuarios", sa.Column("versao_auth", sa.Integer(), nullable=False, server_default="0"))


def downgrade() -> None:
    op.drop_column("usuarios", "versao_auth")
