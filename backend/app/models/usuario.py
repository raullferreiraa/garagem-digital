from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    nome: Mapped[str] = mapped_column(String(100))
    username: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True)
    senha_hash: Mapped[str] = mapped_column(Text)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    bio: Mapped[str | None] = mapped_column(String(280), nullable=True)
    cidade: Mapped[str | None] = mapped_column(String(120), nullable=True)
    estado: Mapped[str | None] = mapped_column(String(120), nullable=True)
    ativo: Mapped[bool] = mapped_column(Boolean, default=True)
    criado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    atualizado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

