from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.config import settings
from app.core.database import get_db
from app.models.equipe import Equipe
from app.schemas.equipe import (
    ConviteCriacao,
    ConviteDecisao,
    EscolhaCarro,
    EquipeAtualizacao,
    EquipeCriacao,
    EquipeDetalhe,
    EquipeResumo,
    PapelMembroAtualizacao,
    SolicitacaoDecisao,
)
from app.services.equipes import (
    AcaoNaoPermitida,
    EquipeNaoEncontrada,
    EstadoInvalido,
    convidar_usuario,
    criar_equipe,
    decidir_convite,
    decidir_solicitacao,
    detalhar_equipe,
    escolher_carro,
    listar_equipes,
    obter_equipe,
    alterar_papel_membro,
    atualizar_equipe,
    remover_carro_escolhido,
    remover_membro,
    solicitar_entrada,
)

from app.services.media import (
    ArquivoMuitoGrande,
    ImagemInvalida,
    remover_media,
    salvar_imagem_equipe,
)


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


def _erro(error: ValueError) -> HTTPException:
    if isinstance(error, EquipeNaoEncontrada):
        return HTTPException(status_code=404, detail=str(error))
    if isinstance(error, AcaoNaoPermitida):
        return HTTPException(status_code=403, detail=str(error))
    return HTTPException(status_code=409, detail=str(error))


@router.get("", response_model=list[EquipeResumo])
def equipes(
    usuario: UsuarioAtual,
    db: DbSession,
    busca: Annotated[str | None, Query(min_length=2, max_length=100)] = None,
) -> list[EquipeResumo]:
    return listar_equipes(db, usuario.id, busca=busca)


@router.post("", response_model=EquipeDetalhe, status_code=status.HTTP_201_CREATED)
def cadastrar_equipe(
    dados: EquipeCriacao, usuario: UsuarioAtual, db: DbSession
) -> EquipeDetalhe:
    equipe = criar_equipe(db, usuario, dados)
    return detalhar_equipe(db, equipe.id, usuario.id)


@router.patch("/{equipe_id}", response_model=EquipeDetalhe)
def editar_equipe(
    equipe_id: UUID, dados: EquipeAtualizacao, usuario: UsuarioAtual, db: DbSession
) -> EquipeDetalhe:
    try:
        atualizar_equipe(db, equipe_id, usuario, dados)
        return detalhar_equipe(db, equipe_id, usuario.id)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error


def _equipe_do_dono(db: Session, equipe_id: UUID, usuario: UsuarioAtual) -> Equipe:
    try:
        equipe = obter_equipe(db, equipe_id)
    except EquipeNaoEncontrada as error:
        raise _erro(error) from error
    if equipe.dono_id != usuario.id:
        raise HTTPException(status_code=403, detail="Apenas o dono pode alterar imagens.")
    return equipe


@router.post("/{equipe_id}/imagens/{tipo}", response_model=EquipeDetalhe)
async def enviar_imagem_equipe(
    equipe_id: UUID,
    tipo: Literal["avatar", "capa"],
    usuario: UsuarioAtual,
    db: DbSession,
    arquivo: Annotated[UploadFile, File()],
) -> EquipeDetalhe:
    equipe = _equipe_do_dono(db, equipe_id, usuario)
    conteudo = await arquivo.read(settings.media_max_upload_bytes + 1)
    try:
        nova_url = salvar_imagem_equipe(equipe_id, tipo, conteudo)
    except ArquivoMuitoGrande as error:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="A foto deve ter no maximo 10 MB.",
        ) from error
    except ImagemInvalida as error:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Envie uma imagem JPEG, PNG ou WebP valida.",
        ) from error

    campo = "avatar_url" if tipo == "avatar" else "capa_url"
    url_anterior = getattr(equipe, campo)
    setattr(equipe, campo, nova_url)
    db.commit()
    remover_media(url_anterior)
    return detalhar_equipe(db, equipe_id, usuario.id)


@router.delete("/{equipe_id}/imagens/{tipo}", response_model=EquipeDetalhe)
def remover_imagem_equipe(
    equipe_id: UUID,
    tipo: Literal["avatar", "capa"],
    usuario: UsuarioAtual,
    db: DbSession,
) -> EquipeDetalhe:
    equipe = _equipe_do_dono(db, equipe_id, usuario)
    campo = "avatar_url" if tipo == "avatar" else "capa_url"
    url_anterior = getattr(equipe, campo)
    setattr(equipe, campo, None)
    db.commit()
    remover_media(url_anterior)
    return detalhar_equipe(db, equipe_id, usuario.id)


@router.get("/{equipe_id}", response_model=EquipeDetalhe)
def detalhe_equipe(
    equipe_id: UUID, usuario: UsuarioAtual, db: DbSession
) -> EquipeDetalhe:
    try:
        return detalhar_equipe(db, equipe_id, usuario.id)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error


@router.post(
    "/{equipe_id}/solicitacoes",
    status_code=status.HTTP_204_NO_CONTENT,
)
def pedir_entrada(
    equipe_id: UUID, usuario: UsuarioAtual, db: DbSession
) -> Response:
    try:
        solicitar_entrada(db, equipe_id, usuario)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch(
    "/{equipe_id}/solicitacoes/{solicitacao_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def analisar_pedido(
    equipe_id: UUID,
    solicitacao_id: UUID,
    dados: SolicitacaoDecisao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    try:
        decidir_solicitacao(
            db, equipe_id, solicitacao_id, usuario, dados.decisao
        )
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{equipe_id}/convites", status_code=status.HTTP_204_NO_CONTENT)
def enviar_convite(
    equipe_id: UUID,
    dados: ConviteCriacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    try:
        convidar_usuario(db, equipe_id, dados.usuario_id, usuario)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch("/{equipe_id}/meu-convite", status_code=status.HTTP_204_NO_CONTENT)
def responder_convite(
    equipe_id: UUID,
    dados: ConviteDecisao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    try:
        decidir_convite(db, equipe_id, usuario, dados.decisao)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch(
    "/{equipe_id}/membros/{membro_id}/papel",
    status_code=status.HTTP_204_NO_CONTENT,
)
def atualizar_papel_membro(
    equipe_id: UUID,
    membro_id: UUID,
    dados: PapelMembroAtualizacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    try:
        alterar_papel_membro(db, equipe_id, membro_id, dados.papel, usuario)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/{equipe_id}/membros/{membro_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def excluir_membro(
    equipe_id: UUID,
    membro_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    try:
        remover_membro(db, equipe_id, membro_id, usuario)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.put("/{equipe_id}/meu-carro", status_code=status.HTTP_204_NO_CONTENT)
def selecionar_meu_carro(
    equipe_id: UUID,
    dados: EscolhaCarro,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    try:
        escolher_carro(db, equipe_id, dados.carro_id, usuario)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{equipe_id}/meu-carro", status_code=status.HTTP_204_NO_CONTENT)
def retirar_meu_carro(
    equipe_id: UUID, usuario: UsuarioAtual, db: DbSession
) -> Response:
    try:
        remover_carro_escolhido(db, equipe_id, usuario)
    except (EquipeNaoEncontrada, AcaoNaoPermitida, EstadoInvalido) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)
