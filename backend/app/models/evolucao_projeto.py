from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def agora_utc() -> datetime:
    return datetime.now(timezone.utc)


class EvolucaoProjeto(Base):
    __tablename__ = "evolucoes_projeto"
    __table_args__ = (
        CheckConstraint(
            "categoria IS NULL OR categoria IN "
            "('mecanica', 'estetica', 'manutencao', 'evento', 'historia', 'outra')",
            name="evolucoes_categoria_valida",
        ),
        CheckConstraint(
            "quilometragem_km IS NULL OR quilometragem_km >= 0",
            name="evolucoes_quilometragem_valida",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    carro_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("carros.id", ondelete="CASCADE"),
        index=True,
    )
    autor_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    titulo: Mapped[str] = mapped_column(String(120))
    descricao: Mapped[str] = mapped_column(Text)
    categoria: Mapped[str | None] = mapped_column(String(30), nullable=True)
    ocorreu_em: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    quilometragem_km: Mapped[int | None] = mapped_column(Integer, nullable=True)
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

    carro = relationship("Carro", back_populates="evolucoes")
    autor = relationship("Usuario", lazy="joined")
    fotos = relationship(
        "MidiaEvolucao",
        back_populates="evolucao",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="MidiaEvolucao.ordem",
    )
