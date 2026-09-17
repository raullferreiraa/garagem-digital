from pydantic import BaseModel

from app.schemas.carro import CarroPublico
from app.schemas.evolucao import EvolucaoResposta


class ItemFeedSeguindo(BaseModel):
    evolucao: EvolucaoResposta
    carro: CarroPublico
