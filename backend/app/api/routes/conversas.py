from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.models.conversa import MensagemDireta
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
    mensagem_do_remetente,
    editar_mensagem,
    apagar_mensagem,
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
    busca: Annotated[str | None, Query(min_length=2, max_length=100)] = None,
) -> PaginaMensagens:
    conversa = buscar_conversa(db, conversa_id, usuario.id)
    if conversa is None:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada.")
    try:
        if busca is not None and len(busca.strip()) < 2:
            raise HTTPException(status_code=422, detail="Digite pelo menos dois caracteres.")
        return listar_mensagens(db, conversa, limite=limite, cursor=cursor, busca=busca)
    except CursorInvalido as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.get("/{conversa_id}/mensagens/{mensagem_id}", response_model=MensagemResposta)
def obter_mensagem_da_conversa(
    conversa_id: UUID, mensagem_id: UUID, usuario: UsuarioAtual, db: DbSession,
) -> MensagemResposta:
    if buscar_conversa(db, conversa_id, usuario.id) is None:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada.")
    mensagem = db.get(MensagemDireta, mensagem_id)
    if mensagem is None or mensagem.conversa_id != conversa_id:
        raise HTTPException(status_code=404, detail="Mensagem nao encontrada.")
    return MensagemResposta.model_validate(mensagem)


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
    try:
        mensagem = enviar_mensagem(db, conversa, usuario.id, dados.conteudo, dados.resposta_a_id)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    return MensagemResposta.model_validate(mensagem)


@router.patch("/{conversa_id}/mensagens/{mensagem_id}", response_model=MensagemResposta)
def alterar_mensagem(
    conversa_id: UUID,
    mensagem_id: UUID,
    dados: EnviarMensagem,
    usuario: UsuarioAtual,
    db: DbSession,
) -> MensagemResposta:
    if buscar_conversa(db, conversa_id, usuario.id) is None:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada.")
    mensagem = mensagem_do_remetente(db, conversa_id, mensagem_id, usuario.id)
    if mensagem is None:
        raise HTTPException(status_code=404, detail="Mensagem nao encontrada.")
    if mensagem.excluida_em is not None:
        raise HTTPException(status_code=409, detail="Esta mensagem foi apagada.")
    return MensagemResposta.model_validate(editar_mensagem(db, mensagem, dados.conteudo))


@router.delete(
    "/{conversa_id}/mensagens/{mensagem_id}", status_code=status.HTTP_204_NO_CONTENT
)
def apagar_mensagem_direta(
    conversa_id: UUID,
    mensagem_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    if buscar_conversa(db, conversa_id, usuario.id) is None:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada.")
    mensagem = mensagem_do_remetente(db, conversa_id, mensagem_id, usuario.id)
    if mensagem is None:
        raise HTTPException(status_code=404, detail="Mensagem nao encontrada.")
    apagar_mensagem(db, mensagem)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


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
