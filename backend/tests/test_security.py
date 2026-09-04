from uuid import uuid4

import pytest

from app.core.security import (
    TokenInvalido,
    criar_access_token,
    criar_refresh_token,
    decodificar_access_token,
    gerar_hash_senha,
    hash_refresh_token,
    verificar_senha,
)


def test_password_hash_nao_armazena_senha_pura() -> None:
    senha = "uma-senha-segura"
    senha_hash = gerar_hash_senha(senha)

    assert senha_hash != senha
    assert verificar_senha(senha, senha_hash)
    assert not verificar_senha("senha-incorreta", senha_hash)


def test_access_token_identifica_usuario() -> None:
    usuario_id = uuid4()
    token, expires_in = criar_access_token(usuario_id)

    assert decodificar_access_token(token) == str(usuario_id)
    assert expires_in > 0


def test_token_invalido_e_rejeitado() -> None:
    with pytest.raises(TokenInvalido):
        decodificar_access_token("nao-e-um-jwt")


def test_refresh_token_e_armazenado_apenas_como_hash() -> None:
    token, token_hash = criar_refresh_token()

    assert token != token_hash
    assert hash_refresh_token(token) == token_hash
    assert len(token_hash) == 64

