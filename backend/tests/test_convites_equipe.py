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


def test_fluxo_de_convite_para_equipe_privada(client: TestClient) -> None:
    dono = cadastrar(client, "dono.convite")
    convidado = cadastrar(client, "pessoa.convidada")
    intruso = cadastrar(client, "gestor.falso")
    equipe = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Equipe Fechada", "visibilidade": "privada"},
    ).json()

    proibido = client.post(
        f"/api/v1/equipes/{equipe['id']}/convites",
        headers=auth(intruso),
        json={"usuario_id": convidado["usuario"]["id"]},
    )
    assert proibido.status_code == 403
    enviado = client.post(
        f"/api/v1/equipes/{equipe['id']}/convites",
        headers=auth(dono),
        json={"usuario_id": convidado["usuario"]["id"]},
    )
    assert enviado.status_code == 204
    repetido = client.post(
        f"/api/v1/equipes/{equipe['id']}/convites",
        headers=auth(dono),
        json={"usuario_id": convidado["usuario"]["id"]},
    )
    assert repetido.status_code == 409

    equipes = client.get("/api/v1/equipes", headers=auth(convidado)).json()
    resumo = next(item for item in equipes if item["id"] == equipe["id"])
    assert resumo["meu_convite"] == "pendente"
    detalhe = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(convidado)
    )
    assert detalhe.status_code == 200

    resposta = client.patch(
        f"/api/v1/equipes/{equipe['id']}/meu-convite",
        headers=auth(convidado),
        json={"decisao": "aceitar"},
    )
    assert resposta.status_code == 204
    detalhe_membro = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(convidado)
    ).json()
    assert detalhe_membro["meu_papel"] == "membro"
    assert detalhe_membro["meu_convite"] == "aceito"


def test_usuario_pode_recusar_convite(client: TestClient) -> None:
    dono = cadastrar(client, "dono.recusa")
    convidado = cadastrar(client, "pessoa.recusa")
    equipe = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Equipe Publica"},
    ).json()
    client.post(
        f"/api/v1/equipes/{equipe['id']}/convites",
        headers=auth(dono),
        json={"usuario_id": convidado["usuario"]["id"]},
    )
    resposta = client.patch(
        f"/api/v1/equipes/{equipe['id']}/meu-convite",
        headers=auth(convidado),
        json={"decisao": "recusar"},
    )
    assert resposta.status_code == 204
    detalhe = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(convidado)
    ).json()
    assert detalhe["meu_convite"] == "recusado"
