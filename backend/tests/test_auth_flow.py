from fastapi.testclient import TestClient


def test_cadastro_login_e_usuario_atual(client: TestClient) -> None:
    cadastro = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": "Raul Ferreira",
            "username": "raul.ferreira",
            "email": "raul@example.com",
            "senha": "senha-segura-123",
        },
    )

    assert cadastro.status_code == 201
    tokens = cadastro.json()
    assert tokens["token_type"] == "bearer"
    assert tokens["access_token"]
    assert tokens["refresh_token"]
    assert "senha" not in tokens["usuario"]

    usuario_atual = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )

    assert usuario_atual.status_code == 200
    assert usuario_atual.json()["username"] == "raul.ferreira"

    login = client.post(
        "/api/v1/auth/login",
        json={
            "identificador": "RAUL@EXAMPLE.COM",
            "senha": "senha-segura-123",
        },
    )

    assert login.status_code == 200
    assert login.json()["usuario"]["email"] == "raul@example.com"

    refresh = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )

    assert refresh.status_code == 200
    novos_tokens = refresh.json()
    assert novos_tokens["refresh_token"] != tokens["refresh_token"]

    reutilizacao = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert reutilizacao.status_code == 401

    logout = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": novos_tokens["refresh_token"]},
    )
    assert logout.status_code == 204

    apos_logout = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": novos_tokens["refresh_token"]},
    )
    assert apos_logout.status_code == 401


def test_cadastro_duplicado_e_credenciais_erradas(client: TestClient) -> None:
    dados = {
        "nome": "Usuario de Teste",
        "username": "usuario.teste",
        "email": "usuario@example.com",
        "senha": "senha-segura-123",
    }

    assert client.post("/api/v1/auth/cadastro", json=dados).status_code == 201
    assert client.post("/api/v1/auth/cadastro", json=dados).status_code == 409

    login = client.post(
        "/api/v1/auth/login",
        json={
            "identificador": dados["email"],
            "senha": "senha-incorreta",
        },
    )

    assert login.status_code == 401
    assert login.json() == {"detail": "Email, username ou senha incorretos."}
