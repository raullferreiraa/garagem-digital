from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual
from app.core.database import get_db
from app.schemas.evento import (
    EdicaoCriacao,
    EncontroAtualizacao,
    EventoCriacao,
    EventoResposta,
    ParticipacaoEquipeEntrada,
    PresencaEventoEntrada,
)
from app.services import eventos as service


router = APIRouter()
DbSession = Annotated[Session, Depends(get_db)]


def _erro(error: ValueError) -> HTTPException:
    codigo = 404 if isinstance(error, service.EventoNaoEncontrado) else 403
    return HTTPException(status_code=codigo, detail=str(error))


@router.get("", response_model=list[EventoResposta])
def listar_eventos(usuario: UsuarioAtual, db: DbSession) -> list[EventoResposta]:
    return service.listar(db, usuario.id)


@router.post("", response_model=EventoResposta, status_code=status.HTTP_201_CREATED)
def criar_evento(
    dados: EventoCriacao, usuario: UsuarioAtual, db: DbSession
) -> EventoResposta:
    try:
        return service.criar(db, usuario, dados)
    except service.AcaoEventoNaoPermitida as error:
        raise _erro(error) from error


@router.get("/{evento_id}", response_model=EventoResposta)
def detalhar_evento(
    evento_id: UUID, usuario: UsuarioAtual, db: DbSession
) -> EventoResposta:
    try:
        return service.detalhar(db, evento_id, usuario.id)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.post("/{evento_id}/edicoes", response_model=EventoResposta, status_code=status.HTTP_201_CREATED)
def criar_edicao(
    evento_id: UUID, dados: EdicaoCriacao, usuario: UsuarioAtual, db: DbSession
) -> EventoResposta:
    try:
        return service.criar_edicao(db, evento_id, usuario.id, dados)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.patch("/{evento_id}/edicoes/{edicao_id}", response_model=EventoResposta)
def editar_edicao(
    evento_id: UUID,
    edicao_id: UUID,
    dados: EdicaoCriacao,
    usuario: UsuarioAtual,
    db: DbSession,
) -> EventoResposta:
    try:
        return service.atualizar_edicao(db, evento_id, edicao_id, usuario.id, dados)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.post("/{evento_id}/edicoes/{edicao_id}/cancelamento", response_model=EventoResposta)
def cancelar_edicao(
    evento_id: UUID, edicao_id: UUID, usuario: UsuarioAtual, db: DbSession
) -> EventoResposta:
    try:
        return service.cancelar_edicao(db, evento_id, edicao_id, usuario.id)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.put("/{evento_id}/seguindo", response_model=EventoResposta)
def seguir_encontro(evento_id: UUID, usuario: UsuarioAtual, db: DbSession) -> EventoResposta:
    try:
        return service.seguir(db, evento_id, usuario.id, True)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.delete("/{evento_id}/seguindo", response_model=EventoResposta)
def deixar_de_seguir(evento_id: UUID, usuario: UsuarioAtual, db: DbSession) -> EventoResposta:
    try:
        return service.seguir(db, evento_id, usuario.id, False)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.put("/{evento_id}/minha-presenca", response_model=EventoResposta)
def confirmar_presenca(
    evento_id: UUID,
    dados: PresencaEventoEntrada,
    usuario: UsuarioAtual,
    db: DbSession,
    edicao_id: UUID | None = None,
) -> EventoResposta:
    try:
        return service.registrar_presenca(
            db, evento_id, usuario.id, dados.status, dados.carro_id, edicao_id
        )
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.delete("/{evento_id}/minha-presenca", response_model=EventoResposta)
def cancelar_presenca(
    evento_id: UUID, usuario: UsuarioAtual, db: DbSession, edicao_id: UUID | None = None
) -> EventoResposta:
    try:
        return service.remover_presenca(db, evento_id, usuario.id, edicao_id)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.put("/{evento_id}/minha-equipe", response_model=EventoResposta)
def confirmar_equipe(
    evento_id: UUID,
    dados: ParticipacaoEquipeEntrada,
    usuario: UsuarioAtual,
    db: DbSession,
    edicao_id: UUID | None = None,
) -> EventoResposta:
    try:
        return service.registrar_equipe(db, evento_id, usuario.id, dados.status, edicao_id, dados.confirmar_integrantes)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.delete("/{evento_id}/minha-equipe", response_model=EventoResposta)
def retirar_equipe(
    evento_id: UUID, usuario: UsuarioAtual, db: DbSession, edicao_id: UUID | None = None
) -> EventoResposta:
    try:
        return service.remover_equipe(db, evento_id, usuario.id, edicao_id)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error

@router.patch("/{evento_id}", response_model=EventoResposta)
def editar_encontro(evento_id: UUID, dados: EncontroAtualizacao, usuario: UsuarioAtual, db: DbSession) -> EventoResposta:
    try:
        return service.atualizar(db, evento_id, usuario.id, dados)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error


@router.delete("/{evento_id}", status_code=status.HTTP_204_NO_CONTENT)
def excluir_encontro(evento_id: UUID, usuario: UsuarioAtual, db: DbSession) -> Response:
    try:
        service.excluir(db, evento_id, usuario.id)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{evento_id}/capa", response_model=EventoResposta)
async def enviar_capa(evento_id: UUID, usuario: UsuarioAtual, db: DbSession, arquivo: Annotated[UploadFile, File()]) -> EventoResposta:
    from app.core.config import settings
    from app.services.media import salvar_capa_encontro, remover_media, ArquivoMuitoGrande, ImagemInvalida
    try:
        encontro = service.gerenciavel(db, evento_id, usuario.id)
    except (service.EventoNaoEncontrado, service.AcaoEventoNaoPermitida) as error:
        raise _erro(error) from error
    conteudo = await arquivo.read(settings.media_max_upload_bytes + 1)
    try:
        nova_url = salvar_capa_encontro(evento_id, conteudo)
    except ArquivoMuitoGrande as error:
        raise HTTPException(status_code=413, detail="A capa deve ter no máximo 10 MB.") from error
    except ImagemInvalida as error:
        raise HTTPException(status_code=415, detail="Envie uma imagem válida.") from error
    antiga = encontro.capa_url
    encontro.capa_url = nova_url
    try:
        db.commit()
    except Exception:
        db.rollback()
        remover_media(nova_url)
        raise
    remover_media(antiga)
    return service.detalhar(db, evento_id, usuario.id)
