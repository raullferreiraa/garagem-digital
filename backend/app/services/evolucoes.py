from uuid import UUID

from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session

from app.models.evolucao_projeto import EvolucaoProjeto
from app.models.usuario import Usuario
from app.schemas.evolucao import EvolucaoCriacao


def listar_evolucoes(db: Session, carro_id: UUID) -> list[EvolucaoProjeto]:
    return list(
        db.scalars(
            select(EvolucaoProjeto)
            .where(EvolucaoProjeto.carro_id == carro_id)
            .order_by(
                desc(func.coalesce(EvolucaoProjeto.ocorreu_em, EvolucaoProjeto.criado_em)),
                EvolucaoProjeto.id.desc(),
            )
        ).unique()
    )


def criar_evolucao(
    db: Session,
    carro_id: UUID,
    autor: Usuario,
    dados: EvolucaoCriacao,
) -> EvolucaoProjeto:
    evolucao = EvolucaoProjeto(
        carro_id=carro_id,
        autor_id=autor.id,
        **dados.model_dump(),
    )
    db.add(evolucao)
    db.commit()
    db.refresh(evolucao)
    return evolucao


def obter_evolucao_do_autor(
    db: Session,
    evolucao_id: UUID,
    carro_id: UUID,
    autor_id: UUID,
) -> EvolucaoProjeto | None:
    return db.scalar(
        select(EvolucaoProjeto).where(
            EvolucaoProjeto.id == evolucao_id,
            EvolucaoProjeto.carro_id == carro_id,
            EvolucaoProjeto.autor_id == autor_id,
        )
    )
