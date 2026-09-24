from datetime import datetime, timedelta, timezone

from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import (
    criar_access_token,
    criar_refresh_token,
    gerar_hash_senha,
    hash_refresh_token,
    verificar_senha,
)
from app.models.sessao_refresh import SessaoRefresh
from app.models.usuario import Usuario
from app.schemas.auth import CredenciaisLogin, TokenResposta, UsuarioCadastro
from app.schemas.usuario import PerfilPrivado


class IdentificadorEmUso(ValueError):
    pass


class CredenciaisInvalidas(ValueError):
    pass


class RefreshTokenInvalido(ValueError):
    pass


class SenhaAtualIncorreta(ValueError):
    pass


class NovaSenhaInvalida(ValueError):
    pass


def _em_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def cadastrar_usuario(db: Session, dados: UsuarioCadastro) -> Usuario:
    conflito = db.scalar(
        select(Usuario.id).where(
            or_(
                func.lower(Usuario.email) == str(dados.email).lower(),
                Usuario.username == dados.username,
            )
        )
    )
    if conflito is not None:
        raise IdentificadorEmUso("Email ou username ja esta em uso.")

    usuario = Usuario(
        nome=dados.nome,
        username=dados.username,
        email=str(dados.email).lower(),
        senha_hash=gerar_hash_senha(dados.senha),
    )
    db.add(usuario)
    db.flush()
    return usuario


def autenticar_usuario(db: Session, dados: CredenciaisLogin) -> Usuario:
    usuario = db.scalar(
        select(Usuario).where(
            or_(
                func.lower(Usuario.email) == dados.identificador,
                Usuario.username == dados.identificador,
            )
        ).with_for_update()
    )

    if (
        usuario is None
        or not usuario.ativo
        or not verificar_senha(dados.senha, usuario.senha_hash)
    ):
        raise CredenciaisInvalidas("Email, username ou senha incorretos.")
    return usuario


def _adicionar_sessao_refresh(db: Session, usuario: Usuario) -> str:
    refresh_token, token_hash = criar_refresh_token()
    db.add(
        SessaoRefresh(
            usuario_id=usuario.id,
            token_hash=token_hash,
            expira_em=datetime.now(timezone.utc)
            + timedelta(days=settings.refresh_token_days),
        )
    )
    return refresh_token


def _montar_resposta(usuario: Usuario, refresh_token: str) -> TokenResposta:
    access_token, expires_in = criar_access_token(usuario.id, usuario.versao_auth)
    return TokenResposta(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
        usuario=PerfilPrivado.model_validate(usuario),
    )


def emitir_tokens(db: Session, usuario: Usuario) -> TokenResposta:
    refresh_token = _adicionar_sessao_refresh(db, usuario)
    resposta = _montar_resposta(usuario, refresh_token)
    db.commit()
    return resposta


def alterar_senha(
    db: Session,
    usuario: Usuario,
    senha_atual: str,
    nova_senha: str,
) -> TokenResposta:
    db.refresh(usuario, with_for_update=True)
    if not verificar_senha(senha_atual, usuario.senha_hash):
        raise SenhaAtualIncorreta("A senha atual está incorreta.")
    if verificar_senha(nova_senha, usuario.senha_hash):
        raise NovaSenhaInvalida("A nova senha deve ser diferente da atual.")

    agora = datetime.now(timezone.utc)
    usuario.senha_hash = gerar_hash_senha(nova_senha)
    usuario.versao_auth += 1
    db.execute(
        update(SessaoRefresh)
        .where(
            SessaoRefresh.usuario_id == usuario.id,
            SessaoRefresh.revogada_em.is_(None),
        )
        .values(revogada_em=agora)
    )
    refresh_token = _adicionar_sessao_refresh(db, usuario)
    resposta = _montar_resposta(usuario, refresh_token)
    db.commit()
    return resposta


def rotacionar_refresh_token(db: Session, token: str) -> TokenResposta:
    agora = datetime.now(timezone.utc)
    # Mesma ordem de bloqueios da troca de senha: usuário, depois sessões.
    usuario_id = db.scalar(
        select(SessaoRefresh.usuario_id).where(
            SessaoRefresh.token_hash == hash_refresh_token(token)
        )
    )
    if usuario_id is None:
        raise RefreshTokenInvalido("Sessão expirada ou revogada.")
    usuario = db.scalar(
        select(Usuario).where(Usuario.id == usuario_id).with_for_update()
    )
    sessao = db.scalar(
        select(SessaoRefresh)
        .where(SessaoRefresh.token_hash == hash_refresh_token(token))
        .with_for_update()
    )

    if (
        sessao is None
        or sessao.revogada_em is not None
        or _em_utc(sessao.expira_em) <= agora
    ):
        raise RefreshTokenInvalido("Sessao expirada ou revogada.")

    if usuario is None or not usuario.ativo:
        raise RefreshTokenInvalido("Usuario indisponivel.")

    sessao.revogada_em = agora
    novo_refresh_token = _adicionar_sessao_refresh(db, usuario)
    resposta = _montar_resposta(usuario, novo_refresh_token)
    db.commit()
    return resposta


def revogar_refresh_token(db: Session, token: str) -> None:
    sessao = db.scalar(
        select(SessaoRefresh).where(
            SessaoRefresh.token_hash == hash_refresh_token(token)
        )
    )
    if sessao is not None and sessao.revogada_em is None:
        sessao.revogada_em = datetime.now(timezone.utc)
        db.commit()
