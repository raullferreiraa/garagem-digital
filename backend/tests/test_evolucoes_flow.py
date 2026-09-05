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


def auth_header(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def criar_carro(client: TestClient, tokens: dict[str, object]) -> dict[str, object]:
    response = client.post(
        "/api/v1/carros",
        headers=auth_header(tokens),
        json={"modelo": "Omega CD 4.1", "ano": 1996},
    )
    assert response.status_code == 201
    return response.json()


def test_diario_publico_e_mutacoes_exclusivas_do_dono(client: TestClient) -> None:
    dono = cadastrar(client, "dono.diario")
    intruso = cadastrar(client, "outro.diario")
    carro = criar_carro(client, dono)
    endpoint = f"/api/v1/carros/{carro['id']}/evolucoes"
    dados = {
        "titulo": "Primeira revisao",
        "descricao": "Troca de oleo e filtros.",
        "categoria": "manutencao",
        "ocorreu_em": "2026-09-05T12:00:00Z",
        "quilometragem_km": 185000,
    }

    assert client.post(endpoint, json=dados).status_code == 401
    assert (
        client.post(endpoint, headers=auth_header(intruso), json=dados).status_code
        == 404
    )

    criado = client.post(endpoint, headers=auth_header(dono), json=dados)
    assert criado.status_code == 201
    evolucao = criado.json()
    assert evolucao["titulo"] == "Primeira revisao"
    assert evolucao["quilometragem_km"] == 185000
    assert evolucao["autor"]["username"] == "dono.diario"

    diario_publico = client.get(endpoint)
    assert diario_publico.status_code == 200
    assert [item["id"] for item in diario_publico.json()] == [evolucao["id"]]

    item_endpoint = f"{endpoint}/{evolucao['id']}"
    bloqueado = client.patch(
        item_endpoint,
        headers=auth_header(intruso),
        json={"titulo": "Alteracao indevida"},
    )
    assert bloqueado.status_code == 404

    atualizado = client.patch(
        item_endpoint,
        headers=auth_header(dono),
        json={"titulo": "Revisao concluida", "quilometragem_km": 185100},
    )
    assert atualizado.status_code == 200
    assert atualizado.json()["titulo"] == "Revisao concluida"
    assert atualizado.json()["quilometragem_km"] == 185100

    assert (
        client.delete(item_endpoint, headers=auth_header(intruso)).status_code == 404
    )
    assert client.delete(item_endpoint, headers=auth_header(dono)).status_code == 204
    assert client.get(endpoint).json() == []
