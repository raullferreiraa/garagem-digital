from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Encontro(Base):
    __tablename__ = "encontros"

    capa_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True), primary_key=True, default=uuid4
    )
    organizador_usuario_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="SET NULL")
    )
    organizador_equipe_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True), ForeignKey("equipes.id", ondelete="SET NULL")
    )
    nome: Mapped[str] = mapped_column(String(140))
    descricao: Mapped[str | None] = mapped_column(Text, nullable=True)
    cidade: Mapped[str | None] = mapped_column(String(120), nullable=True)
    estado: Mapped[str | None] = mapped_column(String(120), nullable=True)
    visibilidade: Mapped[str] = mapped_column(String(20), default="publico")
    criado_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SeguidorEncontro(Base):
    __tablename__ = "seguidores_encontro"

    encontro_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True), ForeignKey("encontros.id", ondelete="CASCADE"), primary_key=True
    )
    usuario_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True), ForeignKey("usuarios.id", ondelete="CASCADE"), primary_key=True
    )
    seguido_em: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Evento(Base):
    __tablename__ = "eventos"

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True), primary_key=True, default=uuid4
    )
    encontro_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True), ForeignKey("encontros.id", ondelete="CASCADE"), index=True
    )
    organizador_usuario_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="SET NULL"),
        nullable=True,
    )
    organizador_equipe_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("equipes.id", ondelete="SET NULL"),
        nullable=True,
    )
    nome: Mapped[str] = mapped_column(String(140))
    descricao: Mapped[str | None] = mapped_column(Text, nullable=True)
    inicio: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    termino: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    endereco_publico: Mapped[str | None] = mapped_column(Text, nullable=True)
    cidade: Mapped[str | None] = mapped_column(String(120), nullable=True)
    estado: Mapped[str | None] = mapped_column(String(120), nullable=True)
    visibilidade: Mapped[str] = mapped_column(String(20), default="publico")
    status: Mapped[str] = mapped_column(String(20), default="agendada")
    criado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class PresencaEvento(Base):
    __tablename__ = "presencas_evento"

    evento_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("eventos.id", ondelete="CASCADE"),
        primary_key=True,
    )
    usuario_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        primary_key=True,
    )
    carro_id: Mapped[UUID | None] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("carros.id", ondelete="SET NULL"),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(String(20), default="confirmada")
    confirmada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ParticipacaoEquipeEvento(Base):
    __tablename__ = "participacoes_equipe_evento"

    evento_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("eventos.id", ondelete="CASCADE"),
        primary_key=True,
    )
    equipe_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("equipes.id", ondelete="CASCADE"),
        primary_key=True,
    )
    registrada_por: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
    )
    status: Mapped[str] = mapped_column(String(20), default="confirmada")
    registrada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
