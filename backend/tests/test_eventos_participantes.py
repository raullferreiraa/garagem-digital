from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient


def _register(client: TestClient, username: str) -> dict:
    response = client.post("/api/v1/auth/cadastro", json={
        "nome": username,
        "username": username,
        "email": f"{username}@example.com",
        "senha": "senha-segura-123",
    })
    assert response.status_code == 201
    return response.json()


def _headers(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_edicao_lista_confirmados_carros_e_equipes(client: TestClient) -> None:
    owner = _register(client, "lista.owner")
    visitor = _register(client, "lista.visitor")
    start = datetime.now(timezone.utc) + timedelta(days=7)
    community = client.post("/api/v1/eventos", headers=_headers(owner), json={
        "nome": "Clássicos da região",
        "proxima_edicao": {"inicio": start.isoformat()},
    }).json()
    base = f"/api/v1/eventos/{community['id']}"
    edition_id = community["edicao_id"]
    url = f"{base}/edicoes/{edition_id}/participantes"
    assert client.get(url, headers=_headers(visitor)).json() == {
        "pessoas": [], "equipes": [], "total_pessoas": 0, "total_equipes": 0,
    }

    car = client.post("/api/v1/carros", headers=_headers(visitor), json={
        "modelo": "Fusca 1300", "ano": 1975,
    }).json()
    confirmed = client.put(
        f"{base}/minha-presenca", headers=_headers(visitor),
        params={"edicao_id": edition_id},
        json={"status": "confirmada", "carro_id": car["id"]},
    )
    assert confirmed.status_code == 200
    team = client.post("/api/v1/equipes", headers=_headers(owner), json={
        "nome": "Antigos ES"
    }).json()
    assert client.put(
        f"{base}/minha-equipe", headers=_headers(owner),
        params={"edicao_id": edition_id}, json={"status": "confirmada"},
    ).status_code == 200

    response = client.get(url, headers=_headers(visitor))
    assert response.status_code == 200
    participants = response.json()
    assert len(participants["pessoas"]) == 1
    assert participants["pessoas"][0]["usuario"]["id"] == visitor["usuario"]["id"]
    assert participants["pessoas"][0]["carro"]["id"] == car["id"]
    assert participants["pessoas"][0]["carro"]["modelo"] == "FUSCA 1300"
    assert participants["equipes"] == []
    assert participants["total_pessoas"] == 1
    assert participants["total_equipes"] == 1
    teams_page = client.get(url, headers=_headers(visitor), params={"tipo": "equipes"}).json()
    assert teams_page["pessoas"] == []
    assert teams_page["equipes"][0]["id"] == team["id"]
    assert client.get(url, headers=_headers(visitor), params={"offset": 1}).json()["pessoas"] == []

    assert client.put(
        f"/api/v1/usuarios/{visitor['usuario']['id']}/bloqueio",
        headers=_headers(owner),
    ).status_code == 204
    assert client.get(url, headers=_headers(owner)).json()["pessoas"] == []
    assert client.delete(
        f"/api/v1/usuarios/{visitor['usuario']['id']}/bloqueio",
        headers=_headers(owner),
    ).status_code == 204

    other = client.post("/api/v1/eventos", headers=_headers(owner), json={
        "nome": "Outro encontro", "proxima_edicao": {"inicio": start.isoformat()}
    }).json()
    assert client.get(
        f"/api/v1/eventos/{other['id']}/edicoes/{edition_id}/participantes",
        headers=_headers(visitor),
    ).status_code == 404

    assert client.delete(
        f"{base}/minha-presenca", headers=_headers(visitor),
        params={"edicao_id": edition_id},
    ).status_code == 200
    assert client.get(url, headers=_headers(visitor)).json()["pessoas"] == []
