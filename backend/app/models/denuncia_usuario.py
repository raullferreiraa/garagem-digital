from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class DenunciaUsuario(Base):
    __tablename__ = "denuncias_usuarios"
    __table_args__ = (
        UniqueConstraint(
            "denunciante_id",
            "denunciado_id",
            name="uq_denuncias_usuarios_par",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True), primary_key=True, default=uuid4
    )
    denunciante_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    denunciado_id: Mapped[UUID] = mapped_column(
        PostgresUUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
    )
    motivo: Mapped[str] = mapped_column(String(40))
    detalhes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pendente", server_default="pendente")
    criada_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
