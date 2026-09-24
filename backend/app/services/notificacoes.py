from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import Session

from app.models.notificacao import Notificacao
from app.services.bloqueios import existe_bloqueio, ids_com_bloqueio


def criar_notificacao(
    db: Session,
    *,
    destinatario_id: UUID,
    ator_id: UUID | None,
    tipo: str,
    mensagem: str,
    carro_id: UUID | None = None,
    evolucao_id: UUID | None = None,
    equipe_id: UUID | None = None,
    comentario_id: UUID | None = None,
) -> Notificacao | None:
    if ator_id == destinatario_id:
        return None
    if ator_id is not None and existe_bloqueio(db, destinatario_id, ator_id):
        return None
    notificacao = Notificacao(
        destinatario_id=destinatario_id,
        ator_id=ator_id,
        tipo=tipo,
        mensagem=mensagem,
        carro_id=carro_id,
        evolucao_id=evolucao_id,
        equipe_id=equipe_id,
        comentario_id=comentario_id,
    )
    db.add(notificacao)
    return notificacao


def listar_notificacoes(
    db: Session,
    destinatario_id: UUID,
    *,
    limite: int = 100,
) -> list[Notificacao]:
    return list(
        db.scalars(
            select(Notificacao)
            .where(
                Notificacao.destinatario_id == destinatario_id,
                or_(
                    Notificacao.ator_id.is_(None),
                    Notificacao.ator_id.not_in(ids_com_bloqueio(db, destinatario_id)),
                ),
            )
            .order_by(Notificacao.criada_em.desc(), Notificacao.id.desc())
            .limit(limite)
        ).unique()
    )


def total_nao_lidas(db: Session, destinatario_id: UUID) -> int:
    return (
        db.scalar(
            select(func.count()).select_from(Notificacao).where(
                Notificacao.destinatario_id == destinatario_id,
                Notificacao.lida_em.is_(None),
                or_(
                    Notificacao.ator_id.is_(None),
                    Notificacao.ator_id.not_in(ids_com_bloqueio(db, destinatario_id)),
                ),
            )
        )
        or 0
    )


def marcar_como_lida(
    db: Session,
    notificacao_id: UUID,
    destinatario_id: UUID,
) -> Notificacao | None:
    notificacao = db.scalar(
        select(Notificacao).where(
            Notificacao.id == notificacao_id,
            Notificacao.destinatario_id == destinatario_id,
        )
    )
    if notificacao is None:
        return None
    if notificacao.lida_em is None:
        notificacao.lida_em = datetime.now(timezone.utc)
        db.commit()
        db.refresh(notificacao)
    return notificacao


def marcar_todas_como_lidas(db: Session, destinatario_id: UUID) -> None:
    db.execute(
        update(Notificacao)
        .where(
            Notificacao.destinatario_id == destinatario_id,
            Notificacao.lida_em.is_(None),
        )
        .values(lida_em=datetime.now(timezone.utc))
    )
    db.commit()
