from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.carro import CarroPublico
from app.schemas.usuario import UsuarioResumo


class EquipeCriacao(BaseModel):
    nome: Annotated[str, Field(min_length=2, max_length=100)]
    descricao: Annotated[str | None, Field(max_length=500)] = None
    cidade: Annotated[str | None, Field(max_length=120)] = None
    estado: Annotated[str | None, Field(max_length=120)] = None
    visibilidade: Literal["publica", "privada"] = "publica"

    @field_validator("nome")
    @classmethod
    def limpar_nome(cls, value: str) -> str:
        value = " ".join(value.split())
        if len(value) < 2:
            raise ValueError("O nome deve ter pelo menos 2 caracteres.")
        return value

    @field_validator("descricao", "cidade", "estado")
    @classmethod
    def limpar_opcionais(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None


class EquipeResumo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    nome: str
    slug: str
    descricao: str | None
    cidade: str | None
    estado: str | None
    visibilidade: str
    total_membros: int
    meu_papel: str | None
    minha_solicitacao: str | None


class MembroEquipeResposta(BaseModel):
    usuario: UsuarioResumo
    papel: str
    entrou_em: datetime


class SolicitacaoEquipeResposta(BaseModel):
    id: UUID
    usuario: UsuarioResumo
    status: str
    criada_em: datetime


class EquipeDetalhe(EquipeResumo):
    dono_id: UUID
    membros: list[MembroEquipeResposta]
    carros: list[CarroPublico]
    solicitacoes_pendentes: list[SolicitacaoEquipeResposta]


class SolicitacaoDecisao(BaseModel):
    decisao: Literal["aprovar", "recusar"]


class EscolhaCarro(BaseModel):
    carro_id: UUID
