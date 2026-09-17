from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.schemas.notificacao import (
    NotificacaoResposta,
    TotalNotificacoesResposta,
)
from app.services.notificacoes import (
    listar_notificacoes,
    marcar_como_lida,
    marcar_todas_como_lidas,
    total_nao_lidas,
)


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


@router.get("", response_model=list[NotificacaoResposta])
def minhas_notificacoes(
    usuario: UsuarioAtual,
    db: DbSession,
) -> list[NotificacaoResposta]:
    return [
        NotificacaoResposta.model_validate(item)
        for item in listar_notificacoes(db, usuario.id)
    ]


@router.get("/nao-lidas", response_model=TotalNotificacoesResposta)
def notificacoes_nao_lidas(
    usuario: UsuarioAtual,
    db: DbSession,
) -> TotalNotificacoesResposta:
    return TotalNotificacoesResposta(total=total_nao_lidas(db, usuario.id))


@router.patch("/{notificacao_id}/lida", response_model=NotificacaoResposta)
def ler_notificacao(
    notificacao_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> NotificacaoResposta:
    notificacao = marcar_como_lida(db, notificacao_id, usuario.id)
    if notificacao is None:
        raise HTTPException(status_code=404, detail="Notificacao nao encontrada.")
    return NotificacaoResposta.model_validate(notificacao)


@router.post("/lidas", status_code=status.HTTP_204_NO_CONTENT)
def ler_todas(
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    marcar_todas_como_lidas(db, usuario.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
