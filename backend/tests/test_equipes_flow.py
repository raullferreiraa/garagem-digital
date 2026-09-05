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


def criar_carro(client: TestClient, tokens: dict[str, object], modelo: str) -> dict:
    response = client.post(
        "/api/v1/carros", headers=auth(tokens), json={"modelo": modelo}
    )
    assert response.status_code == 201
    return response.json()


def test_fluxo_de_equipe_pedido_e_carro_escolhido(client: TestClient) -> None:
    dono = cadastrar(client, "dono.equipe")
    membro = cadastrar(client, "novo.membro")
    intruso = cadastrar(client, "pessoa.fora")
    carro_um = criar_carro(client, membro, "Omega")
    carro_dois = criar_carro(client, membro, "Opala")
    carro_intruso = criar_carro(client, intruso, "Gol")

    criada = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Equipe Omega ES", "cidade": "Vila Velha", "estado": "ES"},
    )
    assert criada.status_code == 201
    equipe = criada.json()
    assert equipe["slug"] == "equipe-omega-es"
    assert equipe["meu_papel"] == "dono"
    assert equipe["total_membros"] == 1

    pedido = client.post(
        f"/api/v1/equipes/{equipe['id']}/solicitacoes", headers=auth(membro)
    )
    assert pedido.status_code == 204
    assert pedido.content == b""

    repetido = client.post(
        f"/api/v1/equipes/{equipe['id']}/solicitacoes", headers=auth(membro)
    )
    assert repetido.status_code == 409

    detalhe_dono = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(dono)
    ).json()
    assert len(detalhe_dono["solicitacoes_pendentes"]) == 1
    solicitacao_id = detalhe_dono["solicitacoes_pendentes"][0]["id"]

    proibida = client.patch(
        f"/api/v1/equipes/{equipe['id']}/solicitacoes/{solicitacao_id}",
        headers=auth(intruso),
        json={"decisao": "aprovar"},
    )
    assert proibida.status_code == 403

    aprovada = client.patch(
        f"/api/v1/equipes/{equipe['id']}/solicitacoes/{solicitacao_id}",
        headers=auth(dono),
        json={"decisao": "aprovar"},
    )
    assert aprovada.status_code == 204

    escolhido = client.put(
        f"/api/v1/equipes/{equipe['id']}/meu-carro",
        headers=auth(membro),
        json={"carro_id": carro_um["id"]},
    )
    assert escolhido.status_code == 204

    trocado = client.put(
        f"/api/v1/equipes/{equipe['id']}/meu-carro",
        headers=auth(membro),
        json={"carro_id": carro_dois["id"]},
    )
    assert trocado.status_code == 204
    detalhe = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(membro)
    ).json()
    assert detalhe["total_membros"] == 2
    assert detalhe["meu_papel"] == "membro"
    assert [carro["id"] for carro in detalhe["carros"]] == [carro_dois["id"]]

    carro_de_outro = client.put(
        f"/api/v1/equipes/{equipe['id']}/meu-carro",
        headers=auth(membro),
        json={"carro_id": carro_intruso["id"]},
    )
    assert carro_de_outro.status_code == 403

    removido = client.delete(
        f"/api/v1/equipes/{equipe['id']}/meu-carro", headers=auth(membro)
    )
    assert removido.status_code == 204
    detalhe_sem_carro = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(membro)
    ).json()
    assert detalhe_sem_carro["carros"] == []
