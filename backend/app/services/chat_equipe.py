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


def listar(db: Session, equipe_id: UUID, usuario_id: UUID, limite: int, cursor: str | None) -> PaginaMensagensEquipe | None:
    if not _membro(db, equipe_id, usuario_id):
        return None

    # Paginar o histórico não significa ter visualizado mensagens novas.
    # Valida o cursor antes de alterar o estado de leitura.
    if cursor:
        _ler_cursor(cursor)
    else:
        leitura = db.get(LeituraChatEquipe, (equipe_id, usuario_id))
        if leitura is None:
            db.add(LeituraChatEquipe(equipe_id=equipe_id, usuario_id=usuario_id))
        else:
            leitura.ultima_leitura_em = datetime.now(timezone.utc)
        db.commit()

    query = select(MensagemEquipe, Usuario).join(Usuario, Usuario.id == MensagemEquipe.autor_id).where(MensagemEquipe.equipe_id == equipe_id)
    if cursor:
        criado_em, mensagem_id = _ler_cursor(cursor)
        query = query.where(or_(MensagemEquipe.criada_em < criado_em, and_(MensagemEquipe.criada_em == criado_em, MensagemEquipe.id < mensagem_id)))
    rows = list(db.execute(query.order_by(MensagemEquipe.criada_em.desc(), MensagemEquipe.id.desc()).limit(limite + 1)))
    more = len(rows) > limite
    rows = rows[:limite]
    next_cursor = _cursor(rows[-1][0]) if more and rows else None
    rows.reverse()
    return PaginaMensagensEquipe(itens=[MensagemEquipeResposta(id=item.id, equipe_id=item.equipe_id, conteudo=item.conteudo, criada_em=item.criada_em, autor=UsuarioResumo.model_validate(autor)) for item, autor in rows], proximo_cursor=next_cursor)


def enviar(db: Session, equipe_id: UUID, usuario: Usuario, conteudo: str) -> MensagemEquipe | None:
    if not _membro(db, equipe_id, usuario.id): return None
    mensagem = MensagemEquipe(equipe_id=equipe_id, autor_id=usuario.id, conteudo=conteudo)
    db.add(mensagem); db.commit(); db.refresh(mensagem)
    return mensagem


def resposta(mensagem: MensagemEquipe, usuario: Usuario) -> MensagemEquipeResposta:
    return MensagemEquipeResposta(id=mensagem.id, equipe_id=mensagem.equipe_id, conteudo=mensagem.conteudo, criada_em=mensagem.criada_em, autor=UsuarioResumo.model_validate(usuario))


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
