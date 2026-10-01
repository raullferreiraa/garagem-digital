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


def _alerts(client: TestClient, tokens: dict) -> list[dict]:
    response = client.get("/api/v1/notificacoes", headers=_headers(tokens))
    assert response.status_code == 200
    return response.json()


def test_edicoes_avisam_seguidores_e_confirmados_sem_duplicar(client: TestClient) -> None:
    owner = _register(client, "avisos.owner")
    follower = _register(client, "avisos.follower")
    attendee = _register(client, "avisos.attendee")
    event = client.post(
        "/api/v1/eventos", headers=_headers(owner),
        json={"nome": "Encontro itinerante", "cidade": "Vila Velha", "estado": "ES"},
    ).json()
    base = f"/api/v1/eventos/{event['id']}"
    assert client.put(f"{base}/seguindo", headers=_headers(follower)).status_code == 200

    start = datetime.now(timezone.utc) + timedelta(days=7)
    edition = {"inicio": start.isoformat(), "endereco_publico": "Praça"}
    created = client.post(f"{base}/edicoes", headers=_headers(owner), json=edition)
    assert created.status_code == 201
    edition_id = created.json()["edicao_id"]
    assert [alert["tipo"] for alert in _alerts(client, follower)] == ["nova_edicao_encontro"]
    assert _alerts(client, follower)[0]["encontro_id"] == event["id"]
    assert _alerts(client, attendee) == []
    assert _alerts(client, owner) == []

    assert client.put(f"{base}/minha-presenca", headers=_headers(attendee), json={}).status_code == 200
    changed = {"inicio": (start + timedelta(hours=2)).isoformat(), "endereco_publico": "Autódromo"}
    assert client.patch(f"{base}/edicoes/{edition_id}", headers=_headers(owner), json=changed).status_code == 200
    assert _alerts(client, follower)[0]["tipo"] == "edicao_encontro_alterada"
    assert _alerts(client, attendee)[0]["tipo"] == "edicao_encontro_alterada"

    assert client.patch(f"{base}/edicoes/{edition_id}", headers=_headers(owner), json=changed).status_code == 200
    assert len(_alerts(client, follower)) == 2
    assert len(_alerts(client, attendee)) == 1

    assert client.post(f"{base}/edicoes/{edition_id}/cancelamento", headers=_headers(owner)).status_code == 200
    assert _alerts(client, follower)[0]["tipo"] == "edicao_encontro_cancelada"
    assert _alerts(client, attendee)[0]["tipo"] == "edicao_encontro_cancelada"
    assert client.post(f"{base}/edicoes/{edition_id}/cancelamento", headers=_headers(owner)).status_code == 200
    assert len(_alerts(client, follower)) == 3
    assert len(_alerts(client, attendee)) == 2
