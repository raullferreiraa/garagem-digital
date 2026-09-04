from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, SmallInteger, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def agora_utc() -> datetime:
    return datetime.now(timezone.utc)


class Carro(Base):
    __tablename__ = "carros"

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    proprietario_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    modelo: Mapped[str] = mapped_column(String(100))
    ano: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    cor: Mapped[str | None] = mapped_column(String(50), nullable=True)
    placa: Mapped[str | None] = mapped_column(String(10), nullable=True)
    placa_visivel: Mapped[bool] = mapped_column(Boolean, default=False)
    tipo_suspensao: Mapped[str | None] = mapped_column(String(50), nullable=True)
    aro_roda: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    foto_principal_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    historia: Mapped[str | None] = mapped_column(Text, nullable=True)
    motor: Mapped[str | None] = mapped_column(String(100), nullable=True)
    cambio: Mapped[str | None] = mapped_column(String(50), nullable=True)
    combustivel: Mapped[str | None] = mapped_column(String(120), nullable=True)
    potencia_estimada: Mapped[str | None] = mapped_column(String(50), nullable=True)
    preparacao: Mapped[str | None] = mapped_column(String(100), nullable=True)
    status_projeto: Mapped[str | None] = mapped_column(String(50), nullable=True)
    criado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=agora_utc,
        server_default=func.now(),
    )
    atualizado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=agora_utc,
        server_default=func.now(),
        onupdate=agora_utc,
    )

    proprietario = relationship("Usuario", back_populates="carros", lazy="joined")

    @property
    def placa_publica(self) -> str | None:
        return self.placa if self.placa_visivel else None
