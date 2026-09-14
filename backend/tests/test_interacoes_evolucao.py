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


def test_curtidas_e_comentarios_da_evolucao(client: TestClient) -> None:
    dono = cadastrar(client, "dono.social")
    visitante = cadastrar(client, "visitante.social")
    outro = cadastrar(client, "outro.social")

    carro_response = client.post(
        "/api/v1/carros",
        headers=auth_header(dono),
        json={"modelo": "Omega CD 4.1", "ano": 1996},
    )
    assert carro_response.status_code == 201
    carro = carro_response.json()

    diario_url = f"/api/v1/carros/{carro['id']}/evolucoes"
    evolucao_response = client.post(
        diario_url,
        headers=auth_header(dono),
        json={
            "titulo": "Motor montado",
            "descricao": "Primeira partida depois da montagem.",
        },
    )
    assert evolucao_response.status_code == 201
    evolucao = evolucao_response.json()
    base = f"{diario_url}/{evolucao['id']}"

    assert client.get(f"{base}/interacoes").status_code == 401

    curtida_url = f"{base}/curtida"
    assert client.put(curtida_url, headers=auth_header(visitante)).status_code == 204
    assert client.put(curtida_url, headers=auth_header(visitante)).status_code == 204

    interacoes = client.get(
        f"{base}/interacoes",
        headers=auth_header(visitante),
    )
    assert interacoes.status_code == 200
    assert interacoes.json()["total_curtidas"] == 1
    assert interacoes.json()["curtido_por_mim"] is True
    assert interacoes.json()["comentarios"] == []

    comentario_response = client.post(
        f"{base}/comentarios",
        headers=auth_header(visitante),
        json={"conteudo": "  Ficou muito bom!  "},
    )
    assert comentario_response.status_code == 201
    comentario = comentario_response.json()
    assert comentario["conteudo"] == "Ficou muito bom!"
    assert comentario["autor"]["username"] == "visitante.social"

    interacoes_dono = client.get(
        f"{base}/interacoes",
        headers=auth_header(dono),
    ).json()
    assert interacoes_dono["total_curtidas"] == 1
    assert interacoes_dono["curtido_por_mim"] is False
    assert [item["id"] for item in interacoes_dono["comentarios"]] == [
        comentario["id"]
    ]

    comentario_url = f"{base}/comentarios/{comentario['id']}"
    assert (
        client.delete(comentario_url, headers=auth_header(outro)).status_code == 404
    )
    assert (
        client.delete(comentario_url, headers=auth_header(visitante)).status_code
        == 204
    )
    assert client.delete(curtida_url, headers=auth_header(visitante)).status_code == 204
    assert client.delete(curtida_url, headers=auth_header(visitante)).status_code == 204

    finais = client.get(
        f"{base}/interacoes",
        headers=auth_header(visitante),
    ).json()
    assert finais["total_curtidas"] == 0
    assert finais["curtido_por_mim"] is False
    assert finais["comentarios"] == []
