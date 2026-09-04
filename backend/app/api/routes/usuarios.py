from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.models.usuario import Usuario
from app.schemas.carro import CarroPublico
from app.schemas.usuario import PerfilAtualizacao, PerfilPrivado, PerfilPublico
from app.services.carros import listar_carros_do_usuario


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


@router.patch("/me", response_model=PerfilPrivado)
def atualizar_meu_perfil(
    dados: PerfilAtualizacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> PerfilPrivado:
    for campo, valor in dados.model_dump(exclude_unset=True).items():
        setattr(usuario, campo, valor)

    db.commit()
    db.refresh(usuario)
    return PerfilPrivado.model_validate(usuario)


@router.get("/{usuario_id}", response_model=PerfilPublico)
def obter_perfil(usuario_id: UUID, db: DbSession) -> PerfilPublico:
    usuario = db.get(Usuario, usuario_id)
    if usuario is None or not usuario.ativo:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado.")
    return PerfilPublico.model_validate(usuario)


@router.get("/{usuario_id}/carros", response_model=list[CarroPublico])
def obter_garagem_publica(usuario_id: UUID, db: DbSession) -> list[CarroPublico]:
    usuario_existe = db.scalar(
        select(Usuario.id).where(Usuario.id == usuario_id, Usuario.ativo.is_(True))
    )
    if usuario_existe is None:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado.")

    return [
        CarroPublico.model_validate(carro)
        for carro in listar_carros_do_usuario(db, usuario_id)
    ]
