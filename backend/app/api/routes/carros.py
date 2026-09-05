from typing import Annotated
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.config import settings
from app.core.database import get_db
from app.schemas.carro import (
    CarroAtualizacao,
    CarroCriacao,
    CarroPrivado,
    CarroPublico,
    PaginaCarros,
)
from app.services.carros import (
    CursorInvalido,
    criar_carro,
    excluir_carro,
    listar_carros_do_usuario,
    listar_feed,
    obter_carro,
    obter_carro_do_proprietario,
)
from app.services.media import (
    ArquivoMuitoGrande,
    ImagemInvalida,
    remover_media,
    salvar_foto_principal,
)


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


@router.post("", response_model=CarroPrivado, status_code=status.HTTP_201_CREATED)
def cadastrar_carro(
    dados: CarroCriacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> CarroPrivado:
    return CarroPrivado.model_validate(criar_carro(db, usuario, dados))


@router.get("", response_model=PaginaCarros)
def feed_carros(
    db: DbSession,
    limite: Annotated[int, Query(ge=1, le=50)] = 20,
    cursor: str | None = None,
) -> PaginaCarros:
    try:
        return listar_feed(db, limite=limite, cursor=cursor)
    except CursorInvalido as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.get("/meus", response_model=list[CarroPrivado])
def meus_carros(usuario: UsuarioAtual, db: DbSession) -> list[CarroPrivado]:
    return [
        CarroPrivado.model_validate(carro)
        for carro in listar_carros_do_usuario(db, usuario.id)
    ]


@router.get("/{carro_id}", response_model=CarroPublico)
def detalhe_carro(carro_id: UUID, db: DbSession) -> CarroPublico:
    carro = obter_carro(db, carro_id)
    if carro is None:
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")
    return CarroPublico.model_validate(carro)


@router.patch("/{carro_id}", response_model=CarroPrivado)
def atualizar_carro(
    carro_id: UUID,
    dados: CarroAtualizacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> CarroPrivado:
    carro = obter_carro_do_proprietario(db, carro_id, usuario.id)
    if carro is None:
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")

    for campo, valor in dados.model_dump(exclude_unset=True).items():
        setattr(carro, campo, valor)

    db.commit()
    db.refresh(carro)
    return CarroPrivado.model_validate(carro)


@router.post("/{carro_id}/foto-principal", response_model=CarroPrivado)
async def enviar_foto_principal(
    carro_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
    arquivo: Annotated[UploadFile, File()],
) -> CarroPrivado:
    carro = obter_carro_do_proprietario(db, carro_id, usuario.id)
    if carro is None:
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")

    conteudo = await arquivo.read(settings.media_max_upload_bytes + 1)
    try:
        nova_url = salvar_foto_principal(carro.id, conteudo)
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

    url_anterior = carro.foto_principal_url
    carro.foto_principal_url = nova_url
    db.commit()
    db.refresh(carro)
    remover_media(url_anterior)
    return CarroPrivado.model_validate(carro)


@router.delete(
    "/{carro_id}/foto-principal",
    response_model=CarroPrivado,
)
def remover_foto_principal(
    carro_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> CarroPrivado:
    carro = obter_carro_do_proprietario(db, carro_id, usuario.id)
    if carro is None:
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")

    url_anterior = carro.foto_principal_url
    carro.foto_principal_url = None
    db.commit()
    db.refresh(carro)
    remover_media(url_anterior)
    return CarroPrivado.model_validate(carro)


@router.delete("/{carro_id}", status_code=status.HTTP_204_NO_CONTENT)
def remover_carro(
    carro_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    carro = obter_carro_do_proprietario(db, carro_id, usuario.id)
    url_da_foto = carro.foto_principal_url if carro is not None else None
    if not excluir_carro(db, carro_id, usuario.id):
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")
    remover_media(url_da_foto)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
