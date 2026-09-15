from fastapi.testclient import TestClient


def cadastrar(client: TestClient, username: str) -> dict[str, object]:
    response = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": username.replace(".", " ").title(),
            "username": username,
            "email": f"{username}@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert response.status_code == 201
    return response.json()


def auth(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_dono_altera_cargo_de_integrante(client: TestClient) -> None:
    dono = cadastrar(client, "dono.cargos")
    membro = cadastrar(client, "membro.cargos")
    intruso = cadastrar(client, "intruso.cargos")
    equipe = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Equipe com Cargos"},
    ).json()
    equipe_id = equipe["id"]
    membro_id = membro["usuario"]["id"]

    client.post(
        f"/api/v1/equipes/{equipe_id}/convites",
        headers=auth(dono),
        json={"usuario_id": membro_id},
    )
    client.patch(
        f"/api/v1/equipes/{equipe_id}/meu-convite",
        headers=auth(membro),
        json={"decisao": "aceitar"},
    )

    proibido = client.patch(
        f"/api/v1/equipes/{equipe_id}/membros/{membro_id}/papel",
        headers=auth(intruso),
        json={"papel": "administrador"},
    )
    assert proibido.status_code == 403

    atualizado = client.patch(
        f"/api/v1/equipes/{equipe_id}/membros/{membro_id}/papel",
        headers=auth(dono),
        json={"papel": "administrador"},
    )
    assert atualizado.status_code == 204

    detalhe = client.get(
        f"/api/v1/equipes/{equipe_id}",
        headers=auth(dono),
    ).json()
    papel = next(
        item["papel"]
        for item in detalhe["membros"]
        if item["usuario"]["id"] == membro_id
    )
    assert papel == "administrador"


def test_cargo_do_dono_nao_pode_ser_alterado(client: TestClient) -> None:
    dono = cadastrar(client, "dono.fixo")
    equipe = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Equipe do Dono"},
    ).json()
    resposta = client.patch(
        f"/api/v1/equipes/{equipe['id']}/membros/{dono['usuario']['id']}/papel",
        headers=auth(dono),
        json={"papel": "membro"},
    )
    assert resposta.status_code == 409
