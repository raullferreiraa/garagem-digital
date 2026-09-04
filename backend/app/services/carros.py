import base64
import json
from datetime import datetime
from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session

from app.models.carro import Carro
from app.models.usuario import Usuario
from app.schemas.carro import CarroCriacao, CarroPublico, PaginaCarros


class CursorInvalido(ValueError):
    pass


def _codificar_cursor(carro: Carro) -> str:
    conteudo = json.dumps(
        {"criado_em": carro.criado_em.isoformat(), "id": str(carro.id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(conteudo).decode("ascii").rstrip("=")


def _decodificar_cursor(cursor: str) -> tuple[datetime, UUID]:
    try:
        padding = "=" * (-len(cursor) % 4)
        dados = json.loads(base64.urlsafe_b64decode(cursor + padding))
        return datetime.fromisoformat(dados["criado_em"]), UUID(dados["id"])
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise CursorInvalido("Cursor de paginacao invalido.") from error


def criar_carro(db: Session, usuario: Usuario, dados: CarroCriacao) -> Carro:
    carro = Carro(proprietario_id=usuario.id, **dados.model_dump())
    db.add(carro)
    db.commit()
    db.refresh(carro)
    return carro


def obter_carro(db: Session, carro_id: UUID) -> Carro | None:
    return db.scalar(select(Carro).where(Carro.id == carro_id))


def obter_carro_do_proprietario(
    db: Session,
    carro_id: UUID,
    proprietario_id: UUID,
) -> Carro | None:
    return db.scalar(
        select(Carro).where(
            Carro.id == carro_id,
            Carro.proprietario_id == proprietario_id,
        )
    )


def listar_carros_do_usuario(db: Session, usuario_id: UUID) -> list[Carro]:
    return list(
        db.scalars(
            select(Carro)
            .where(Carro.proprietario_id == usuario_id)
            .order_by(Carro.criado_em.desc(), Carro.id.desc())
        ).unique()
    )


def listar_feed(db: Session, limite: int, cursor: str | None) -> PaginaCarros:
    consulta = select(Carro).order_by(Carro.criado_em.desc(), Carro.id.desc())

    if cursor:
        criado_em, carro_id = _decodificar_cursor(cursor)
        consulta = consulta.where(
            or_(
                Carro.criado_em < criado_em,
                and_(Carro.criado_em == criado_em, Carro.id < carro_id),
            )
        )

    carros = list(db.scalars(consulta.limit(limite + 1)).unique())
    tem_proxima = len(carros) > limite
    carros = carros[:limite]

    return PaginaCarros(
        itens=[CarroPublico.model_validate(carro) for carro in carros],
        proximo_cursor=(
            _codificar_cursor(carros[-1]) if tem_proxima and carros else None
        ),
    )


def excluir_carro(db: Session, carro_id: UUID, proprietario_id: UUID) -> bool:
    carro = obter_carro_do_proprietario(db, carro_id, proprietario_id)
    if carro is None:
        return False
    db.delete(carro)
    db.commit()
    return True
