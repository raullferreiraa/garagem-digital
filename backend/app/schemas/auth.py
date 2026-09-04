from typing import Annotated

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.usuario import PerfilPrivado


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


class TokenResposta(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    usuario: PerfilPrivado
