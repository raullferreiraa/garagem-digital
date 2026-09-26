import base64
import binascii
import json
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from app.models.equipe import Equipe, LeituraChatEquipe, MensagemEquipe, MembroEquipe
from app.models.usuario import Usuario
from app.schemas.chat_equipe import (
    MensagemEquipeCitada,
    MensagemEquipeResposta,
    PaginaMensagensEquipe,
    ResumoChatEquipe,
)
from app.schemas.usuario import UsuarioResumo


def _membro(db: Session, equipe_id: UUID, usuario_id: UUID) -> bool:
    return db.get(MembroEquipe, (equipe_id, usuario_id)) is not None


def _cursor(mensagem: MensagemEquipe) -> str:
    raw = json.dumps({"criada_em": mensagem.criada_em.isoformat(), "id": str(mensagem.id)}, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def _ler_cursor(cursor: str) -> tuple[datetime, UUID]:
    try:
        data = json.loads(base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)))
        return datetime.fromisoformat(data["criada_em"]), UUID(data["id"])
    except (ValueError, KeyError, TypeError, binascii.Error) as error:
        raise ValueError("Cursor de paginacao invalido.") from error


def listar(db: Session, equipe_id: UUID, usuario_id: UUID, limite: int, cursor: str | None, busca: str | None = None) -> PaginaMensagensEquipe | None:
    if not _membro(db, equipe_id, usuario_id):
        return None

    # Paginar o histórico não significa ter visualizado mensagens novas.
    # Valida o cursor antes de alterar o estado de leitura.
    if cursor:
        _ler_cursor(cursor)
    elif busca is None:
        leitura = db.get(LeituraChatEquipe, (equipe_id, usuario_id))
        if leitura is None:
            db.add(LeituraChatEquipe(equipe_id=equipe_id, usuario_id=usuario_id))
        else:
            leitura.ultima_leitura_em = datetime.now(timezone.utc)
        db.commit()

    query = select(MensagemEquipe, Usuario).join(Usuario, Usuario.id == MensagemEquipe.autor_id).where(MensagemEquipe.equipe_id == equipe_id)
    if busca is not None:
        query = query.where(
            MensagemEquipe.excluida_em.is_(None),
            MensagemEquipe.conteudo.icontains(busca.strip(), autoescape=True),
        )
    if cursor:
        criado_em, mensagem_id = _ler_cursor(cursor)
        query = query.where(or_(MensagemEquipe.criada_em < criado_em, and_(MensagemEquipe.criada_em == criado_em, MensagemEquipe.id < mensagem_id)))
    rows = list(db.execute(query.order_by(MensagemEquipe.criada_em.desc(), MensagemEquipe.id.desc()).limit(limite + 1)))
    more = len(rows) > limite
    rows = rows[:limite]
    next_cursor = _cursor(rows[-1][0]) if more and rows else None
    rows.reverse()
    return PaginaMensagensEquipe(itens=[resposta(item, autor) for item, autor in rows], proximo_cursor=next_cursor)


def obter_mensagem(db: Session, equipe_id: UUID, mensagem_id: UUID, usuario_id: UUID) -> MensagemEquipe | None:
    if not _membro(db, equipe_id, usuario_id):
        return None
    mensagem = db.get(MensagemEquipe, mensagem_id)
    return mensagem if mensagem is not None and mensagem.equipe_id == equipe_id else None


def enviar(db: Session, equipe_id: UUID, usuario: Usuario, conteudo: str, resposta_a_id: UUID | None = None) -> MensagemEquipe | None:
    if not _membro(db, equipe_id, usuario.id): return None
    if resposta_a_id is not None:
        original = db.get(MensagemEquipe, resposta_a_id)
        if original is None or original.equipe_id != equipe_id or original.excluida_em is not None:
            raise ValueError("A mensagem respondida não está disponível nesta conversa.")
    mensagem = MensagemEquipe(equipe_id=equipe_id, autor_id=usuario.id, conteudo=conteudo, resposta_a_id=resposta_a_id)
    db.add(mensagem); db.commit(); db.refresh(mensagem)
    return mensagem


def resposta(mensagem: MensagemEquipe, usuario: Usuario) -> MensagemEquipeResposta:
    return MensagemEquipeResposta(
        id=mensagem.id, equipe_id=mensagem.equipe_id, conteudo=mensagem.conteudo,
        criada_em=mensagem.criada_em, editada_em=mensagem.editada_em,
        excluida_em=mensagem.excluida_em, autor=UsuarioResumo.model_validate(usuario),
        resposta_a=MensagemEquipeCitada.model_validate(mensagem.resposta_a)
        if mensagem.resposta_a is not None else None,
    )


def mensagem_do_autor(
    db: Session, equipe_id: UUID, mensagem_id: UUID, usuario_id: UUID
) -> MensagemEquipe | None:
    if not _membro(db, equipe_id, usuario_id):
        return None
    mensagem = db.get(MensagemEquipe, mensagem_id)
    if (
        mensagem is None
        or mensagem.equipe_id != equipe_id
        or mensagem.autor_id != usuario_id
    ):
        return None
    return mensagem


def editar_mensagem(
    db: Session, mensagem: MensagemEquipe, conteudo: str
) -> MensagemEquipe:
    mensagem.conteudo = conteudo
    mensagem.editada_em = datetime.now(timezone.utc)
    db.commit()
    db.refresh(mensagem)
    return mensagem


def apagar_mensagem(db: Session, mensagem: MensagemEquipe) -> None:
    if mensagem.excluida_em is not None:
        return
    mensagem.conteudo = ""
    mensagem.excluida_em = datetime.now(timezone.utc)
    db.commit()


def resumo(db: Session, usuario_id: UUID) -> ResumoChatEquipe | None:
    vinculo = db.execute(
        select(MembroEquipe, Equipe)
        .join(Equipe, Equipe.id == MembroEquipe.equipe_id)
        .where(MembroEquipe.usuario_id == usuario_id)
        .limit(1)
    ).first()
    if vinculo is None:
        return None

    membro, equipe = vinculo
    leitura = db.get(LeituraChatEquipe, (equipe.id, usuario_id))
    filtros = [
        MensagemEquipe.equipe_id == equipe.id,
        MensagemEquipe.autor_id != usuario_id,
        MensagemEquipe.excluida_em.is_(None),
    ]
    if leitura is not None:
        filtros.append(MensagemEquipe.criada_em > leitura.ultima_leitura_em)
    total_nao_lidas = db.scalar(
        select(func.count()).select_from(MensagemEquipe).where(*filtros)
    ) or 0

    ultima = db.execute(
        select(MensagemEquipe, Usuario)
        .join(Usuario, Usuario.id == MensagemEquipe.autor_id)
        .where(MensagemEquipe.equipe_id == equipe.id)
        .order_by(MensagemEquipe.criada_em.desc(), MensagemEquipe.id.desc())
        .limit(1)
    ).first()
    ultima_resposta = (
        resposta(ultima[0], ultima[1]) if ultima is not None else None
    )
    return ResumoChatEquipe(
        equipe_id=equipe.id,
        equipe_nome=equipe.nome,
        equipe_avatar_url=equipe.avatar_url,
        total_nao_lidas=total_nao_lidas,
        ultima_mensagem=ultima_resposta,
    )
