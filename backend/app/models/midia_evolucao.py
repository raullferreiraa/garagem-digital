from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def agora_utc() -> datetime:
    return datetime.now(timezone.utc)


class MidiaEvolucao(Base):
    __tablename__ = "midias_evolucao"
    __table_args__ = (
        CheckConstraint(
            "tipo IN ('imagem', 'video')",
            name="midias_evolucao_tipo_valido",
        ),
        CheckConstraint(
            "ordem >= 0",
            name="midias_evolucao_ordem_valida",
        ),
        UniqueConstraint(
            "evolucao_id",
            "ordem",
            name="midias_evolucao_ordem_unica",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    evolucao_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("evolucoes_projeto.id", ondelete="CASCADE"),
        index=True,
    )
    url: Mapped[str] = mapped_column(Text)
    tipo: Mapped[str] = mapped_column(String(10), default="imagem")
    ordem: Mapped[int] = mapped_column(SmallInteger, default=0)
    criado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=agora_utc,
        server_default=func.now(),
    )

    evolucao = relationship("EvolucaoProjeto", back_populates="fotos")
