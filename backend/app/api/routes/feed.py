import base64
import binascii
import json
from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, desc, func, or_, select
from sqlalchemy.orm import Session, joinedload

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.models.carro import Carro
from app.models.evolucao_projeto import EvolucaoProjeto
from app.models.seguidor import Seguidor
from app.schemas.carro import CarroPublico
from app.schemas.evolucao import EvolucaoResposta
from app.schemas.feed import ItemFeedSeguindo, PaginaFeedSeguindo
from app.services.bloqueios import ids_com_bloqueio


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


def _encode_cursor(evolution: EvolucaoProjeto) -> str:
    date = evolution.ocorreu_em or evolution.criado_em
    payload = json.dumps(
        {"data": date.isoformat(), "id": str(evolution.id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def _decode_cursor(cursor: str) -> tuple[datetime, UUID]:
    try:
        padding = "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(cursor + padding))
        if not isinstance(payload["id"], str):
            raise ValueError("Identificador do cursor invalido.")
        return datetime.fromisoformat(payload["data"]), UUID(payload["id"])
    except (KeyError, TypeError, ValueError, binascii.Error) as error:
        raise HTTPException(status_code=400, detail="Cursor de paginacao invalido.") from error


def _following_evolutions(
    db: Session,
    user_id: UUID,
    *,
    limit: int,
    cursor: str | None = None,
) -> list[EvolucaoProjeto]:
    date = func.coalesce(EvolucaoProjeto.ocorreu_em, EvolucaoProjeto.criado_em)
    followed = select(Seguidor.seguido_id).where(
        Seguidor.seguidor_id == user_id,
        Seguidor.seguido_id.not_in(ids_com_bloqueio(db, user_id)),
    )
    query = (
        select(EvolucaoProjeto)
        .options(joinedload(EvolucaoProjeto.carro))
        .join(Carro, Carro.id == EvolucaoProjeto.carro_id)
        .where(Carro.proprietario_id.in_(followed))
    )
    if cursor is not None:
        cursor_date, cursor_id = _decode_cursor(cursor)
        query = query.where(
            or_(
                date < cursor_date,
                and_(date == cursor_date, EvolucaoProjeto.id < cursor_id),
            )
        )
    return list(
        db.scalars(query.order_by(desc(date), EvolucaoProjeto.id.desc()).limit(limit))
        .unique()
    )


def _feed_items(evolutions: list[EvolucaoProjeto]) -> list[ItemFeedSeguindo]:
    return [
        ItemFeedSeguindo(
            evolucao=EvolucaoResposta.model_validate(evolution),
            carro=CarroPublico.model_validate(evolution.carro),
        )
        for evolution in evolutions
    ]


@router.get("/seguindo", response_model=list[ItemFeedSeguindo])
def feed_seguindo(
    usuario: UsuarioAtual,
    db: DbSession,
    limite: Annotated[int, Query(ge=1, le=50)] = 20,
) -> list[ItemFeedSeguindo]:
    return _feed_items(_following_evolutions(db, usuario.id, limit=limite))


@router.get("/seguindo/pagina", response_model=PaginaFeedSeguindo)
def feed_seguindo_pagina(
    usuario: UsuarioAtual,
    db: DbSession,
    limite: Annotated[int, Query(ge=1, le=50)] = 20,
    cursor: Annotated[str | None, Query(max_length=512)] = None,
) -> PaginaFeedSeguindo:
    evolutions = _following_evolutions(
        db, usuario.id, limit=limite + 1, cursor=cursor
    )
    has_more = len(evolutions) > limite
    page = evolutions[:limite]
    return PaginaFeedSeguindo(
        itens=_feed_items(page),
        proximo_cursor=_encode_cursor(page[-1]) if has_more else None,
    )
