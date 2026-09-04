import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import jwt
from jwt import InvalidTokenError
from pwdlib import PasswordHash

from app.core.config import settings


ALGORITHM = "HS256"
password_hash = PasswordHash.recommended()


class TokenInvalido(ValueError):
    pass


def gerar_hash_senha(senha: str) -> str:
    return password_hash.hash(senha)


def verificar_senha(senha: str, senha_hash: str) -> bool:
    return password_hash.verify(senha, senha_hash)


def criar_access_token(usuario_id: UUID) -> tuple[str, int]:
    agora = datetime.now(timezone.utc)
    expira_em = agora + timedelta(minutes=settings.access_token_minutes)
    payload = {
        "sub": str(usuario_id),
        "type": "access",
        "iat": agora,
        "exp": expira_em,
        "jti": str(uuid4()),
    }
    token = jwt.encode(
        payload,
        settings.jwt_secret.get_secret_value(),
        algorithm=ALGORITHM,
    )
    return token, settings.access_token_minutes * 60


def decodificar_access_token(token: str) -> str:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret.get_secret_value(),
            algorithms=[ALGORITHM],
            options={"require": ["sub", "type", "iat", "exp", "jti"]},
        )
    except InvalidTokenError as error:
        raise TokenInvalido("Token invalido ou expirado.") from error

    if payload.get("type") != "access":
        raise TokenInvalido("Tipo de token invalido.")

    subject = payload.get("sub")
    if not isinstance(subject, str):
        raise TokenInvalido("Token sem identificador de usuario.")
    return subject


def criar_refresh_token() -> tuple[str, str]:
    token = secrets.token_urlsafe(64)
    return token, hash_refresh_token(token)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()

