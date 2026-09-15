from fastapi.testclient import TestClient


def cadastrar(client: TestClient, username: str) -> dict[str, object]:
    response = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": username.title(),
            "username": username,
            "email": f"{username}@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert response.status_code == 201
    return response.json()


def auth_header(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_central_de_notificacoes(client: TestClient) -> None:
    dono = cadastrar(client, "donoavisos")
    visitante = cadastrar(client, "visitanteavisos")

    perfil_dono = client.get(
        "/api/v1/auth/me",
        headers=auth_header(dono),
    ).json()
    perfil_visitante = client.get(
        "/api/v1/auth/me",
        headers=auth_header(visitante),
    ).json()

    seguir = client.put(
        f"/api/v1/usuarios/{perfil_dono['id']}/seguir",
        headers=auth_header(visitante),
    )
    assert seguir.status_code == 204

    avisos_dono = client.get(
        "/api/v1/notificacoes",
        headers=auth_header(dono),
    )
    assert avisos_dono.status_code == 200
    novo_seguidor = avisos_dono.json()[0]
    assert novo_seguidor["tipo"] == "novo_seguidor"
    assert novo_seguidor["ator"]["id"] == perfil_visitante["id"]
    assert novo_seguidor["lida_em"] is None

    total = client.get(
        "/api/v1/notificacoes/nao-lidas",
        headers=auth_header(dono),
    ).json()
    assert total["total"] == 1
    assert (
        client.patch(
            f"/api/v1/notificacoes/{novo_seguidor['id']}/lida",
            headers=auth_header(visitante),
        ).status_code
        == 404
    )
    lida = client.patch(
        f"/api/v1/notificacoes/{novo_seguidor['id']}/lida",
        headers=auth_header(dono),
    )
    assert lida.status_code == 200
    assert lida.json()["lida_em"] is not None

    carro = client.post(
        "/api/v1/carros",
        headers=auth_header(dono),
        json={"modelo": "Omega CD 4.1", "ano": 1996},
    ).json()
    evolucao = client.post(
        f"/api/v1/carros/{carro['id']}/evolucoes",
        headers=auth_header(dono),
        json={
            "titulo": "Primeira partida",
            "descricao": "Motor funcionando.",
        },
    ).json()
    base = f"/api/v1/carros/{carro['id']}/evolucoes/{evolucao['id']}"
    comentario = client.post(
        f"{base}/comentarios",
        headers=auth_header(visitante),
        json={"conteudo": "Ficou ótimo!"},
    ).json()

    tipos_dono = [
        item["tipo"]
        for item in client.get(
            "/api/v1/notificacoes",
            headers=auth_header(dono),
        ).json()
    ]
    assert tipos_dono[:2] == ["comentario_evolucao", "novo_seguidor"]

    resposta = client.post(
        f"{base}/comentarios/{comentario['id']}/respostas",
        headers=auth_header(dono),
        json={"conteudo": "Valeu!"},
    )
    assert resposta.status_code == 201
    tipos_visitante = [
        item["tipo"]
        for item in client.get(
            "/api/v1/notificacoes",
            headers=auth_header(visitante),
        ).json()
    ]
    assert tipos_visitante == ["resposta_comentario"]

    equipe = client.post(
        "/api/v1/equipes",
        headers=auth_header(dono),
        json={"nome": "Clássicos da Cidade"},
    ).json()
    assert (
        client.post(
            f"/api/v1/equipes/{equipe['id']}/solicitacoes",
            headers=auth_header(visitante),
        ).status_code
        == 204
    )
    detalhes = client.get(
        f"/api/v1/equipes/{equipe['id']}",
        headers=auth_header(dono),
    ).json()
    solicitacao_id = detalhes["solicitacoes_pendentes"][0]["id"]
    assert (
        client.patch(
            f"/api/v1/equipes/{equipe['id']}/solicitacoes/{solicitacao_id}",
            headers=auth_header(dono),
            json={"decisao": "aprovar"},
        ).status_code
        == 204
    )

    tipos_visitante = [
        item["tipo"]
        for item in client.get(
            "/api/v1/notificacoes",
            headers=auth_header(visitante),
        ).json()
    ]
    assert tipos_visitante[:2] == [
        "solicitacao_equipe_aprovada",
        "resposta_comentario",
    ]

    assert (
        client.post(
            "/api/v1/notificacoes/lidas",
            headers=auth_header(visitante),
        ).status_code
        == 204
    )
    total_final = client.get(
        "/api/v1/notificacoes/nao-lidas",
        headers=auth_header(visitante),
    ).json()
    assert total_final["total"] == 0
