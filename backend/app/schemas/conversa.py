from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.usuario import UsuarioResumo


class CriarConversaDireta(BaseModel):
    usuario_id: UUID


class EnviarMensagem(BaseModel):
    conteudo: Annotated[str, Field(min_length=1, max_length=2000)]

    @field_validator("conteudo")
    @classmethod
    def limpar_conteudo(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("A mensagem nao pode ser vazia.")
        return value


class MensagemResposta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    conversa_id: UUID
    remetente_id: UUID
    conteudo: str
    criada_em: datetime


class ConversaResumo(BaseModel):
    id: UUID
    outro_usuario: UsuarioResumo
    ultima_mensagem: MensagemResposta | None
    total_nao_lidas: int
    criada_em: datetime
    atualizada_em: datetime


class PaginaMensagens(BaseModel):
    itens: list[MensagemResposta]
    proximo_cursor: str | None


class TotalConversasNaoLidas(BaseModel):
    total: int
