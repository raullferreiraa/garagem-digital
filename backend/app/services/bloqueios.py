from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.bloqueio_usuario import BloqueioUsuario


def existe_bloqueio(db: Session, usuario_a: UUID, usuario_b: UUID) -> bool:
    if usuario_a == usuario_b:
        return False
    return db.scalar(
        select(BloqueioUsuario.bloqueador_id).where(
            or_(
                (BloqueioUsuario.bloqueador_id == usuario_a)
                & (BloqueioUsuario.bloqueado_id == usuario_b),
                (BloqueioUsuario.bloqueador_id == usuario_b)
                & (BloqueioUsuario.bloqueado_id == usuario_a),
            )
        )
    ) is not None


def ids_com_bloqueio(db: Session, usuario_id: UUID):
    return select(BloqueioUsuario.bloqueado_id).where(
        BloqueioUsuario.bloqueador_id == usuario_id
    ).union(
        select(BloqueioUsuario.bloqueador_id).where(
            BloqueioUsuario.bloqueado_id == usuario_id
        )
    )
