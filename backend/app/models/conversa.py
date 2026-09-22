from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def agora_utc() -> datetime:
    return datetime.now(timezone.utc)


class ConversaDireta(Base):
    __tablename__ = "conversas_diretas"
    __table_args__ = (
        UniqueConstraint(
            "usuario_a_id",
            "usuario_b_id",
            name="uq_conversas_diretas_usuarios",
        ),
        CheckConstraint(
            "usuario_a_id <> usuario_b_id",
            name="ck_conversas_diretas_usuarios_distintos",
        ),
        CheckConstraint(
            "usuario_a_id < usuario_b_id",
            name="ck_conversas_diretas_ordem_usuarios",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    usuario_a_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    usuario_b_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    usuario_a_leu_em: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    usuario_b_leu_em: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    criada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=agora_utc,
        server_default=func.now(),
    )
    atualizada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=agora_utc,
        server_default=func.now(),
    )

    usuario_a = relationship("Usuario", foreign_keys=[usuario_a_id], lazy="joined")
    usuario_b = relationship("Usuario", foreign_keys=[usuario_b_id], lazy="joined")
    mensagens = relationship(
        "MensagemDireta",
        back_populates="conversa",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class MensagemDireta(Base):
    __tablename__ = "mensagens_diretas"
    __table_args__ = (
        Index(
            "ix_mensagens_diretas_conversa_criada_id",
            "conversa_id",
            "criada_em",
            "id",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    conversa_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("conversas_diretas.id", ondelete="CASCADE"),
        index=True,
    )
    remetente_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    conteudo: Mapped[str] = mapped_column(String(2000))
    criada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=agora_utc,
        server_default=func.now(),
    )

    conversa = relationship("ConversaDireta", back_populates="mensagens")
    remetente = relationship("Usuario", foreign_keys=[remetente_id], lazy="joined")
