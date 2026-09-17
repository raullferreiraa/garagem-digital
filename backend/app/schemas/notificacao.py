from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.usuario import UsuarioResumo


class NotificacaoResposta(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    tipo: str
    mensagem: str
    ator: UsuarioResumo | None
    carro_id: UUID | None
    evolucao_id: UUID | None
    equipe_id: UUID | None
    comentario_id: UUID | None
    lida_em: datetime | None
    criada_em: datetime


class TotalNotificacoesResposta(BaseModel):
    total: int
