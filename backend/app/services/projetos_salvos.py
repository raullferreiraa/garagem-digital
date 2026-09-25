import base64
import binascii
import json
from datetime import datetime
from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.carro import Carro
from app.models.projeto_salvo import ProjetoSalvo
from app.schemas.carro import CarroPublico, PaginaCarros
from app.services.bloqueios import existe_bloqueio, ids_com_bloqueio


class CursorSalvosInvalido(ValueError):
    pass


def carro_acessivel(db: Session, carro_id: UUID, usuario_id: UUID) -> Carro | None:
    carro = db.get(Carro, carro_id)
    if carro is None or existe_bloqueio(db, usuario_id, carro.proprietario_id):
        return None
    return carro


def esta_salvo(db: Session, usuario_id: UUID, carro_id: UUID) -> bool:
    return db.get(ProjetoSalvo, (usuario_id, carro_id)) is not None


def salvar(db: Session, usuario_id: UUID, carro_id: UUID) -> None:
    if esta_salvo(db, usuario_id, carro_id):
        return
    db.add(ProjetoSalvo(usuario_id=usuario_id, carro_id=carro_id))
    try:
        db.commit()
    except IntegrityError:
        # Duas solicitações simultâneas para o mesmo projeto são idempotentes.
        db.rollback()
        if not esta_salvo(db, usuario_id, carro_id):
            raise


def remover(db: Session, usuario_id: UUID, carro_id: UUID) -> None:
    salvo = db.get(ProjetoSalvo, (usuario_id, carro_id))
    if salvo is not None:
        db.delete(salvo)
        db.commit()


def _codificar_cursor(salvo: ProjetoSalvo) -> str:
    conteudo = json.dumps(
        {"criado_em": salvo.criado_em.isoformat(), "carro_id": str(salvo.carro_id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(conteudo).decode("ascii").rstrip("=")


def _decodificar_cursor(cursor: str) -> tuple[datetime, UUID]:
    try:
        dados = json.loads(base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)))
        return datetime.fromisoformat(dados["criado_em"]), UUID(dados["carro_id"])
    except (KeyError, TypeError, ValueError, binascii.Error) as error:
        raise CursorSalvosInvalido("Cursor de paginacao invalido.") from error


def listar_salvos(
    db: Session, usuario_id: UUID, *, limite: int, cursor: str | None
) -> PaginaCarros:
    consulta = (
        select(ProjetoSalvo, Carro)
        .join(Carro, Carro.id == ProjetoSalvo.carro_id)
        .where(
            ProjetoSalvo.usuario_id == usuario_id,
            Carro.proprietario_id.not_in(ids_com_bloqueio(db, usuario_id)),
        )
    )
    if cursor:
        criado_em, carro_id = _decodificar_cursor(cursor)
        consulta = consulta.where(
            or_(
                ProjetoSalvo.criado_em < criado_em,
                and_(
                    ProjetoSalvo.criado_em == criado_em,
                    ProjetoSalvo.carro_id < carro_id,
                ),
            )
        )
    encontrados = db.execute(
        consulta.order_by(
            ProjetoSalvo.criado_em.desc(), ProjetoSalvo.carro_id.desc()
        ).limit(limite + 1)
    ).unique().all()
    tem_proxima = len(encontrados) > limite
    encontrados = encontrados[:limite]
    return PaginaCarros(
        itens=[CarroPublico.model_validate(carro) for _, carro in encontrados],
        proximo_cursor=(
            _codificar_cursor(encontrados[-1][0])
            if tem_proxima and encontrados
            else None
        ),
    )
