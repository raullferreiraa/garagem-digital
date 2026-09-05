from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.config import settings
from app.core.database import get_db
from app.models.midia_evolucao import MidiaEvolucao
from app.schemas.evolucao import (
    EvolucaoAtualizacao,
    EvolucaoCriacao,
    EvolucaoResposta,
)
from app.services.carros import obter_carro, obter_carro_do_proprietario
from app.services.evolucoes import (
    criar_evolucao,
    listar_evolucoes,
    obter_evolucao_do_autor,
    obter_foto_da_evolucao,
)
from app.services.media import (
    ArquivoMuitoGrande,
    ImagemInvalida,
    remover_media,
    salvar_foto_evolucao,
)


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]
MAX_FOTOS_POR_EVOLUCAO = 8


@router.get("/{carro_id}/evolucoes", response_model=list[EvolucaoResposta])
def diario_do_carro(carro_id: UUID, db: DbSession) -> list[EvolucaoResposta]:
    if obter_carro(db, carro_id) is None:
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")
    return [
        EvolucaoResposta.model_validate(evolucao)
        for evolucao in listar_evolucoes(db, carro_id)
    ]


@router.post(
    "/{carro_id}/evolucoes",
    response_model=EvolucaoResposta,
    status_code=status.HTTP_201_CREATED,
)
def registrar_evolucao(
    carro_id: UUID,
    dados: EvolucaoCriacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> EvolucaoResposta:
    if obter_carro_do_proprietario(db, carro_id, usuario.id) is None:
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")
    return EvolucaoResposta.model_validate(
        criar_evolucao(db, carro_id, usuario, dados)
    )


@router.patch(
    "/{carro_id}/evolucoes/{evolucao_id}",
    response_model=EvolucaoResposta,
)
def atualizar_evolucao(
    carro_id: UUID,
    evolucao_id: UUID,
    dados: EvolucaoAtualizacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> EvolucaoResposta:
    evolucao = obter_evolucao_do_autor(db, evolucao_id, carro_id, usuario.id)
    if evolucao is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")

    for campo, valor in dados.model_dump(exclude_unset=True).items():
        setattr(evolucao, campo, valor)
    db.commit()
    db.refresh(evolucao)
    return EvolucaoResposta.model_validate(evolucao)


@router.post(
    "/{carro_id}/evolucoes/{evolucao_id}/fotos",
    response_model=EvolucaoResposta,
)
async def adicionar_foto(
    carro_id: UUID,
    evolucao_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
    arquivo: Annotated[UploadFile, File()],
) -> EvolucaoResposta:
    evolucao = obter_evolucao_do_autor(db, evolucao_id, carro_id, usuario.id)
    if evolucao is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")
    if len(evolucao.fotos) >= MAX_FOTOS_POR_EVOLUCAO:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cada evolucao pode ter no maximo 8 fotos.",
        )

    conteudo = await arquivo.read(settings.media_max_upload_bytes + 1)
    try:
        url = salvar_foto_evolucao(carro_id, evolucao_id, conteudo)
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

    foto = MidiaEvolucao(
        evolucao_id=evolucao.id,
        url=url,
        tipo="imagem",
        ordem=max((foto.ordem for foto in evolucao.fotos), default=-1) + 1,
    )
    db.add(foto)
    try:
        db.commit()
    except Exception:
        db.rollback()
        remover_media(url)
        raise
    db.expire(evolucao, ["fotos"])
    return EvolucaoResposta.model_validate(evolucao)


@router.delete(
    "/{carro_id}/evolucoes/{evolucao_id}/fotos/{foto_id}",
    response_model=EvolucaoResposta,
)
def excluir_foto(
    carro_id: UUID,
    evolucao_id: UUID,
    foto_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> EvolucaoResposta:
    foto = obter_foto_da_evolucao(
        db,
        foto_id,
        evolucao_id,
        carro_id,
        usuario.id,
    )
    if foto is None:
        raise HTTPException(status_code=404, detail="Foto nao encontrada.")

    evolucao = foto.evolucao
    url = foto.url
    db.delete(foto)
    db.commit()
    db.expire(evolucao, ["fotos"])
    remover_media(url)
    return EvolucaoResposta.model_validate(evolucao)


@router.delete(
    "/{carro_id}/evolucoes/{evolucao_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def excluir_evolucao(
    carro_id: UUID,
    evolucao_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> None:
    evolucao = obter_evolucao_do_autor(db, evolucao_id, carro_id, usuario.id)
    if evolucao is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")
    urls = [foto.url for foto in evolucao.fotos]
    db.delete(evolucao)
    db.commit()
    for url in urls:
        remover_media(url)
