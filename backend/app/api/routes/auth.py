from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.schemas.auth import (
    CredenciaisLogin,
    RefreshTokenEntrada,
    TokenResposta,
    UsuarioCadastro,
)
from app.schemas.usuario import PerfilPrivado
from app.services.auth import (
    CredenciaisInvalidas,
    IdentificadorEmUso,
    RefreshTokenInvalido,
    autenticar_usuario,
    cadastrar_usuario,
    emitir_tokens,
    revogar_refresh_token,
    rotacionar_refresh_token,
)


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


@router.post(
    "/cadastro",
    response_model=TokenResposta,
    status_code=status.HTTP_201_CREATED,
)
def cadastro(dados: UsuarioCadastro, db: DbSession) -> TokenResposta:
    try:
        usuario = cadastrar_usuario(db, dados)
        return emitir_tokens(db, usuario)
    except IdentificadorEmUso as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Email ou username ja esta em uso.",
        ) from error


@router.post("/login", response_model=TokenResposta)
def login(dados: CredenciaisLogin, db: DbSession) -> TokenResposta:
    try:
        usuario = autenticar_usuario(db, dados)
    except CredenciaisInvalidas as error:
        raise HTTPException(status_code=401, detail=str(error)) from error

    return emitir_tokens(db, usuario)


@router.post("/refresh", response_model=TokenResposta)
def refresh(dados: RefreshTokenEntrada, db: DbSession) -> TokenResposta:
    try:
        return rotacionar_refresh_token(db, dados.refresh_token)
    except RefreshTokenInvalido as error:
        raise HTTPException(status_code=401, detail=str(error)) from error


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(dados: RefreshTokenEntrada, db: DbSession) -> Response:
    revogar_refresh_token(db, dados.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=PerfilPrivado)
def me(usuario: UsuarioAtual) -> PerfilPrivado:
    return PerfilPrivado.model_validate(usuario)
