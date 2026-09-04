from datetime import datetime, timedelta, timezone

from sqlalchemy import func, or_, select
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
from app.schemas.auth import CredenciaisLogin, TokenResposta, UsuarioCadastro, UsuarioPublico


class IdentificadorEmUso(ValueError):
    pass


class CredenciaisInvalidas(ValueError):
    pass


class RefreshTokenInvalido(ValueError):
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
        )
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
    access_token, expires_in = criar_access_token(usuario.id)
    return TokenResposta(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
        usuario=UsuarioPublico.model_validate(usuario),
    )


def emitir_tokens(db: Session, usuario: Usuario) -> TokenResposta:
    refresh_token = _adicionar_sessao_refresh(db, usuario)
    db.commit()
    db.refresh(usuario)
    return _montar_resposta(usuario, refresh_token)


def rotacionar_refresh_token(db: Session, token: str) -> TokenResposta:
    agora = datetime.now(timezone.utc)
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

    usuario = db.get(Usuario, sessao.usuario_id)
    if usuario is None or not usuario.ativo:
        raise RefreshTokenInvalido("Usuario indisponivel.")

    sessao.revogada_em = agora
    novo_refresh_token = _adicionar_sessao_refresh(db, usuario)
    db.commit()
    db.refresh(usuario)
    return _montar_resposta(usuario, novo_refresh_token)


def revogar_refresh_token(db: Session, token: str) -> None:
    sessao = db.scalar(
        select(SessaoRefresh).where(
            SessaoRefresh.token_hash == hash_refresh_token(token)
        )
    )
    if sessao is not None and sessao.revogada_em is None:
        sessao.revogada_em = datetime.now(timezone.utc)
        db.commit()
