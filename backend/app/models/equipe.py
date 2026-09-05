from datetime import datetime, timezone
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def agora_utc() -> datetime:
    return datetime.now(timezone.utc)


class Equipe(Base):
    __tablename__ = "equipes"

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True), primary_key=True, default=uuid4
    )
    dono_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="RESTRICT"),
        index=True,
    )
    nome: Mapped[str] = mapped_column(String(100))
    slug: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    descricao: Mapped[str | None] = mapped_column(String(500), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    capa_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    cidade: Mapped[str | None] = mapped_column(String(120), nullable=True)
    estado: Mapped[str | None] = mapped_column(String(120), nullable=True)
    visibilidade: Mapped[str] = mapped_column(String(20), default="publica")
    criado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=agora_utc, server_default=func.now()
    )
    atualizado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=agora_utc,
        server_default=func.now(),
        onupdate=agora_utc,
    )


class MembroEquipe(Base):
    __tablename__ = "membros_equipe"

    equipe_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("equipes.id", ondelete="CASCADE"),
        primary_key=True,
    )
    usuario_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        primary_key=True,
    )
    papel: Mapped[str] = mapped_column(String(20), default="membro")
    entrou_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=agora_utc, server_default=func.now()
    )


class SolicitacaoEquipe(Base):
    __tablename__ = "solicitacoes_equipe"

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True), primary_key=True, default=uuid4
    )
    equipe_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("equipes.id", ondelete="CASCADE"),
        index=True,
    )
    usuario_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    status: Mapped[str] = mapped_column(String(20), default="pendente")
    analisada_por: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        nullable=True,
    )
    criada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=agora_utc, server_default=func.now()
    )
    analisada_em: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class CarroEquipe(Base):
    __tablename__ = "carros_equipe"

    equipe_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("equipes.id", ondelete="CASCADE"),
        primary_key=True,
    )
    carro_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("carros.id", ondelete="CASCADE"),
        primary_key=True,
    )
    adicionado_por: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="RESTRICT"),
        index=True,
    )
    adicionado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=agora_utc, server_default=func.now()
    )
