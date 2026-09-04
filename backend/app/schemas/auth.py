from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


Username = Annotated[str, Field(min_length=3, max_length=30, pattern=r"^[a-z0-9._]+$")]
Senha = Annotated[str, Field(min_length=8, max_length=128)]


class UsuarioCadastro(BaseModel):
    nome: Annotated[str, Field(min_length=2, max_length=100)]
    username: Username
    email: EmailStr
    senha: Senha

    @field_validator("nome")
    @classmethod
    def limpar_nome(cls, value: str) -> str:
        return " ".join(value.split())

    @field_validator("username")
    @classmethod
    def normalizar_username(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("email", mode="before")
    @classmethod
    def normalizar_email(cls, value: object) -> object:
        return value.strip().lower() if isinstance(value, str) else value


class CredenciaisLogin(BaseModel):
    identificador: Annotated[str, Field(min_length=3, max_length=254)]
    senha: Senha

    @field_validator("identificador")
    @classmethod
    def normalizar_identificador(cls, value: str) -> str:
        return value.strip().lower()


class RefreshTokenEntrada(BaseModel):
    refresh_token: Annotated[str, Field(min_length=40, max_length=256)]


class UsuarioPublico(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    nome: str
    username: str
    email: EmailStr
    avatar_url: str | None
    bio: str | None
    cidade: str | None
    estado: str | None
    criado_em: datetime


class TokenResposta(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    usuario: UsuarioPublico

