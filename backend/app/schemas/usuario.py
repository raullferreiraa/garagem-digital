from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)


class UsuarioResumo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    nome: str
    username: str
    avatar_url: str | None


class PerfilPublico(UsuarioResumo):
    bio: str | None
    cidade: str | None
    estado: str | None
    criado_em: datetime


class PerfilSocial(PerfilPublico):
    total_projetos: int
    total_seguidores: int
    total_seguindo: int
    seguido_por_mim: bool
    bloqueado_por_mim: bool = False


class PerfilPrivado(PerfilPublico):
    email: EmailStr


class PerfilAtualizacao(BaseModel):
    nome: Annotated[str | None, Field(min_length=2, max_length=100)] = None
    bio: Annotated[str | None, Field(max_length=280)] = None
    cidade: Annotated[str | None, Field(max_length=120)] = None
    estado: Annotated[str | None, Field(max_length=120)] = None

    @field_validator("nome")
    @classmethod
    def limpar_nome(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = " ".join(value.split())
        if len(value) < 2:
            raise ValueError("O nome deve ter pelo menos 2 caracteres.")
        return value

    @field_validator("bio", "cidade", "estado")
    @classmethod
    def limpar_campos_opcionais(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @model_validator(mode="after")
    def nome_nao_pode_ser_nulo(self) -> "PerfilAtualizacao":
        if "nome" in self.model_fields_set and self.nome is None:
            raise ValueError("O nome nao pode ser nulo.")
        return self


class DenunciaUsuarioCriacao(BaseModel):
    motivo: Literal[
        "spam",
        "assedio",
        "conteudo_improprio",
        "identidade_falsa",
        "outro",
    ]
    detalhes: Annotated[str | None, Field(max_length=500)] = None

    @field_validator("detalhes")
    @classmethod
    def limpar_detalhes(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = " ".join(value.split())
        return value or None

    @model_validator(mode="after")
    def outro_exige_detalhes(self) -> "DenunciaUsuarioCriacao":
        if self.motivo == "outro" and not self.detalhes:
            raise ValueError("Explique o motivo da denúncia.")
        return self
