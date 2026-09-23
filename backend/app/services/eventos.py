from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from app.models.carro import Carro
from app.models.equipe import Equipe, MembroEquipe
from app.models.evento import (
    Encontro,
    Evento,
    ParticipacaoEquipeEvento,
    PresencaEvento,
    SeguidorEncontro,
)
from app.models.usuario import Usuario
from app.schemas.evento import EdicaoCriacao, EdicaoResposta, EncontroCriacao, EncontroResposta, EncontroAtualizacao


class EventoNaoEncontrado(ValueError):
    pass


class AcaoEventoNaoPermitida(ValueError):
    pass


def _em_utc(valor: datetime) -> datetime:
    return valor.replace(tzinfo=timezone.utc) if valor.tzinfo is None else valor.astimezone(timezone.utc)


def _equipe_e_papel(db: Session, usuario_id: UUID) -> tuple[Equipe | None, str | None]:
    resultado = db.execute(
        select(Equipe, MembroEquipe.papel)
        .join(MembroEquipe, MembroEquipe.equipe_id == Equipe.id)
        .where(MembroEquipe.usuario_id == usuario_id)
        .limit(1)
    ).first()
    return (resultado[0], resultado[1]) if resultado else (None, None)


def _pode_representar(papel: str | None) -> bool:
    return papel in {"dono", "administrador", "moderador"}


def _visivel(db: Session, encontro: Encontro, usuario_id: UUID) -> bool:
    if encontro.visibilidade == "publico" or (encontro.organizador_equipe_id is None and encontro.organizador_usuario_id == usuario_id):
        return True
    equipe, _ = _equipe_e_papel(db, usuario_id)
    return equipe is not None and equipe.id == encontro.organizador_equipe_id


def _proxima_edicao(db: Session, encontro_id: UUID) -> Evento | None:
    return db.scalar(
        select(Evento)
        .where(
            Evento.encontro_id == encontro_id,
            Evento.inicio >= datetime.now(timezone.utc),
            Evento.status == "agendada",
        )
        .order_by(Evento.inicio, Evento.id)
        .limit(1)
    )


def _resposta(db: Session, encontro: Encontro, edicao: Evento | None, usuario_id: UUID) -> EncontroResposta:
    equipe, papel = _equipe_e_papel(db, usuario_id)
    presenca = db.get(PresencaEvento, (edicao.id, usuario_id)) if edicao else None
    participacao = db.get(ParticipacaoEquipeEvento, (edicao.id, equipe.id)) if equipe and edicao else None
    if encontro.organizador_equipe_id is not None:
        organizador = db.get(Equipe, encontro.organizador_equipe_id)
        tipo = "equipe"
    else:
        organizador = db.get(Usuario, encontro.organizador_usuario_id)
        tipo = "usuario"
    pode_gerenciar = (encontro.organizador_equipe_id is None and encontro.organizador_usuario_id == usuario_id) or (
        equipe is not None
        and encontro.organizador_equipe_id == equipe.id
        and _pode_representar(papel)
    )
    return EncontroResposta(
        id=encontro.id,
        edicao_id=edicao.id if edicao else None,
        nome=encontro.nome,
        descricao=encontro.descricao,
        inicio=edicao.inicio if edicao else None,
        termino=edicao.termino if edicao else None,
        endereco_publico=edicao.endereco_publico if edicao else None,
        cidade=encontro.cidade,
        estado=encontro.estado,
        edicao_cidade=edicao.cidade if edicao else None,
        edicao_estado=edicao.estado if edicao else None,
        visibilidade=encontro.visibilidade,
        organizador_tipo=tipo,
        organizador_nome=organizador.nome if organizador else "Organizador indisponível",
        organizador_id=organizador.id if organizador else encontro.id,
        total_seguidores=db.scalar(select(func.count()).select_from(SeguidorEncontro).where(SeguidorEncontro.encontro_id == encontro.id)) or 0,
        seguindo=db.get(SeguidorEncontro, (encontro.id, usuario_id)) is not None,
        total_confirmados=db.scalar(select(func.count()).select_from(PresencaEvento).where(PresencaEvento.evento_id == (edicao.id if edicao else None), PresencaEvento.status == "confirmada")) or 0,
        total_equipes=db.scalar(select(func.count()).select_from(ParticipacaoEquipeEvento).where(ParticipacaoEquipeEvento.evento_id == (edicao.id if edicao else None), ParticipacaoEquipeEvento.status == "confirmada")) or 0,
        minha_presenca=presenca.status if presenca and presenca.status != "cancelada" else None,
        minha_equipe_id=equipe.id if equipe else None,
        minha_equipe_nome=equipe.nome if equipe else None,
        minha_equipe_total_integrantes=(db.scalar(select(func.count()).select_from(MembroEquipe).where(MembroEquipe.equipe_id == equipe.id)) or 0) if equipe else 0,
        minha_equipe_papel=papel,
        minha_equipe_participacao=participacao.status if participacao else None,
        posso_gerenciar=pode_gerenciar,
        capa_url=encontro.capa_url,
        edicoes=[
            EdicaoResposta(
                id=item.id, inicio=item.inicio, termino=item.termino,
                endereco_publico=item.endereco_publico,
                cidade=item.cidade, estado=item.estado, status=item.status,
                total_confirmados=db.scalar(select(func.count()).select_from(PresencaEvento).where(PresencaEvento.evento_id == item.id, PresencaEvento.status == "confirmada")) or 0,
                total_equipes=db.scalar(select(func.count()).select_from(ParticipacaoEquipeEvento).where(ParticipacaoEquipeEvento.evento_id == item.id, ParticipacaoEquipeEvento.status == "confirmada")) or 0,
            )
            for item in db.scalars(select(Evento).where(Evento.encontro_id == encontro.id).order_by(Evento.inicio.desc()).limit(50))
        ],
    )


def criar(db: Session, usuario: Usuario, dados: EncontroCriacao) -> EncontroResposta:
    equipe, papel = _equipe_e_papel(db, usuario.id)
    if dados.organizador == "equipe" and (equipe is None or not _pode_representar(papel)):
        raise AcaoEventoNaoPermitida("Você não pode criar encontros em nome da equipe.")
    encontro = Encontro(
        organizador_usuario_id=usuario.id,
        organizador_equipe_id=equipe.id if dados.organizador == "equipe" else None,
        nome=dados.nome,
        descricao=dados.descricao,
        cidade=dados.cidade,
        estado=dados.estado,
        visibilidade=dados.visibilidade,
    )
    db.add(encontro)
    db.flush()
    edicao = None
    if dados.proxima_edicao is not None:
        edicao = _nova_edicao(db, encontro, usuario.id, dados.proxima_edicao)
    db.add(SeguidorEncontro(encontro_id=encontro.id, usuario_id=usuario.id))
    db.commit()
    return _resposta(db, encontro, edicao, usuario.id)


def criar_edicao(db: Session, encontro_id: UUID, usuario_id: UUID, dados: EdicaoCriacao) -> EncontroResposta:
    encontro = gerenciavel(db, encontro_id, usuario_id, bloquear=True)
    _nova_edicao(db, encontro, usuario_id, dados)
    db.commit()
    return detalhar(db, encontro_id, usuario_id)


def _nova_edicao(db: Session, encontro: Encontro, usuario_id: UUID, dados: EdicaoCriacao) -> Evento:
    cidade = encontro.cidade if dados.usar_regiao_comunidade else dados.cidade
    estado = encontro.estado if dados.usar_regiao_comunidade else dados.estado
    edicao = Evento(
        encontro_id=encontro.id,
        organizador_usuario_id=encontro.organizador_usuario_id,
        organizador_equipe_id=encontro.organizador_equipe_id,
        nome=encontro.nome, descricao=encontro.descricao,
        cidade=cidade,
        estado=estado,
        visibilidade=encontro.visibilidade,
        inicio=dados.inicio,
        termino=dados.termino,
        endereco_publico=dados.endereco_publico,
    )
    db.add(edicao)
    db.flush()
    if encontro.organizador_equipe_id:
        db.add(ParticipacaoEquipeEvento(evento_id=edicao.id, equipe_id=encontro.organizador_equipe_id, registrada_por=usuario_id))
    return edicao


def atualizar_edicao(
    db: Session,
    encontro_id: UUID,
    edicao_id: UUID,
    usuario_id: UUID,
    dados: EdicaoCriacao,
) -> EncontroResposta:
    encontro = gerenciavel(db, encontro_id, usuario_id, bloquear=True)
    edicao = db.scalar(
        select(Evento)
        .where(Evento.id == edicao_id, Evento.encontro_id == encontro.id)
        .with_for_update()
    )
    if edicao is None:
        raise EventoNaoEncontrado("Edição não encontrada.")
    if edicao.status == "cancelada":
        raise AcaoEventoNaoPermitida("Uma edição cancelada não pode ser alterada.")
    if _em_utc(edicao.inicio) < datetime.now(timezone.utc):
        raise AcaoEventoNaoPermitida("Uma edição já realizada não pode ser alterada.")
    edicao.inicio = dados.inicio
    edicao.termino = dados.termino
    edicao.endereco_publico = dados.endereco_publico
    edicao.cidade = encontro.cidade if dados.usar_regiao_comunidade else dados.cidade
    edicao.estado = encontro.estado if dados.usar_regiao_comunidade else dados.estado
    db.commit()
    return detalhar(db, encontro_id, usuario_id)


def cancelar_edicao(
    db: Session, encontro_id: UUID, edicao_id: UUID, usuario_id: UUID
) -> EncontroResposta:
    encontro = gerenciavel(db, encontro_id, usuario_id, bloquear=True)
    edicao = db.scalar(
        select(Evento)
        .where(Evento.id == edicao_id, Evento.encontro_id == encontro.id)
        .with_for_update()
    )
    if edicao is None:
        raise EventoNaoEncontrado("Edição não encontrada.")
    if _em_utc(edicao.inicio) < datetime.now(timezone.utc):
        raise AcaoEventoNaoPermitida("Uma edição já realizada não pode ser cancelada.")
    edicao.status = "cancelada"
    db.commit()
    return detalhar(db, encontro_id, usuario_id)


def gerenciavel(db: Session, encontro_id: UUID, usuario_id: UUID, bloquear: bool = False) -> Encontro:
    query = select(Encontro).where(Encontro.id == encontro_id)
    encontro = db.scalar(query.with_for_update() if bloquear else query)
    if encontro is None or not _visivel(db, encontro, usuario_id):
        raise EventoNaoEncontrado("Encontro não encontrado.")
    equipe, papel = _equipe_e_papel(db, usuario_id)
    permitido = (
        equipe is not None and equipe.id == encontro.organizador_equipe_id and _pode_representar(papel)
        if encontro.organizador_equipe_id is not None
        else encontro.organizador_usuario_id == usuario_id
    )
    if not permitido:
        raise AcaoEventoNaoPermitida("Somente a organização pode alterar este encontro.")
    return encontro


def atualizar(db: Session, encontro_id: UUID, usuario_id: UUID, dados: EncontroAtualizacao) -> EncontroResposta:
    encontro = gerenciavel(db, encontro_id, usuario_id)
    for campo, valor in dados.model_dump().items():
        setattr(encontro, campo, valor)
    db.commit()
    return detalhar(db, encontro_id, usuario_id)


def listar(db: Session, usuario_id: UUID) -> list[EncontroResposta]:
    equipe, _ = _equipe_e_papel(db, usuario_id)
    criterios = [Encontro.visibilidade == "publico", (Encontro.organizador_equipe_id.is_(None) & (Encontro.organizador_usuario_id == usuario_id))]
    if equipe:
        criterios.append(Encontro.organizador_equipe_id == equipe.id)
    encontros = db.scalars(select(Encontro).where(or_(*criterios)).order_by(Encontro.criado_em.desc())).all()
    respostas = []
    for encontro in encontros:
        edicao = _proxima_edicao(db, encontro.id)
        respostas.append(_resposta(db, encontro, edicao, usuario_id))
    return respostas


def detalhar(db: Session, encontro_id: UUID, usuario_id: UUID) -> EncontroResposta:
    encontro = db.get(Encontro, encontro_id)
    if encontro is None or not _visivel(db, encontro, usuario_id):
        raise EventoNaoEncontrado("Encontro não encontrado.")
    edicao = _proxima_edicao(db, encontro_id)
    return _resposta(db, encontro, edicao, usuario_id)


def seguir(db: Session, encontro_id: UUID, usuario_id: UUID, ativo: bool) -> EncontroResposta:
    detalhar(db, encontro_id, usuario_id)
    db.scalar(select(Encontro).where(Encontro.id == encontro_id).with_for_update())
    registro = db.get(SeguidorEncontro, (encontro_id, usuario_id))
    if ativo and registro is None:
        db.add(SeguidorEncontro(encontro_id=encontro_id, usuario_id=usuario_id))
    elif not ativo and registro is not None:
        db.delete(registro)
    db.commit()
    return detalhar(db, encontro_id, usuario_id)


def registrar_presenca(db: Session, encontro_id: UUID, usuario_id: UUID, status: str, carro_id: UUID | None, edicao_id: UUID | None = None) -> EncontroResposta:
    db.scalar(select(Encontro).where(Encontro.id == encontro_id).with_for_update())
    resposta = detalhar(db, encontro_id, usuario_id)
    if edicao_id is not None and resposta.edicao_id != edicao_id:
        raise AcaoEventoNaoPermitida("A próxima edição mudou. Atualize o encontro antes de confirmar.")
    if resposta.edicao_id is None:
        raise AcaoEventoNaoPermitida("Não há uma próxima edição para confirmar presença.")
    if carro_id is not None and db.scalar(select(Carro.id).where(Carro.id == carro_id, Carro.proprietario_id == usuario_id)) is None:
        raise AcaoEventoNaoPermitida("O carro selecionado não pertence a você.")
    presenca = db.get(PresencaEvento, (resposta.edicao_id, usuario_id))
    if presenca is None:
        presenca = PresencaEvento(evento_id=resposta.edicao_id, usuario_id=usuario_id)
        db.add(presenca)
    presenca.status, presenca.carro_id = status, carro_id
    db.commit()
    return detalhar(db, encontro_id, usuario_id)


def remover_presenca(db: Session, encontro_id: UUID, usuario_id: UUID, edicao_id: UUID | None = None) -> EncontroResposta:
    db.scalar(select(Encontro).where(Encontro.id == encontro_id).with_for_update())
    resposta = detalhar(db, encontro_id, usuario_id)
    if edicao_id is not None and resposta.edicao_id != edicao_id:
        raise AcaoEventoNaoPermitida("A próxima edição mudou. Atualize o encontro antes de confirmar.")
    if resposta.edicao_id is None:
        raise AcaoEventoNaoPermitida("Não há uma próxima edição para confirmar presença.")
    presenca = db.get(PresencaEvento, (resposta.edicao_id, usuario_id))
    if presenca is None:
        presenca = PresencaEvento(evento_id=resposta.edicao_id, usuario_id=usuario_id)
        db.add(presenca)
    # Preserve the member's choice when a manager confirms the team again.
    presenca.status = "cancelada"
    presenca.carro_id = None
    db.commit()
    return detalhar(db, encontro_id, usuario_id)


def registrar_equipe(db: Session, encontro_id: UUID, usuario_id: UUID, status: str, edicao_id: UUID | None = None, confirmar_integrantes: bool = False) -> EncontroResposta:
    db.scalar(select(Encontro).where(Encontro.id == encontro_id).with_for_update())
    resposta = detalhar(db, encontro_id, usuario_id)
    if edicao_id is not None and resposta.edicao_id != edicao_id:
        raise AcaoEventoNaoPermitida("A próxima edição mudou. Atualize o encontro antes de confirmar.")
    if resposta.edicao_id is None:
        raise AcaoEventoNaoPermitida("Não há uma próxima edição para confirmar presença.")
    equipe, papel = _equipe_e_papel(db, usuario_id)
    if equipe is None or not _pode_representar(papel):
        raise AcaoEventoNaoPermitida("Você não pode representar uma equipe neste encontro.")
    participacao = db.get(ParticipacaoEquipeEvento, (resposta.edicao_id, equipe.id))
    if participacao is None:
        participacao = ParticipacaoEquipeEvento(evento_id=resposta.edicao_id, equipe_id=equipe.id, registrada_por=usuario_id)
        db.add(participacao)
    participacao.status = status
    if confirmar_integrantes and status == "confirmada":
        integrantes = db.scalars(select(MembroEquipe.usuario_id).where(MembroEquipe.equipe_id == equipe.id)).all()
        existentes = set(db.scalars(select(PresencaEvento.usuario_id).where(PresencaEvento.evento_id == resposta.edicao_id)))
        for integrante in integrantes:
            if integrante not in existentes:
                db.add(PresencaEvento(evento_id=resposta.edicao_id, usuario_id=integrante, status="confirmada"))
    db.commit()
    return detalhar(db, encontro_id, usuario_id)


def remover_equipe(db: Session, encontro_id: UUID, usuario_id: UUID, edicao_id: UUID | None = None) -> EncontroResposta:
    db.scalar(select(Encontro).where(Encontro.id == encontro_id).with_for_update())
    resposta = detalhar(db, encontro_id, usuario_id)
    if edicao_id is not None and resposta.edicao_id != edicao_id:
        raise AcaoEventoNaoPermitida("A próxima edição mudou. Atualize o encontro antes de confirmar.")
    if resposta.edicao_id is None:
        raise AcaoEventoNaoPermitida("Não há uma próxima edição para confirmar presença.")
    encontro = db.get(Encontro, encontro_id)
    equipe, papel = _equipe_e_papel(db, usuario_id)
    if equipe is None or not _pode_representar(papel):
        raise AcaoEventoNaoPermitida("Você não pode representar uma equipe neste encontro.")
    if encontro and encontro.organizador_equipe_id == equipe.id:
        raise AcaoEventoNaoPermitida("A equipe organizadora não pode retirar sua participação.")
    participacao = db.get(ParticipacaoEquipeEvento, (resposta.edicao_id, equipe.id))
    if participacao:
        db.delete(participacao)
        db.commit()
    return detalhar(db, encontro_id, usuario_id)


def excluir(db: Session, encontro_id: UUID, usuario_id: UUID) -> None:
    encontro = gerenciavel(db, encontro_id, usuario_id, bloquear=True)
    capa = encontro.capa_url
    edicoes = select(Evento.id).where(Evento.encontro_id == encontro_id)
    db.execute(delete(PresencaEvento).where(PresencaEvento.evento_id.in_(edicoes)))
    db.execute(delete(ParticipacaoEquipeEvento).where(ParticipacaoEquipeEvento.evento_id.in_(edicoes)))
    db.execute(delete(Evento).where(Evento.encontro_id == encontro_id))
    db.execute(delete(SeguidorEncontro).where(SeguidorEncontro.encontro_id == encontro_id))
    db.delete(encontro)
    db.commit()
    from app.services.media import remover_media
    remover_media(capa)
