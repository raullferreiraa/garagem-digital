from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.carro import agora_utc


class FotoProjeto(Base):
    __tablename__ = "fotos_projeto"
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    carro_id: Mapped[UUID] = mapped_column(ForeignKey("carros.id", ondelete="CASCADE"), index=True)
    url: Mapped[str] = mapped_column(Text)
    legenda: Mapped[str] = mapped_column(String(160), default="")
    ordem: Mapped[int] = mapped_column(Integer, default=0)


class EtapaProjeto(Base):
    __tablename__ = "etapas_projeto"
    __table_args__ = (CheckConstraint("status IN ('planejada', 'em_andamento', 'concluida')", name="etapa_status_valido"),)
    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    carro_id: Mapped[UUID] = mapped_column(ForeignKey("carros.id", ondelete="CASCADE"), index=True)
    titulo: Mapped[str] = mapped_column(String(100))
    descricao: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="planejada")
    evolucao_id: Mapped[UUID | None] = mapped_column(ForeignKey("evolucoes_projeto.id", ondelete="SET NULL"), nullable=True)
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=agora_utc)
