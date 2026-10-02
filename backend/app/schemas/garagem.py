from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class FotoLegenda(BaseModel):
    legenda: Annotated[str, Field(max_length=160)] = ""


class FotoResposta(FotoLegenda):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    url: str
    ordem: int


class OrdemFotos(BaseModel):
    ids: Annotated[list[UUID], Field(max_length=12)]


class EtapaDados(BaseModel):
    titulo: Annotated[str, Field(min_length=1, max_length=100)]
    descricao: Annotated[str | None, Field(max_length=2000)] = None
    status: Literal["planejada", "em_andamento", "concluida"] = "planejada"
    evolucao_id: UUID | None = None

    @field_validator("titulo")
    @classmethod
    def limpar_titulo(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Informe o título da etapa.")
        return value

    @model_validator(mode="after")
    def vinculo_concluido(self):
        if self.evolucao_id is not None and self.status != "concluida":
            raise ValueError("Vincule uma evolução apenas à etapa concluída.")
        return self


class EtapaResposta(EtapaDados):
    model_config = ConfigDict(from_attributes=True)
    id: UUID


class GaragemResposta(BaseModel):
    fotos: list[FotoResposta]
    etapas: list[EtapaResposta]
