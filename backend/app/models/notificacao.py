from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def agora_utc() -> datetime:
    return datetime.now(timezone.utc)


class Notificacao(Base):
    __tablename__ = "notificacoes"

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    destinatario_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    ator_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        nullable=True,
    )
    tipo: Mapped[str] = mapped_column(String(50), index=True)
    mensagem: Mapped[str] = mapped_column(String(240))
    carro_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        nullable=True,
    )
    evolucao_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        nullable=True,
    )
    equipe_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        nullable=True,
    )
    comentario_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        nullable=True,
    )
    lida_em: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    criada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=agora_utc,
        server_default=func.now(),
    )

    ator = relationship("Usuario", foreign_keys=[ator_id], lazy="joined")
