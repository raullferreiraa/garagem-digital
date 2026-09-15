from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.config import settings
from app.core.database import get_db
from app.models.comentario_evolucao import ComentarioEvolucao
from app.models.curtida_comentario_evolucao import CurtidaComentarioEvolucao
from app.models.curtida_evolucao import CurtidaEvolucao
from app.models.midia_evolucao import MidiaEvolucao
from app.schemas.evolucao import (
    EvolucaoAtualizacao,
    EvolucaoCriacao,
    EvolucaoResposta,
    ComentarioEvolucaoCriacao,
    ComentarioEvolucaoResposta,
    InteracoesEvolucaoResposta,
)
from app.services.carros import obter_carro, obter_carro_do_proprietario
from app.services.evolucoes import (
    criar_evolucao,
    listar_evolucoes,
    obter_evolucao,
    obter_evolucao_do_autor,
    obter_foto_da_evolucao,
)
from app.services.media import (
    ArquivoMuitoGrande,
    ImagemInvalida,
    remover_media,
    salvar_foto_evolucao,
)


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]
MAX_FOTOS_POR_EVOLUCAO = 8


def _obter_comentario(
    db: Session,
    evolucao_id: UUID,
    comentario_id: UUID,
) -> ComentarioEvolucao | None:
    return db.scalar(
        select(ComentarioEvolucao).where(
            ComentarioEvolucao.id == comentario_id,
            ComentarioEvolucao.evolucao_id == evolucao_id,
        )
    )


def _comentario_resposta(
    comentario: ComentarioEvolucao,
    *,
    total_curtidas: int = 0,
    curtido_por_mim: bool = False,
    respostas: list[ComentarioEvolucaoResposta] | None = None,
) -> ComentarioEvolucaoResposta:
    return ComentarioEvolucaoResposta(
        id=comentario.id,
        evolucao_id=comentario.evolucao_id,
        autor=comentario.autor,
        comentario_pai_id=comentario.comentario_pai_id,
        conteudo=comentario.conteudo,
        total_curtidas=total_curtidas,
        curtido_por_mim=curtido_por_mim,
        respostas=respostas or [],
        criado_em=comentario.criado_em,
    )


def _listar_comentarios_resposta(
    db: Session,
    evolucao_id: UUID,
    usuario_id: UUID,
) -> list[ComentarioEvolucaoResposta]:
    comentarios = list(
        db.scalars(
            select(ComentarioEvolucao)
            .where(ComentarioEvolucao.evolucao_id == evolucao_id)
            .order_by(
                ComentarioEvolucao.criado_em,
                ComentarioEvolucao.id,
            )
        ).unique()
    )
    if not comentarios:
        return []

    ids = [comentario.id for comentario in comentarios]
    totais = dict(
        db.execute(
            select(
                CurtidaComentarioEvolucao.comentario_id,
                func.count(),
            )
            .where(CurtidaComentarioEvolucao.comentario_id.in_(ids))
            .group_by(CurtidaComentarioEvolucao.comentario_id)
        ).all()
    )
    curtidos = set(
        db.scalars(
            select(CurtidaComentarioEvolucao.comentario_id).where(
                CurtidaComentarioEvolucao.comentario_id.in_(ids),
                CurtidaComentarioEvolucao.usuario_id == usuario_id,
            )
        )
    )
    respostas_por_pai: dict[UUID, list[ComentarioEvolucaoResposta]] = {}
    for comentario in comentarios:
        if comentario.comentario_pai_id is None:
            continue
        respostas_por_pai.setdefault(comentario.comentario_pai_id, []).append(
            _comentario_resposta(
                comentario,
                total_curtidas=totais.get(comentario.id, 0),
                curtido_por_mim=comentario.id in curtidos,
            )
        )

    return [
        _comentario_resposta(
            comentario,
            total_curtidas=totais.get(comentario.id, 0),
            curtido_por_mim=comentario.id in curtidos,
            respostas=respostas_por_pai.get(comentario.id, []),
        )
        for comentario in comentarios
        if comentario.comentario_pai_id is None
    ]



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


@router.post(
    "/{carro_id}/evolucoes/{evolucao_id}/fotos",
    response_model=EvolucaoResposta,
)
async def adicionar_foto(
    carro_id: UUID,
    evolucao_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
    arquivo: Annotated[UploadFile, File()],
) -> EvolucaoResposta:
    evolucao = obter_evolucao_do_autor(db, evolucao_id, carro_id, usuario.id)
    if evolucao is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")
    if len(evolucao.fotos) >= MAX_FOTOS_POR_EVOLUCAO:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cada evolucao pode ter no maximo 8 fotos.",
        )

    conteudo = await arquivo.read(settings.media_max_upload_bytes + 1)
    try:
        url = salvar_foto_evolucao(carro_id, evolucao_id, conteudo)
    except ArquivoMuitoGrande as error:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="A foto deve ter no maximo 10 MB.",
        ) from error
    except ImagemInvalida as error:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Envie uma imagem JPEG, PNG ou WebP valida.",
        ) from error

    foto = MidiaEvolucao(
        evolucao_id=evolucao.id,
        url=url,
        tipo="imagem",
        ordem=max((foto.ordem for foto in evolucao.fotos), default=-1) + 1,
    )
    db.add(foto)
    try:
        db.commit()
    except Exception:
        db.rollback()
        remover_media(url)
        raise
    db.expire(evolucao, ["fotos"])
    return EvolucaoResposta.model_validate(evolucao)


@router.delete(
    "/{carro_id}/evolucoes/{evolucao_id}/fotos/{foto_id}",
    response_model=EvolucaoResposta,
)
def excluir_foto(
    carro_id: UUID,
    evolucao_id: UUID,
    foto_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> EvolucaoResposta:
    foto = obter_foto_da_evolucao(
        db,
        foto_id,
        evolucao_id,
        carro_id,
        usuario.id,
    )
    if foto is None:
        raise HTTPException(status_code=404, detail="Foto nao encontrada.")

    evolucao = foto.evolucao
    url = foto.url
    db.delete(foto)
    db.commit()
    db.expire(evolucao, ["fotos"])
    remover_media(url)
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
) -> None:
    evolucao = obter_evolucao_do_autor(db, evolucao_id, carro_id, usuario.id)
    if evolucao is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")
    urls = [foto.url for foto in evolucao.fotos]
    db.delete(evolucao)
    db.commit()
    for url in urls:
        remover_media(url)



@router.get(
    "/{carro_id}/evolucoes/{evolucao_id}/interacoes",
    response_model=InteracoesEvolucaoResposta,
)
def obter_interacoes(
    carro_id: UUID,
    evolucao_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> InteracoesEvolucaoResposta:
    if obter_evolucao(db, evolucao_id, carro_id) is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")

    total_curtidas = db.scalar(
        select(func.count()).select_from(CurtidaEvolucao).where(
            CurtidaEvolucao.evolucao_id == evolucao_id
        )
    ) or 0
    curtido_por_mim = db.get(
        CurtidaEvolucao,
        (evolucao_id, usuario.id),
    ) is not None
    return InteracoesEvolucaoResposta(
        total_curtidas=total_curtidas,
        curtido_por_mim=curtido_por_mim,
        comentarios=_listar_comentarios_resposta(
            db,
            evolucao_id,
            usuario.id,
        ),
    )


@router.put(
    "/{carro_id}/evolucoes/{evolucao_id}/curtida",
    status_code=status.HTTP_204_NO_CONTENT,
)
def curtir_evolucao(
    carro_id: UUID,
    evolucao_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> None:
    if obter_evolucao(db, evolucao_id, carro_id) is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")

    chave = (evolucao_id, usuario.id)
    if db.get(CurtidaEvolucao, chave) is None:
        db.add(
            CurtidaEvolucao(
                evolucao_id=evolucao_id,
                usuario_id=usuario.id,
            )
        )
        db.commit()


@router.delete(
    "/{carro_id}/evolucoes/{evolucao_id}/curtida",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remover_curtida(
    carro_id: UUID,
    evolucao_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> None:
    if obter_evolucao(db, evolucao_id, carro_id) is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")

    curtida = db.get(CurtidaEvolucao, (evolucao_id, usuario.id))
    if curtida is not None:
        db.delete(curtida)
        db.commit()


@router.post(
    "/{carro_id}/evolucoes/{evolucao_id}/comentarios",
    response_model=ComentarioEvolucaoResposta,
    status_code=status.HTTP_201_CREATED,
)
def comentar_evolucao(
    carro_id: UUID,
    evolucao_id: UUID,
    dados: ComentarioEvolucaoCriacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> ComentarioEvolucaoResposta:
    if obter_evolucao(db, evolucao_id, carro_id) is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")

    comentario = ComentarioEvolucao(
        evolucao_id=evolucao_id,
        autor_id=usuario.id,
        conteudo=dados.conteudo,
    )
    db.add(comentario)
    db.commit()
    db.refresh(comentario)
    return _comentario_resposta(comentario)


@router.post(
    "/{carro_id}/evolucoes/{evolucao_id}/comentarios/{comentario_id}/respostas",
    response_model=ComentarioEvolucaoResposta,
    status_code=status.HTTP_201_CREATED,
)
def responder_comentario(
    carro_id: UUID,
    evolucao_id: UUID,
    comentario_id: UUID,
    dados: ComentarioEvolucaoCriacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> ComentarioEvolucaoResposta:
    if obter_evolucao(db, evolucao_id, carro_id) is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")

    comentario_pai = _obter_comentario(db, evolucao_id, comentario_id)
    if comentario_pai is None:
        raise HTTPException(status_code=404, detail="Comentario nao encontrado.")
    if comentario_pai.comentario_pai_id is not None:
        raise HTTPException(
            status_code=422,
            detail="Respostas podem ter apenas um nivel.",
        )

    resposta = ComentarioEvolucao(
        evolucao_id=evolucao_id,
        autor_id=usuario.id,
        comentario_pai_id=comentario_pai.id,
        conteudo=dados.conteudo,
    )
    db.add(resposta)
    db.commit()
    db.refresh(resposta)
    return _comentario_resposta(resposta)


@router.put(
    "/{carro_id}/evolucoes/{evolucao_id}/comentarios/{comentario_id}/curtida",
    status_code=status.HTTP_204_NO_CONTENT,
)
def curtir_comentario(
    carro_id: UUID,
    evolucao_id: UUID,
    comentario_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> None:
    if obter_evolucao(db, evolucao_id, carro_id) is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")
    if _obter_comentario(db, evolucao_id, comentario_id) is None:
        raise HTTPException(status_code=404, detail="Comentario nao encontrado.")

    chave = (comentario_id, usuario.id)
    if db.get(CurtidaComentarioEvolucao, chave) is None:
        db.add(
            CurtidaComentarioEvolucao(
                comentario_id=comentario_id,
                usuario_id=usuario.id,
            )
        )
        db.commit()


@router.delete(
    "/{carro_id}/evolucoes/{evolucao_id}/comentarios/{comentario_id}/curtida",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remover_curtida_comentario(
    carro_id: UUID,
    evolucao_id: UUID,
    comentario_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> None:
    if obter_evolucao(db, evolucao_id, carro_id) is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")
    if _obter_comentario(db, evolucao_id, comentario_id) is None:
        raise HTTPException(status_code=404, detail="Comentario nao encontrado.")

    curtida = db.get(CurtidaComentarioEvolucao, (comentario_id, usuario.id))
    if curtida is not None:
        db.delete(curtida)
        db.commit()


@router.delete(
    "/{carro_id}/evolucoes/{evolucao_id}/comentarios/{comentario_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def excluir_comentario(
    carro_id: UUID,
    evolucao_id: UUID,
    comentario_id: UUID,
    usuario: UsuarioAtual,
    db: DbSession,
) -> None:
    if obter_evolucao(db, evolucao_id, carro_id) is None:
        raise HTTPException(status_code=404, detail="Evolucao nao encontrada.")

    comentario = db.scalar(
        select(ComentarioEvolucao).where(
            ComentarioEvolucao.id == comentario_id,
            ComentarioEvolucao.evolucao_id == evolucao_id,
            ComentarioEvolucao.autor_id == usuario.id,
        )
    )
    if comentario is None:
        raise HTTPException(status_code=404, detail="Comentario nao encontrado.")
    db.delete(comentario)
    db.commit()
