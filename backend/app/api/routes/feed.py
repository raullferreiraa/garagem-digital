from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.models.carro import Carro
from app.models.evolucao_projeto import EvolucaoProjeto
from app.models.seguidor import Seguidor
from app.schemas.carro import CarroPublico
from app.schemas.evolucao import EvolucaoResposta
from app.schemas.feed import ItemFeedSeguindo


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


@router.get("/seguindo", response_model=list[ItemFeedSeguindo])
def feed_seguindo(
    usuario: UsuarioAtual,
    db: DbSession,
    limite: Annotated[int, Query(ge=1, le=50)] = 20,
) -> list[ItemFeedSeguindo]:
    seguidos = select(Seguidor.seguido_id).where(
        Seguidor.seguidor_id == usuario.id
    )
    evolucoes = list(
        db.scalars(
            select(EvolucaoProjeto)
            .join(Carro, Carro.id == EvolucaoProjeto.carro_id)
            .where(Carro.proprietario_id.in_(seguidos))
            .order_by(
                desc(
                    func.coalesce(
                        EvolucaoProjeto.ocorreu_em,
                        EvolucaoProjeto.criado_em,
                    )
                ),
                EvolucaoProjeto.id.desc(),
            )
            .limit(limite)
        ).unique()
    )
    return [
        ItemFeedSeguindo(
            evolucao=EvolucaoResposta.model_validate(evolucao),
            carro=CarroPublico.model_validate(evolucao.carro),
        )
        for evolucao in evolucoes
    ]
