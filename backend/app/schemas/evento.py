from datetime import datetime, timezone
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

from app.schemas.usuario import UsuarioResumo


class EdicaoCriacao(BaseModel):
    inicio: datetime
    termino: datetime | None = None
    endereco_publico: Annotated[str | None, Field(max_length=300)] = None
    usar_regiao_comunidade: bool = True
    cidade: Annotated[str | None, Field(max_length=120)] = None
    estado: Annotated[str | None, Field(max_length=120)] = None

    @field_validator("endereco_publico", "cidade", "estado")
    @classmethod
    def limpar_texto(cls, value: str | None) -> str | None:
        return " ".join(value.split()) or None if value is not None else None

    @field_validator("inicio", "termino")
    @classmethod
    def normalizar_data(cls, value: datetime | None) -> datetime | None:
        if value is None:
            return None
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)

    @model_validator(mode="after")
    def validar_periodo(self) -> "EdicaoCriacao":
        inicio = self.inicio if self.inicio.tzinfo else self.inicio.replace(tzinfo=timezone.utc)
        if inicio <= datetime.now(timezone.utc):
            raise ValueError("A edição precisa começar no futuro.")
        if self.termino is not None and self.termino < self.inicio:
            raise ValueError("O término não pode ser anterior ao início.")
        if not self.usar_regiao_comunidade and not (self.cidade and self.estado):
            raise ValueError("Informe a cidade e o estado desta edição.")
        return self


class EncontroCriacao(BaseModel):
    nome: Annotated[str, Field(min_length=3, max_length=140)]
    descricao: Annotated[str | None, Field(max_length=2000)] = None
    cidade: Annotated[str | None, Field(max_length=120)] = None
    estado: Annotated[str | None, Field(max_length=120)] = None
    organizador: Literal["usuario", "equipe"] = "usuario"
    visibilidade: Literal["publico", "somente_equipe"] = "publico"
    proxima_edicao: EdicaoCriacao | None = None

    @field_validator("nome", "descricao", "cidade", "estado", mode="before")
    @classmethod
    def limpar_texto(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return " ".join(value.split()) or None

    @model_validator(mode="after")
    def validar_visibilidade(self) -> "EncontroCriacao":
        if self.visibilidade == "somente_equipe" and self.organizador != "equipe":
            raise ValueError("Comunidades restritas precisam ser organizadas pela equipe.")
        return self


class PresencaEventoEntrada(BaseModel):
    status: Literal["interessado", "confirmada"] = "confirmada"
    carro_id: UUID | None = None


class ParticipacaoEquipeEntrada(BaseModel):
    status: Literal["interessada", "confirmada"] = "confirmada"
    confirmar_integrantes: bool = False


class EncontroResposta(BaseModel):
    id: UUID
    edicao_id: UUID | None
    nome: str
    descricao: str | None
    inicio: datetime | None
    termino: datetime | None
    endereco_publico: str | None
    cidade: str | None
    estado: str | None
    edicao_cidade: str | None
    edicao_estado: str | None
    visibilidade: str
    organizador_tipo: Literal["usuario", "equipe"]
    organizador_nome: str
    organizador_id: UUID
    total_seguidores: int
    seguindo: bool
    total_confirmados: int
    total_equipes: int
    minha_presenca: str | None
    minha_equipe_id: UUID | None
    minha_equipe_nome: str | None
    minha_equipe_total_integrantes: int = 0
    minha_equipe_papel: str | None
    minha_equipe_participacao: str | None
    posso_gerenciar: bool
    capa_url: str | None = None
    edicoes: list["EdicaoResposta"] = Field(default_factory=list)


class EdicaoResposta(BaseModel):
    id: UUID
    inicio: datetime
    termino: datetime | None
    endereco_publico: str | None
    cidade: str | None
    estado: str | None
    status: Literal["agendada", "cancelada"]
    total_confirmados: int
    total_equipes: int


class ProjetoConfirmadoResposta(BaseModel):
    id: UUID
    modelo: str
    ano: int | None
    foto_principal_url: str | None


class ParticipanteEdicaoResposta(BaseModel):
    usuario: UsuarioResumo
    carro: ProjetoConfirmadoResposta | None


class EquipeEdicaoResposta(BaseModel):
    id: UUID
    nome: str
    avatar_url: str | None


class ParticipantesEdicaoResposta(BaseModel):
    pessoas: list[ParticipanteEdicaoResposta]
    equipes: list[EquipeEdicaoResposta]
    total_pessoas: int
    total_equipes: int


class EncontroAtualizacao(BaseModel):
    nome: Annotated[str, Field(min_length=3, max_length=140)]
    descricao: Annotated[str | None, Field(max_length=2000)] = None
    cidade: Annotated[str | None, Field(max_length=120)] = None
    estado: Annotated[str | None, Field(max_length=120)] = None

    @field_validator("nome", "descricao", "cidade", "estado", mode="before")
    @classmethod
    def limpar_texto(cls, value: str | None) -> str | None:
        return " ".join(value.split()) or None if value is not None else None


EncontroResposta.model_rebuild()


EventoCriacao = EncontroCriacao
EventoResposta = EncontroResposta
