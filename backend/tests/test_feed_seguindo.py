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


def auth(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def criar_evolucao(
    client: TestClient,
    tokens: dict[str, object],
    modelo: str,
    titulo: str,
) -> dict[str, object]:
    carro = client.post(
        "/api/v1/carros",
        headers=auth(tokens),
        json={"modelo": modelo},
    )
    assert carro.status_code == 201
    evolucao = client.post(
        f"/api/v1/carros/{carro.json()['id']}/evolucoes",
        headers=auth(tokens),
        json={"titulo": titulo, "descricao": f"Atualização de {modelo}"},
    )
    assert evolucao.status_code == 201
    return evolucao.json()


def test_feed_seguindo_mostra_apenas_evolucoes_acompanhadas(
    client: TestClient,
) -> None:
    leitor = cadastrar(client, "leitor.feed")
    seguido = cadastrar(client, "seguido.feed")
    desconhecido = cadastrar(client, "desconhecido.feed")

    esperada = criar_evolucao(client, seguido, "Omega", "Motor montado")
    criar_evolucao(client, desconhecido, "Fusca", "Pintura concluída")

    seguir = client.put(
        f"/api/v1/usuarios/{seguido['usuario']['id']}/seguir",
        headers=auth(leitor),
    )
    assert seguir.status_code == 204

    response = client.get("/api/v1/feed/seguindo", headers=auth(leitor))
    assert response.status_code == 200
    itens = response.json()
    assert len(itens) == 1
    assert itens[0]["evolucao"]["id"] == esperada["id"]
    assert itens[0]["evolucao"]["titulo"] == "Motor montado"
    assert itens[0]["carro"]["modelo"] == "Omega"


def test_feed_seguindo_vazio_sem_perfis_acompanhados(
    client: TestClient,
) -> None:
    leitor = cadastrar(client, "sem.seguidos")
    response = client.get("/api/v1/feed/seguindo", headers=auth(leitor))
    assert response.status_code == 200
    assert response.json() == []
