from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from sqlalchemy import func, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual, UsuarioOpcional
from app.core.config import settings
from app.core.database import get_db
from app.models.carro import Carro
from app.models.bloqueio_usuario import BloqueioUsuario
from app.models.conversa import ConversaDireta
from app.models.equipe import Equipe, MembroEquipe
from app.models.denuncia_usuario import DenunciaUsuario
from app.models.notificacao import Notificacao
from app.models.seguidor import Seguidor
from app.models.usuario import Usuario
from app.schemas.carro import CarroPublico
from app.schemas.usuario import (
    PerfilAtualizacao,
    DenunciaUsuarioCriacao,
    PerfilPrivado,
    PerfilSocial,
    EquipeDoPerfil,
    UsuarioResumo,
)
from app.services.carros import listar_carros_do_usuario
from app.services.bloqueios import existe_bloqueio, ids_com_bloqueio
from app.services.media import (
    ArquivoMuitoGrande,
    ImagemInvalida,
    remover_media,
    salvar_avatar,
)
from app.services.notificacoes import criar_notificacao


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


@router.patch("/me", response_model=PerfilPrivado)
def atualizar_meu_perfil(
    dados: PerfilAtualizacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> PerfilPrivado:
    for campo, valor in dados.model_dump(exclude_unset=True).items():
        setattr(usuario, campo, valor)

    db.commit()
    db.refresh(usuario)
    return PerfilPrivado.model_validate(usuario)


@router.post("/me/avatar", response_model=PerfilPrivado)
async def enviar_avatar(
    usuario: UsuarioAtual,
    db: DbSession,
    arquivo: Annotated[UploadFile, File()],
) -> PerfilPrivado:
    conteudo = await arquivo.read(settings.media_max_upload_bytes + 1)
    try:
        nova_url = salvar_avatar(usuario.id, conteudo)
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

    url_anterior = usuario.avatar_url
    usuario.avatar_url = nova_url
    db.commit()
    db.refresh(usuario)
    remover_media(url_anterior)
    return PerfilPrivado.model_validate(usuario)


@router.delete("/me/avatar", response_model=PerfilPrivado)
def remover_avatar(
    usuario: UsuarioAtual,
    db: DbSession,
) -> PerfilPrivado:
    url_anterior = usuario.avatar_url
    usuario.avatar_url = None
    db.commit()
    db.refresh(usuario)
    remover_media(url_anterior)
    return PerfilPrivado.model_validate(usuario)


@router.get("", response_model=list[UsuarioResumo])
def buscar_usuarios(
    usuario: UsuarioAtual,
    db: DbSession,
    busca: Annotated[str, Query(min_length=2, max_length=100)],
) -> list[UsuarioResumo]:
    termo = busca.strip().removeprefix("@")
    if len(termo) < 2:
        raise HTTPException(
            status_code=422,
            detail="Digite pelo menos 2 caracteres para buscar.",
        )
    padrao = f"%{termo}%"
    usuarios = db.scalars(
        select(Usuario)
        .where(
            Usuario.ativo.is_(True),
            Usuario.id != usuario.id,
            Usuario.id.not_in(ids_com_bloqueio(db, usuario.id)),
            or_(
                Usuario.username.ilike(padrao),
                Usuario.nome.ilike(padrao),
            ),
        )
        .order_by(Usuario.username)
        .limit(20)
    ).all()
    return [UsuarioResumo.model_validate(item) for item in usuarios]


def _buscar_usuario_ativo(db: Session, usuario_id: UUID) -> Usuario:
    usuario = db.get(Usuario, usuario_id)
    if usuario is None or not usuario.ativo:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado.")
    return usuario


@router.get("/{usuario_id}", response_model=PerfilSocial)
def obter_perfil(
    usuario_id: UUID,
    usuario_atual: UsuarioOpcional,
    db: DbSession,
) -> PerfilSocial:
    usuario = _buscar_usuario_ativo(db, usuario_id)
    bloqueado_por_mim = (
        usuario_atual is not None
        and db.get(BloqueioUsuario, (usuario_atual.id, usuario_id)) is not None
    )
    if (
        usuario_atual is not None
        and db.get(BloqueioUsuario, (usuario_id, usuario_atual.id)) is not None
    ):
        raise HTTPException(status_code=404, detail="Perfil não encontrado.")
    total_projetos = db.scalar(
        select(func.count()).select_from(Carro).where(
            Carro.proprietario_id == usuario_id
        )
    )
    total_seguidores = db.scalar(
        select(func.count()).select_from(Seguidor).where(
            Seguidor.seguido_id == usuario_id
        )
    )
    total_seguindo = db.scalar(
        select(func.count()).select_from(Seguidor).where(
            Seguidor.seguidor_id == usuario_id
        )
    )
    seguido_por_mim = (
        usuario_atual is not None
        and usuario_atual.id != usuario_id
        and db.get(Seguidor, (usuario_atual.id, usuario_id)) is not None
    )
    equipe = db.scalar(
        select(Equipe)
        .join(MembroEquipe, MembroEquipe.equipe_id == Equipe.id)
        .where(MembroEquipe.usuario_id == usuario_id)
    )
    pode_ver_equipe = (
        equipe is not None
        and not bloqueado_por_mim
        and (
            equipe.visibilidade == "publica"
            or (
                usuario_atual is not None
                and db.scalar(
                    select(MembroEquipe.usuario_id).where(
                        MembroEquipe.equipe_id == equipe.id,
                        MembroEquipe.usuario_id == usuario_atual.id,
                    )
                ) is not None
            )
        )
    )

    return PerfilSocial(
        id=usuario.id,
        nome=usuario.nome,
        username=usuario.username,
        avatar_url=usuario.avatar_url,
        bio=usuario.bio,
        cidade=usuario.cidade,
        estado=usuario.estado,
        criado_em=usuario.criado_em,
        total_projetos=total_projetos or 0,
        total_seguidores=total_seguidores or 0,
        total_seguindo=total_seguindo or 0,
        seguido_por_mim=seguido_por_mim,
        bloqueado_por_mim=bloqueado_por_mim,
        equipe_atual=EquipeDoPerfil(
            id=equipe.id, nome=equipe.nome, avatar_url=equipe.avatar_url
        ) if pode_ver_equipe and equipe is not None else None,
    )


@router.put("/{usuario_id}/seguir", status_code=status.HTTP_204_NO_CONTENT)
def seguir_usuario(
    usuario_id: UUID,
    usuario_atual: UsuarioAtual,
    db: DbSession,
) -> Response:
    if usuario_id == usuario_atual.id:
        raise HTTPException(
            status_code=400,
            detail="Voce nao pode seguir a si mesmo.",
        )
    seguido = _buscar_usuario_ativo(db, usuario_id)
    if existe_bloqueio(db, usuario_atual.id, usuario_id):
        raise HTTPException(status_code=403, detail="Não é possível seguir este perfil.")

    if db.get(Seguidor, (usuario_atual.id, usuario_id)) is None:
        db.add(Seguidor(seguidor_id=usuario_atual.id, seguido_id=usuario_id))
        criar_notificacao(
            db,
            destinatario_id=seguido.id,
            ator_id=usuario_atual.id,
            tipo="novo_seguidor",
            mensagem=f"@{usuario_atual.username} começou a seguir você.",
        )
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{usuario_id}/seguir", status_code=status.HTTP_204_NO_CONTENT)
def deixar_de_seguir_usuario(
    usuario_id: UUID,
    usuario_atual: UsuarioAtual,
    db: DbSession,
) -> Response:
    _buscar_usuario_ativo(db, usuario_id)
    vinculo = db.get(Seguidor, (usuario_atual.id, usuario_id))
    if vinculo is not None:
        db.delete(vinculo)
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me/bloqueios", response_model=list[UsuarioResumo])
def listar_meus_bloqueios(usuario_atual: UsuarioAtual, db: DbSession) -> list[UsuarioResumo]:
    usuarios = db.scalars(
        select(Usuario)
        .join(BloqueioUsuario, BloqueioUsuario.bloqueado_id == Usuario.id)
        .where(BloqueioUsuario.bloqueador_id == usuario_atual.id)
        .order_by(BloqueioUsuario.criado_em.desc())
    ).all()
    return [UsuarioResumo.model_validate(item) for item in usuarios]


@router.put("/{usuario_id}/bloqueio", status_code=status.HTTP_204_NO_CONTENT)
def bloquear_usuario(
    usuario_id: UUID,
    usuario_atual: UsuarioAtual,
    db: DbSession,
) -> Response:
    if usuario_id == usuario_atual.id:
        raise HTTPException(status_code=400, detail="Você não pode bloquear seu próprio perfil.")
    _buscar_usuario_ativo(db, usuario_id)
    if db.get(BloqueioUsuario, (usuario_atual.id, usuario_id)) is None:
        db.add(BloqueioUsuario(bloqueador_id=usuario_atual.id, bloqueado_id=usuario_id))
    for par in ((usuario_atual.id, usuario_id), (usuario_id, usuario_atual.id)):
        vinculo = db.get(Seguidor, par)
        if vinculo is not None:
            db.delete(vinculo)
    agora = datetime.now(timezone.utc)
    db.execute(
        update(ConversaDireta)
        .where(
            or_(
                (ConversaDireta.usuario_a_id == usuario_atual.id)
                & (ConversaDireta.usuario_b_id == usuario_id),
                (ConversaDireta.usuario_a_id == usuario_id)
                & (ConversaDireta.usuario_b_id == usuario_atual.id),
            )
        )
        .values(usuario_a_leu_em=agora, usuario_b_leu_em=agora)
    )
    db.execute(
        update(Notificacao)
        .where(
            or_(
                (Notificacao.destinatario_id == usuario_atual.id)
                & (Notificacao.ator_id == usuario_id),
                (Notificacao.destinatario_id == usuario_id)
                & (Notificacao.ator_id == usuario_atual.id),
            ),
            Notificacao.lida_em.is_(None),
        )
        .values(lida_em=agora)
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        # Uma requisição simultânea pode ter criado o mesmo bloqueio.
        if db.get(BloqueioUsuario, (usuario_atual.id, usuario_id)) is None:
            raise
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{usuario_id}/bloqueio", status_code=status.HTTP_204_NO_CONTENT)
def desbloquear_usuario(
    usuario_id: UUID,
    usuario_atual: UsuarioAtual,
    db: DbSession,
) -> Response:
    vinculo = db.get(BloqueioUsuario, (usuario_atual.id, usuario_id))
    if vinculo is not None:
        db.delete(vinculo)
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{usuario_id}/denuncias", status_code=status.HTTP_204_NO_CONTENT)
def denunciar_usuario(
    usuario_id: UUID,
    dados: DenunciaUsuarioCriacao,
    usuario_atual: UsuarioAtual,
    db: DbSession,
) -> Response:
    if usuario_id == usuario_atual.id:
        raise HTTPException(
            status_code=400,
            detail="Você não pode denunciar seu próprio perfil.",
        )
    _buscar_usuario_ativo(db, usuario_id)
    existente = db.scalar(
        select(DenunciaUsuario.id).where(
            DenunciaUsuario.denunciante_id == usuario_atual.id,
            DenunciaUsuario.denunciado_id == usuario_id,
        )
    )
    if existente is not None:
        raise HTTPException(
            status_code=409,
            detail="Você já denunciou este perfil. A denúncia está em análise.",
        )
    db.add(
        DenunciaUsuario(
            denunciante_id=usuario_atual.id,
            denunciado_id=usuario_id,
            motivo=dados.motivo,
            detalhes=dados.detalhes,
        )
    )
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Você já denunciou este perfil. A denúncia está em análise.",
        ) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{usuario_id}/seguidores", response_model=list[UsuarioResumo])
def listar_seguidores(
    usuario_id: UUID,
    db: DbSession,
    usuario_atual: UsuarioOpcional,
) -> list[UsuarioResumo]:
    _buscar_usuario_ativo(db, usuario_id)
    if usuario_atual is not None and existe_bloqueio(db, usuario_atual.id, usuario_id):
        return []
    usuarios = db.scalars(
        select(Usuario)
        .join(Seguidor, Seguidor.seguidor_id == Usuario.id)
        .where(
            Seguidor.seguido_id == usuario_id,
            Usuario.ativo.is_(True),
            *(
                [Usuario.id.not_in(ids_com_bloqueio(db, usuario_atual.id))]
                if usuario_atual is not None
                else []
            ),
        )
        .order_by(Seguidor.criado_em.desc())
    ).all()
    return [UsuarioResumo.model_validate(usuario) for usuario in usuarios]


@router.get("/{usuario_id}/seguindo", response_model=list[UsuarioResumo])
def listar_seguidos(
    usuario_id: UUID,
    db: DbSession,
    usuario_atual: UsuarioOpcional,
) -> list[UsuarioResumo]:
    _buscar_usuario_ativo(db, usuario_id)
    if usuario_atual is not None and existe_bloqueio(db, usuario_atual.id, usuario_id):
        return []
    usuarios = db.scalars(
        select(Usuario)
        .join(Seguidor, Seguidor.seguido_id == Usuario.id)
        .where(
            Seguidor.seguidor_id == usuario_id,
            Usuario.ativo.is_(True),
            *(
                [Usuario.id.not_in(ids_com_bloqueio(db, usuario_atual.id))]
                if usuario_atual is not None
                else []
            ),
        )
        .order_by(Seguidor.criado_em.desc())
    ).all()
    return [UsuarioResumo.model_validate(usuario) for usuario in usuarios]


@router.get("/{usuario_id}/carros", response_model=list[CarroPublico])
def obter_garagem_publica(
    usuario_id: UUID, db: DbSession, usuario_atual: UsuarioOpcional
) -> list[CarroPublico]:
    if usuario_atual is not None and existe_bloqueio(db, usuario_atual.id, usuario_id):
        return []
    usuario_existe = db.scalar(
        select(Usuario.id).where(Usuario.id == usuario_id, Usuario.ativo.is_(True))
    )
    if usuario_existe is None:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado.")

    return [
        CarroPublico.model_validate(carro)
        for carro in listar_carros_do_usuario(db, usuario_id)
    ]
