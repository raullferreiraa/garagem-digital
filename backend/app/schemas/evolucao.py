from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.usuario import UsuarioResumo


CategoriaEvolucao = Literal[
    "mecanica",
    "estetica",
    "manutencao",
    "evento",
    "historia",
    "outra",
]


class EvolucaoBase(BaseModel):
    titulo: Annotated[str, Field(min_length=1, max_length=120)]
    descricao: Annotated[str, Field(min_length=1, max_length=10000)]
    categoria: CategoriaEvolucao | None = None
    ocorreu_em: datetime | None = None
    quilometragem_km: Annotated[int | None, Field(ge=0)] = None

    @field_validator("titulo")
    @classmethod
    def limpar_titulo(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("O titulo nao pode ser vazio.")
        return value

    @field_validator("descricao")
    @classmethod
    def limpar_descricao(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("A descricao nao pode ser vazia.")
        return value


class EvolucaoCriacao(EvolucaoBase):
    pass


class EvolucaoAtualizacao(BaseModel):
    titulo: Annotated[str | None, Field(min_length=1, max_length=120)] = None
    descricao: Annotated[str | None, Field(min_length=1, max_length=10000)] = None
    categoria: CategoriaEvolucao | None = None
    ocorreu_em: datetime | None = None
    quilometragem_km: Annotated[int | None, Field(ge=0)] = None

    @field_validator("titulo")
    @classmethod
    def limpar_titulo(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = " ".join(value.split())
        if not value:
            raise ValueError("O titulo nao pode ser vazio.")
        return value

    @field_validator("descricao")
    @classmethod
    def limpar_descricao(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("A descricao nao pode ser vazia.")
        return value

    @model_validator(mode="after")
    def campos_obrigatorios_nao_podem_ser_nulos(self) -> "EvolucaoAtualizacao":
        for campo in ("titulo", "descricao"):
            if campo in self.model_fields_set and getattr(self, campo) is None:
                raise ValueError(f"O campo {campo} nao pode ser nulo.")
        return self


class EvolucaoResposta(EvolucaoBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    carro_id: UUID
    autor: UsuarioResumo
    criado_em: datetime
    atualizado_em: datetime
