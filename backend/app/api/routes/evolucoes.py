from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.schemas.evolucao import (
    EvolucaoAtualizacao,
    EvolucaoCriacao,
    EvolucaoResposta,
)
from app.services.carros import obter_carro, obter_carro_do_proprietario
from app.services.evolucoes import (
    criar_evolucao,
    listar_evolucoes,
    obter_evolucao_do_autor,
)


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


@router.get("/{carro_id}/evolucoes", response_model=list[EvolucaoResposta])
def diario_do_carro(carro_id: UUID, db: DbSession) -> list[EvolucaoResposta]:
    if obter_carro(db, carro_id) is None:
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")
    return [
        EvolucaoResposta.model_validate(evolucao)
        for evolucao in listar_evolucoes(db, carro_id)
    ]


@router.post(
    "/{carro_id}/evolucoes",
    response_model=EvolucaoResposta,
    status_code=status.HTTP_201_CREATED,
)
def registrar_evolucao(
    carro_id: UUID,
    dados: EvolucaoCriacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> EvolucaoResposta:
    if obter_carro_do_proprietario(db, carro_id, usuario.id) is None:
        raise HTTPException(status_code=404, detail="Carro nao encontrado.")
    return EvolucaoResposta.model_validate(
        criar_evolucao(db, carro_id, usuario, dados)
    )


@router.patch(
    "/{carro_id}/evolucoes/{evolucao_id}",
    response_model=EvolucaoResposta,
)
def atualizar_evolucao(
    carro_id: UUID,
    evolucao_id: UUID,
    dados: EvolucaoAtualizacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> EvolucaoResposta:
    evolucao = obter_evolucao_do_autor(db, evolucao_id, carro_id, usuario.id)
    if evolucao is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")

    for campo, valor in dados.model_dump(exclude_unset=True).items():
        setattr(evolucao, campo, valor)
    db.commit()
    db.refresh(evolucao)
    return EvolucaoResposta.model_validate(evolucao)


@router.delete(
    "/{carro_id}/evolucoes/{evolucao_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def excluir_evolucao(
    carro_id: UUID,
    evolucao_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> Response:
    evolucao = obter_evolucao_do_autor(db, evolucao_id, carro_id, usuario.id)
    if evolucao is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")
    db.delete(evolucao)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
