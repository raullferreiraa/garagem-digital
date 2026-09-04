from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import TokenInvalido, decodificar_access_token
from app.models.usuario import Usuario


bearer_scheme = HTTPBearer(auto_error=False)


def obter_usuario_atual(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer_scheme),
    ],
    db: Annotated[Session, Depends(get_db)],
) -> Usuario:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticacao necessaria.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        usuario_id = UUID(decodificar_access_token(credentials.credentials))
    except (TokenInvalido, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalido ou expirado.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error

    usuario = db.get(Usuario, usuario_id)

    if usuario is None or not usuario.ativo:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario indisponivel.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return usuario


UsuarioAtual = Annotated[Usuario, Depends(obter_usuario_atual)]

