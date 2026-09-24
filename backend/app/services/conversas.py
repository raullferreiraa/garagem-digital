import base64
import json
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.conversa import ConversaDireta, MensagemDireta
from app.services.bloqueios import existe_bloqueio, ids_com_bloqueio
from app.models.usuario import Usuario
from app.schemas.conversa import ConversaResumo, MensagemResposta, PaginaMensagens
from app.schemas.usuario import UsuarioResumo


class CursorInvalido(ValueError):
    pass


def _ordenar_usuarios(usuario_1: UUID, usuario_2: UUID) -> tuple[UUID, UUID]:
    return tuple(sorted((usuario_1, usuario_2), key=str))  # type: ignore[return-value]


def _participa(conversa: ConversaDireta, usuario_id: UUID) -> bool:
    return usuario_id in (conversa.usuario_a_id, conversa.usuario_b_id)


def _leu_em(conversa: ConversaDireta, usuario_id: UUID) -> datetime | None:
    return (
        conversa.usuario_a_leu_em
        if conversa.usuario_a_id == usuario_id
        else conversa.usuario_b_leu_em
    )


def _marcar_data_leitura(
    conversa: ConversaDireta,
    usuario_id: UUID,
    data: datetime,
) -> None:
    if conversa.usuario_a_id == usuario_id:
        conversa.usuario_a_leu_em = data
    else:
        conversa.usuario_b_leu_em = data


def buscar_conversa(
    db: Session,
    conversa_id: UUID,
    usuario_id: UUID,
) -> ConversaDireta | None:
    conversa = db.scalar(
        select(ConversaDireta).where(ConversaDireta.id == conversa_id)
    )
    if conversa is None or not _participa(conversa, usuario_id):
        return None
    outro_id = (
        conversa.usuario_b_id
        if conversa.usuario_a_id == usuario_id
        else conversa.usuario_a_id
    )
    if existe_bloqueio(db, usuario_id, outro_id):
        return None
    return conversa


def criar_ou_obter_conversa(
    db: Session,
    usuario_id: UUID,
    outro_usuario_id: UUID,
) -> ConversaDireta | None:
    if usuario_id == outro_usuario_id:
        raise ValueError("Voce nao pode iniciar uma conversa consigo mesmo.")
    if existe_bloqueio(db, usuario_id, outro_usuario_id):
        return None
    outro_usuario = db.scalar(
        select(Usuario).where(
            Usuario.id == outro_usuario_id,
            Usuario.ativo.is_(True),
        )
    )
    if outro_usuario is None:
        return None

    usuario_a_id, usuario_b_id = _ordenar_usuarios(usuario_id, outro_usuario_id)
    existente = db.scalar(
        select(ConversaDireta).where(
            ConversaDireta.usuario_a_id == usuario_a_id,
            ConversaDireta.usuario_b_id == usuario_b_id,
        )
    )
    if existente is not None:
        return existente

    agora = datetime.now(timezone.utc)
    conversa = ConversaDireta(
        usuario_a_id=usuario_a_id,
        usuario_b_id=usuario_b_id,
        usuario_a_leu_em=agora,
        usuario_b_leu_em=agora,
        atualizada_em=agora,
    )
    db.add(conversa)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        return db.scalar(
            select(ConversaDireta).where(
                ConversaDireta.usuario_a_id == usuario_a_id,
                ConversaDireta.usuario_b_id == usuario_b_id,
            )
        )
    db.refresh(conversa)
    return conversa


def _ultima_mensagem(db: Session, conversa_id: UUID) -> MensagemDireta | None:
    return db.scalar(
        select(MensagemDireta)
        .where(MensagemDireta.conversa_id == conversa_id)
        .order_by(MensagemDireta.criada_em.desc(), MensagemDireta.id.desc())
        .limit(1)
    )


def _total_nao_lidas(
    db: Session,
    conversa: ConversaDireta,
    usuario_id: UUID,
) -> int:
    consulta = select(func.count()).select_from(MensagemDireta).where(
        MensagemDireta.conversa_id == conversa.id,
        MensagemDireta.remetente_id != usuario_id,
    )
    lida_em = _leu_em(conversa, usuario_id)
    if lida_em is not None:
        consulta = consulta.where(MensagemDireta.criada_em > lida_em)
    return int(db.scalar(consulta) or 0)


def resumir_conversa(
    db: Session,
    conversa: ConversaDireta,
    usuario_id: UUID,
) -> ConversaResumo:
    outro_usuario = (
        conversa.usuario_b
        if conversa.usuario_a_id == usuario_id
        else conversa.usuario_a
    )
    ultima = _ultima_mensagem(db, conversa.id)
    return ConversaResumo(
        id=conversa.id,
        outro_usuario=UsuarioResumo.model_validate(outro_usuario),
        ultima_mensagem=(
            MensagemResposta.model_validate(ultima) if ultima is not None else None
        ),
        total_nao_lidas=_total_nao_lidas(db, conversa, usuario_id),
        criada_em=conversa.criada_em,
        atualizada_em=conversa.atualizada_em,
    )


def listar_conversas(db: Session, usuario_id: UUID) -> list[ConversaResumo]:
    conversas = db.scalars(
        select(ConversaDireta)
        .where(
            or_(
                ConversaDireta.usuario_a_id == usuario_id,
                ConversaDireta.usuario_b_id == usuario_id,
            ),
            case(
                (ConversaDireta.usuario_a_id == usuario_id, ConversaDireta.usuario_b_id),
                else_=ConversaDireta.usuario_a_id,
            ).not_in(ids_com_bloqueio(db, usuario_id)),
        )
        .order_by(ConversaDireta.atualizada_em.desc(), ConversaDireta.id.desc())
    ).unique()
    return [resumir_conversa(db, conversa, usuario_id) for conversa in conversas]


def total_conversas_nao_lidas(db: Session, usuario_id: UUID) -> int:
    ultima_leitura = case(
        (
            ConversaDireta.usuario_a_id == usuario_id,
            ConversaDireta.usuario_a_leu_em,
        ),
        else_=ConversaDireta.usuario_b_leu_em,
    )
    return int(
        db.scalar(
            select(func.count(func.distinct(ConversaDireta.id)))
            .join(
                MensagemDireta,
                MensagemDireta.conversa_id == ConversaDireta.id,
            )
            .where(
                or_(
                    ConversaDireta.usuario_a_id == usuario_id,
                    ConversaDireta.usuario_b_id == usuario_id,
                ),
                case(
                    (ConversaDireta.usuario_a_id == usuario_id, ConversaDireta.usuario_b_id),
                    else_=ConversaDireta.usuario_a_id,
                ).not_in(ids_com_bloqueio(db, usuario_id)),
                MensagemDireta.remetente_id != usuario_id,
                or_(
                    ultima_leitura.is_(None),
                    MensagemDireta.criada_em > ultima_leitura,
                ),
            )
        )
        or 0
    )


def enviar_mensagem(
    db: Session,
    conversa: ConversaDireta,
    remetente_id: UUID,
    conteudo: str,
) -> MensagemDireta:
    agora = datetime.now(timezone.utc)
    mensagem = MensagemDireta(
        conversa_id=conversa.id,
        remetente_id=remetente_id,
        conteudo=conteudo,
        criada_em=agora,
    )
    conversa.atualizada_em = agora
    _marcar_data_leitura(conversa, remetente_id, agora)
    db.add(mensagem)
    db.commit()
    db.refresh(mensagem)
    return mensagem


def marcar_conversa_como_lida(
    db: Session,
    conversa: ConversaDireta,
    usuario_id: UUID,
) -> None:
    _marcar_data_leitura(conversa, usuario_id, datetime.now(timezone.utc))
    db.commit()


def _codificar_cursor(mensagem: MensagemDireta) -> str:
    conteudo = json.dumps(
        {"criada_em": mensagem.criada_em.isoformat(), "id": str(mensagem.id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(conteudo).decode("ascii").rstrip("=")


def _decodificar_cursor(cursor: str) -> tuple[datetime, UUID]:
    try:
        padding = "=" * (-len(cursor) % 4)
        dados = json.loads(base64.urlsafe_b64decode(cursor + padding))
        return datetime.fromisoformat(dados["criada_em"]), UUID(dados["id"])
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise CursorInvalido("Cursor de paginacao invalido.") from error


def listar_mensagens(
    db: Session,
    conversa: ConversaDireta,
    *,
    limite: int,
    cursor: str | None,
) -> PaginaMensagens:
    consulta = select(MensagemDireta).where(
        MensagemDireta.conversa_id == conversa.id
    )
    if cursor:
        criada_em, mensagem_id = _decodificar_cursor(cursor)
        consulta = consulta.where(
            or_(
                MensagemDireta.criada_em < criada_em,
                and_(
                    MensagemDireta.criada_em == criada_em,
                    MensagemDireta.id < mensagem_id,
                ),
            )
        )
    mensagens = list(
        db.scalars(
            consulta.order_by(
                MensagemDireta.criada_em.desc(),
                MensagemDireta.id.desc(),
            ).limit(limite + 1)
        ).unique()
    )
    tem_proxima = len(mensagens) > limite
    mensagens = mensagens[:limite]
    proximo_cursor = (
        _codificar_cursor(mensagens[-1])
        if tem_proxima and mensagens
        else None
    )
    mensagens.reverse()
    return PaginaMensagens(
        itens=[MensagemResposta.model_validate(item) for item in mensagens],
        proximo_cursor=proximo_cursor,
    )
