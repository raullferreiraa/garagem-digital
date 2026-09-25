from fastapi.testclient import TestClient

def cadastrar(client: TestClient, username: str) -> dict[str, object]:
    resposta = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": username.title(),
            "username": username,
            "email": f"{username}@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


def auth_header(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def _criar_carro(client: TestClient, dono: dict[str, object], modelo: str) -> str:
    resposta = client.post(
        "/api/v1/carros", headers=auth_header(dono), json={"modelo": modelo}
    )
    assert resposta.status_code == 201
    return resposta.json()["id"]


def test_salvar_listar_e_remover_projetos(client: TestClient) -> None:
    dono = cadastrar(client, "dono.salvos")
    visitante = cadastrar(client, "visita.salvos")
    carro_id = _criar_carro(client, dono, "Opala")
    caminho = f"/api/v1/carros/{carro_id}/salvo"
    cabecalho = auth_header(visitante)

    assert client.get("/api/v1/carros/salvos").status_code == 401
    assert client.put(caminho).status_code == 401
    assert client.get(caminho, headers=cabecalho).json() == {"salvo": False}
    assert client.put(caminho, headers=cabecalho).status_code == 204
    assert client.put(caminho, headers=cabecalho).status_code == 204
    assert client.get(caminho, headers=cabecalho).json() == {"salvo": True}

    pagina = client.get("/api/v1/carros/salvos", headers=cabecalho)
    assert pagina.status_code == 200
    assert [item["id"] for item in pagina.json()["itens"]] == [carro_id]
    assert pagina.json()["itens"][0]["modelo"] == "OPALA"
    assert pagina.json()["proximo_cursor"] is None

    assert client.delete(caminho, headers=cabecalho).status_code == 204
    assert client.delete(caminho, headers=cabecalho).status_code == 204
    assert client.get("/api/v1/carros/salvos", headers=cabecalho).json()["itens"] == []


def test_salvos_paginam_e_somem_ao_excluir_carro(client: TestClient) -> None:
    dono = cadastrar(client, "dono.pagina")
    visitante = cadastrar(client, "visita.pagina")
    cabecalho = auth_header(visitante)
    ids = [_criar_carro(client, dono, f"Carro {numero}") for numero in range(3)]
    for carro_id in ids:
        assert client.put(f"/api/v1/carros/{carro_id}/salvo", headers=cabecalho).status_code == 204

    primeira = client.get("/api/v1/carros/salvos?limite=2", headers=cabecalho).json()
    assert len(primeira["itens"]) == 2
    assert primeira["proximo_cursor"] is not None
    segunda = client.get(
        "/api/v1/carros/salvos",
        headers=cabecalho,
        params={"limite": 2, "cursor": primeira["proximo_cursor"]},
    ).json()
    assert len(segunda["itens"]) == 1
    assert {item["id"] for item in primeira["itens"] + segunda["itens"]} == set(ids)
    assert client.get(
        "/api/v1/carros/salvos", headers=cabecalho, params={"cursor": "invalido"}
    ).status_code == 400

    assert client.delete(f"/api/v1/carros/{ids[0]}", headers=auth_header(dono)).status_code == 204
    restantes = client.get("/api/v1/carros/salvos", headers=cabecalho).json()["itens"]
    assert {item["id"] for item in restantes} == set(ids[1:])


def test_bloqueio_oculta_projetos_salvos(client: TestClient) -> None:
    dono = cadastrar(client, "dono.bloq.salvos")
    visitante = cadastrar(client, "visita.bloq.salvos")
    carro_id = _criar_carro(client, dono, "Chevette")
    cabecalho = auth_header(visitante)
    caminho = f"/api/v1/carros/{carro_id}/salvo"
    assert client.put(caminho, headers=cabecalho).status_code == 204

    bloqueio = client.put(
        f"/api/v1/usuarios/{dono['usuario']['id']}/bloqueio", headers=cabecalho
    )
    assert bloqueio.status_code == 204
    assert client.get("/api/v1/carros/salvos", headers=cabecalho).json()["itens"] == []
    assert client.get(caminho, headers=cabecalho).status_code == 404
    assert client.put(caminho, headers=cabecalho).status_code == 404
