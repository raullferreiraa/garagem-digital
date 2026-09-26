from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.usuario import UsuarioResumo


class MensagemEquipeCriacao(BaseModel):
    conteudo: Annotated[str, Field(min_length=1, max_length=2000)]
    resposta_a_id: UUID | None = None

    @field_validator("conteudo")
    @classmethod
    def limpar(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("A mensagem nao pode ser vazia.")
        return value


class MensagemEquipeCitada(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    conteudo: str
    excluida_em: datetime | None = None
    autor: UsuarioResumo


class MensagemEquipeResposta(BaseModel):
    id: UUID
    equipe_id: UUID
    conteudo: str
    criada_em: datetime
    editada_em: datetime | None = None
    excluida_em: datetime | None = None
    autor: UsuarioResumo
    resposta_a: MensagemEquipeCitada | None = None


class PaginaMensagensEquipe(BaseModel):
    itens: list[MensagemEquipeResposta]
    proximo_cursor: str | None


class ResumoChatEquipe(BaseModel):
    equipe_id: UUID
    equipe_nome: str
    equipe_avatar_url: str | None
    total_nao_lidas: int
    ultima_mensagem: MensagemEquipeResposta | None
