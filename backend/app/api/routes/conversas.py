from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.schemas.conversa import (
    ConversaResumo,
    CriarConversaDireta,
    EnviarMensagem,
    MensagemResposta,
    PaginaMensagens,
    TotalConversasNaoLidas,
)
from app.services.conversas import (
    CursorInvalido,
    buscar_conversa,
    criar_ou_obter_conversa,
    enviar_mensagem,
    listar_conversas,
    listar_mensagens,
    marcar_conversa_como_lida,
    resumir_conversa,
    total_conversas_nao_lidas,
)


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


@router.get("", response_model=list[ConversaResumo])
def minhas_conversas(
    usuario: UsuarioAtual,
    db: DbSession,
) -> list[ConversaResumo]:
    return listar_conversas(db, usuario.id)


@router.get("/nao-lidas", response_model=TotalConversasNaoLidas)
def conversas_nao_lidas(
    usuario: UsuarioAtual,
    db: DbSession,
) -> TotalConversasNaoLidas:
    return TotalConversasNaoLidas(total=total_conversas_nao_lidas(db, usuario.id))


@router.post("/diretas", response_model=ConversaResumo)
def iniciar_conversa(
    dados: CriarConversaDireta,
    usuario: UsuarioAtual,
    db: DbSession,
) -> ConversaResumo:
    try:
        conversa = criar_ou_obter_conversa(db, usuario.id, dados.usuario_id)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    if conversa is None:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado.")
    return resumir_conversa(db, conversa, usuario.id)


@router.get("/{conversa_id}/mensagens", response_model=PaginaMensagens)
def mensagens_da_conversa(
    conversa_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
    limite: Annotated[int, Query(ge=1, le=50)] = 30,
    cursor: str | None = None,
) -> PaginaMensagens:
    conversa = buscar_conversa(db, conversa_id, usuario.id)
    if conversa is None:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada.")
    try:
        return listar_mensagens(db, conversa, limite=limite, cursor=cursor)
    except CursorInvalido as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.post(
    "/{conversa_id}/mensagens",
    response_model=MensagemResposta,
    status_code=status.HTTP_201_CREATED,
)
def publicar_mensagem(
    conversa_id: UUID,
    dados: EnviarMensagem,
    usuario: UsuarioAtual,
    db: DbSession,
) -> MensagemResposta:
    conversa = buscar_conversa(db, conversa_id, usuario.id)
    if conversa is None:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada.")
    mensagem = enviar_mensagem(db, conversa, usuario.id, dados.conteudo)
    return MensagemResposta.model_validate(mensagem)


@router.post("/{conversa_id}/lida", status_code=status.HTTP_204_NO_CONTENT)
def ler_conversa(
    conversa_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    conversa = buscar_conversa(db, conversa_id, usuario.id)
    if conversa is None:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada.")
    marcar_conversa_como_lida(db, conversa, usuario.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
