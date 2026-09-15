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


def criar_carro(
    client: TestClient,
    tokens: dict[str, object],
    modelo: str,
) -> dict[str, object]:
    response = client.post(
        "/api/v1/carros",
        headers=auth(tokens),
        json={"modelo": modelo},
    )
    assert response.status_code == 201
    return response.json()


def test_feed_em_alta_prioriza_projetos_com_interacoes(
    client: TestClient,
) -> None:
    dono_popular = cadastrar(client, "dono.popular")
    dono_recente = cadastrar(client, "dono.recente")
    visitante = cadastrar(client, "visitante.ranking")

    popular = criar_carro(client, dono_popular, "Omega Popular")
    criar_carro(client, dono_recente, "Projeto Sem Interacoes")

    diario = f"/api/v1/carros/{popular['id']}/evolucoes"
    evolucao_response = client.post(
        diario,
        headers=auth(dono_popular),
        json={
            "titulo": "Motor finalizado",
            "descricao": "Projeto pronto para a primeira partida.",
        },
    )
    assert evolucao_response.status_code == 201
    evolucao = evolucao_response.json()
    base = f"{diario}/{evolucao['id']}"

    assert client.put(
        f"{base}/curtida",
        headers=auth(visitante),
    ).status_code == 204
    assert client.post(
        f"{base}/comentarios",
        headers=auth(visitante),
        json={"conteudo": "Ficou muito bom!"},
    ).status_code == 201

    response = client.get("/api/v1/carros?ordem=em_alta")
    assert response.status_code == 200
    itens = response.json()["itens"]
    assert itens[0]["id"] == popular["id"]
    assert itens[0]["total_curtidas"] == 1
    assert itens[0]["total_comentarios"] == 1


def test_feed_rejeita_ordem_desconhecida(client: TestClient) -> None:
    response = client.get("/api/v1/carros?ordem=aleatoria")
    assert response.status_code == 422
