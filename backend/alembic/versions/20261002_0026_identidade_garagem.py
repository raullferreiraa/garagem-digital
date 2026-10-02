"""Identidade, galeria e etapas da garagem."""
from alembic import op
import sqlalchemy as sa

revision = "20261002_0026"
down_revision = "20260929_0025"
branch_labels = None
depends_on = None


def upgrade():
    for name, kind in [
        ("nome_projeto", sa.String(80)), ("proposta", sa.String(240)),
        ("adquirido_em", sa.String(10)), ("estado_inicial", sa.Text()),
        ("configuracao_original", sa.Text()), ("modificacoes", sa.Text()),
    ]:
        op.add_column("carros", sa.Column(name, kind, nullable=True))
    op.create_table("fotos_projeto",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("carro_id", sa.Uuid(), sa.ForeignKey("carros.id", ondelete="CASCADE"), nullable=False),
        sa.Column("url", sa.Text(), nullable=False),
        sa.Column("legenda", sa.String(160), nullable=False),
        sa.Column("ordem", sa.Integer(), nullable=False),
    )
    op.create_index("ix_fotos_projeto_carro_id", "fotos_projeto", ["carro_id"])
    op.create_table("etapas_projeto",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("carro_id", sa.Uuid(), sa.ForeignKey("carros.id", ondelete="CASCADE"), nullable=False),
        sa.Column("titulo", sa.String(100), nullable=False),
        sa.Column("descricao", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("evolucao_id", sa.Uuid(), sa.ForeignKey("evolucoes_projeto.id", ondelete="SET NULL"), nullable=True),
        sa.Column("criado_em", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("status IN ('planejada', 'em_andamento', 'concluida')", name="etapa_status_valido"),
    )
    op.create_index("ix_etapas_projeto_carro_id", "etapas_projeto", ["carro_id"])


def downgrade():
    op.drop_table("etapas_projeto")
    op.drop_table("fotos_projeto")
    for name in ("nome_projeto", "proposta", "adquirido_em", "estado_inicial", "configuracao_original", "modificacoes"):
        op.drop_column("carros", name)
