import re
import unicodedata
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.models.carro import Carro
from app.models.equipe import CarroEquipe, Equipe, MembroEquipe, SolicitacaoEquipe
from app.models.usuario import Usuario
from app.schemas.carro import CarroPublico
from app.schemas.equipe import (
    EquipeCriacao,
    EquipeDetalhe,
    EquipeResumo,
    MembroEquipeResposta,
    SolicitacaoEquipeResposta,
)
from app.schemas.usuario import UsuarioResumo


class EquipeNaoEncontrada(ValueError):
    pass


class AcaoNaoPermitida(ValueError):
    pass


class EstadoInvalido(ValueError):
    pass


def _slug_base(nome: str) -> str:
    normalizado = unicodedata.normalize("NFKD", nome)
    ascii_nome = normalizado.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "-", ascii_nome.lower()).strip("-") or "equipe"


def _slug_disponivel(db: Session, nome: str) -> str:
    base = _slug_base(nome)[:110]
    slug = base
    numero = 2
    while db.scalar(select(Equipe.id).where(Equipe.slug == slug)) is not None:
        sufixo = f"-{numero}"
        slug = f"{base[:120 - len(sufixo)]}{sufixo}"
        numero += 1
    return slug


def criar_equipe(db: Session, usuario: Usuario, dados: EquipeCriacao) -> Equipe:
    equipe = Equipe(
        dono_id=usuario.id,
        slug=_slug_disponivel(db, dados.nome),
        **dados.model_dump(),
    )
    db.add(equipe)
    db.flush()
    db.add(MembroEquipe(equipe_id=equipe.id, usuario_id=usuario.id, papel="dono"))
    db.commit()
    db.refresh(equipe)
    return equipe


def obter_equipe(db: Session, equipe_id: UUID) -> Equipe:
    equipe = db.get(Equipe, equipe_id)
    if equipe is None:
        raise EquipeNaoEncontrada("Equipe nao encontrada.")
    return equipe


def _meu_estado(
    db: Session, equipe_id: UUID, usuario_id: UUID
) -> tuple[str | None, str | None]:
    papel = db.scalar(
        select(MembroEquipe.papel).where(
            MembroEquipe.equipe_id == equipe_id,
            MembroEquipe.usuario_id == usuario_id,
        )
    )
    solicitacao = db.scalar(
        select(SolicitacaoEquipe.status)
        .where(
            SolicitacaoEquipe.equipe_id == equipe_id,
            SolicitacaoEquipe.usuario_id == usuario_id,
        )
        .order_by(SolicitacaoEquipe.criada_em.desc())
        .limit(1)
    )
    return papel, solicitacao


def _resumo(db: Session, equipe: Equipe, usuario_id: UUID) -> EquipeResumo:
    total = db.scalar(
        select(func.count()).select_from(MembroEquipe).where(
            MembroEquipe.equipe_id == equipe.id
        )
    )
    papel, solicitacao = _meu_estado(db, equipe.id, usuario_id)
    return EquipeResumo(
        id=equipe.id,
        nome=equipe.nome,
        slug=equipe.slug,
        descricao=equipe.descricao,
        cidade=equipe.cidade,
        estado=equipe.estado,
        visibilidade=equipe.visibilidade,
        total_membros=total or 0,
        meu_papel=papel,
        minha_solicitacao=solicitacao,
    )


def listar_equipes(db: Session, usuario_id: UUID) -> list[EquipeResumo]:
    equipes = db.scalars(
        select(Equipe)
        .where(
            (Equipe.visibilidade == "publica")
            | (Equipe.id.in_(
                select(MembroEquipe.equipe_id).where(
                    MembroEquipe.usuario_id == usuario_id
                )
            ))
        )
        .order_by(Equipe.criado_em.desc(), Equipe.id.desc())
    ).all()
    return [_resumo(db, equipe, usuario_id) for equipe in equipes]


def detalhar_equipe(
    db: Session, equipe_id: UUID, usuario_id: UUID
) -> EquipeDetalhe:
    equipe = obter_equipe(db, equipe_id)
    resumo = _resumo(db, equipe, usuario_id)
    if equipe.visibilidade == "privada" and resumo.meu_papel is None:
        raise EquipeNaoEncontrada("Equipe nao encontrada.")

    linhas_membros = db.execute(
        select(MembroEquipe, Usuario)
        .join(Usuario, Usuario.id == MembroEquipe.usuario_id)
        .where(MembroEquipe.equipe_id == equipe.id)
        .order_by(MembroEquipe.entrou_em)
    ).all()
    carros = db.scalars(
        select(Carro)
        .join(CarroEquipe, CarroEquipe.carro_id == Carro.id)
        .where(CarroEquipe.equipe_id == equipe.id)
        .order_by(CarroEquipe.adicionado_em.desc())
    ).unique().all()

    pendentes: list[SolicitacaoEquipeResposta] = []
    if resumo.meu_papel in {"dono", "administrador"}:
        linhas_pendentes = db.execute(
            select(SolicitacaoEquipe, Usuario)
            .join(Usuario, Usuario.id == SolicitacaoEquipe.usuario_id)
            .where(
                SolicitacaoEquipe.equipe_id == equipe.id,
                SolicitacaoEquipe.status == "pendente",
            )
            .order_by(SolicitacaoEquipe.criada_em)
        ).all()
        pendentes = [
            SolicitacaoEquipeResposta(
                id=solicitacao.id,
                usuario=UsuarioResumo.model_validate(membro),
                status=solicitacao.status,
                criada_em=solicitacao.criada_em,
            )
            for solicitacao, membro in linhas_pendentes
        ]

    return EquipeDetalhe(
        **resumo.model_dump(),
        dono_id=equipe.dono_id,
        membros=[
            MembroEquipeResposta(
                usuario=UsuarioResumo.model_validate(usuario),
                papel=membro.papel,
                entrou_em=membro.entrou_em,
            )
            for membro, usuario in linhas_membros
        ],
        carros=[CarroPublico.model_validate(carro) for carro in carros],
        solicitacoes_pendentes=pendentes,
    )


def solicitar_entrada(
    db: Session, equipe_id: UUID, usuario: Usuario
) -> SolicitacaoEquipe:
    obter_equipe(db, equipe_id)
    if db.get(MembroEquipe, (equipe_id, usuario.id)) is not None:
        raise EstadoInvalido("Voce ja faz parte desta equipe.")
    pendente = db.scalar(
        select(SolicitacaoEquipe).where(
            SolicitacaoEquipe.equipe_id == equipe_id,
            SolicitacaoEquipe.usuario_id == usuario.id,
            SolicitacaoEquipe.status == "pendente",
        )
    )
    if pendente is not None:
        raise EstadoInvalido("Sua solicitacao ja esta pendente.")
    solicitacao = SolicitacaoEquipe(equipe_id=equipe_id, usuario_id=usuario.id)
    db.add(solicitacao)
    db.commit()
    db.refresh(solicitacao)
    return solicitacao


def decidir_solicitacao(
    db: Session,
    equipe_id: UUID,
    solicitacao_id: UUID,
    gestor: Usuario,
    decisao: str,
) -> None:
    papel = db.scalar(
        select(MembroEquipe.papel).where(
            MembroEquipe.equipe_id == equipe_id,
            MembroEquipe.usuario_id == gestor.id,
        )
    )
    if papel not in {"dono", "administrador"}:
        raise AcaoNaoPermitida("Apenas a gestao da equipe pode analisar pedidos.")
    solicitacao = db.get(SolicitacaoEquipe, solicitacao_id)
    if solicitacao is None or solicitacao.equipe_id != equipe_id:
        raise EquipeNaoEncontrada("Solicitacao nao encontrada.")
    if solicitacao.status != "pendente":
        raise EstadoInvalido("Esta solicitacao ja foi analisada.")
    if decisao == "aprovar":
        if db.get(MembroEquipe, (equipe_id, solicitacao.usuario_id)) is None:
            db.add(
                MembroEquipe(
                    equipe_id=equipe_id,
                    usuario_id=solicitacao.usuario_id,
                    papel="membro",
                )
            )
        solicitacao.status = "aprovada"
    else:
        solicitacao.status = "recusada"
    solicitacao.analisada_por = gestor.id
    solicitacao.analisada_em = datetime.now(timezone.utc)
    db.commit()


def escolher_carro(
    db: Session, equipe_id: UUID, carro_id: UUID, usuario: Usuario
) -> None:
    if db.get(MembroEquipe, (equipe_id, usuario.id)) is None:
        raise AcaoNaoPermitida("Voce precisa ser membro da equipe.")
    carro = db.get(Carro, carro_id)
    if carro is None or carro.proprietario_id != usuario.id:
        raise AcaoNaoPermitida("Escolha um carro da sua propria garagem.")
    db.execute(
        delete(CarroEquipe).where(
            CarroEquipe.equipe_id == equipe_id,
            CarroEquipe.adicionado_por == usuario.id,
        )
    )
    db.add(
        CarroEquipe(
            equipe_id=equipe_id,
            carro_id=carro_id,
            adicionado_por=usuario.id,
        )
    )
    db.commit()


def remover_carro_escolhido(
    db: Session, equipe_id: UUID, usuario: Usuario
) -> None:
    if db.get(MembroEquipe, (equipe_id, usuario.id)) is None:
        raise AcaoNaoPermitida("Voce precisa ser membro da equipe.")
    db.execute(
        delete(CarroEquipe).where(
            CarroEquipe.equipe_id == equipe_id,
            CarroEquipe.adicionado_por == usuario.id,
        )
    )
    db.commit()
