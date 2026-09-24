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


def test_alterar_senha_renova_sessao_e_revoga_as_anteriores(
    client: TestClient,
) -> None:
    cadastro = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": "Raul Ferreira",
            "username": "raul.senha",
            "email": "raul.senha@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert cadastro.status_code == 201
    sessao_inicial = cadastro.json()

    outra_sessao = client.post(
        "/api/v1/auth/login",
        json={
            "identificador": "raul.senha",
            "senha": "senha-segura-123",
        },
    )
    assert outra_sessao.status_code == 200

    alteracao = client.post(
        "/api/v1/auth/alterar-senha",
        headers={
            "Authorization": f"Bearer {sessao_inicial['access_token']}",
        },
        json={
            "senha_atual": "senha-segura-123",
            "nova_senha": "uma-senha-nova-456",
        },
    )
    assert alteracao.status_code == 200
    nova_sessao = alteracao.json()
    assert nova_sessao["refresh_token"] != sessao_inicial["refresh_token"]

    for sessao in (sessao_inicial, outra_sessao.json()):
        assert client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {sessao['access_token']}"},
        ).status_code == 401
        resposta = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": sessao["refresh_token"]},
        )
        assert resposta.status_code == 401

    refresh_atual = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": nova_sessao["refresh_token"]},
    )
    assert refresh_atual.status_code == 200
    assert client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {nova_sessao['access_token']}"},
    ).status_code == 200

    login_antigo = client.post(
        "/api/v1/auth/login",
        json={
            "identificador": "raul.senha",
            "senha": "senha-segura-123",
        },
    )
    assert login_antigo.status_code == 401

    login_novo = client.post(
        "/api/v1/auth/login",
        json={
            "identificador": "raul.senha",
            "senha": "uma-senha-nova-456",
        },
    )
    assert login_novo.status_code == 200


def test_alterar_senha_exige_senha_atual_e_senha_diferente(
    client: TestClient,
) -> None:
    cadastro = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": "Piloto Seguro",
            "username": "piloto.seguro",
            "email": "piloto.seguro@example.com",
            "senha": "senha-segura-123",
        },
    ).json()
    headers = {"Authorization": f"Bearer {cadastro['access_token']}"}

    incorreta = client.post(
        "/api/v1/auth/alterar-senha",
        headers=headers,
        json={
            "senha_atual": "senha-incorreta",
            "nova_senha": "uma-senha-nova-456",
        },
    )
    assert incorreta.status_code == 400
    assert incorreta.json() == {"detail": "A senha atual está incorreta."}

    repetida = client.post(
        "/api/v1/auth/alterar-senha",
        headers=headers,
        json={
            "senha_atual": "senha-segura-123",
            "nova_senha": "senha-segura-123",
        },
    )
    assert repetida.status_code == 422
    assert repetida.json() == {
        "detail": "A nova senha deve ser diferente da atual."
    }
