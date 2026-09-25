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


def test_perfil_mostra_equipe_publica_sem_expor_equipe_privada(client: TestClient) -> None:
    owner = _register(client, "perfil.team.owner")
    visitor = _register(client, "perfil.team.visitor")
    owner_id = owner["usuario"]["id"]
    url = f"/api/v1/usuarios/{owner_id}"
    assert client.get(url, headers=_headers(visitor)).json()["equipe_atual"] is None

    team = client.post("/api/v1/equipes", headers=_headers(owner), json={
        "nome": "Clássicos ES",
        "visibilidade": "publica",
    }).json()
    public = client.get(url, headers=_headers(visitor)).json()
    assert public["equipe_atual"] == {
        "id": team["id"], "nome": "Clássicos ES", "avatar_url": None,
    }
    block_url = f"/api/v1/usuarios/{owner_id}/bloqueio"
    assert client.put(block_url, headers=_headers(visitor)).status_code == 204
    assert client.get(url, headers=_headers(visitor)).json()["equipe_atual"] is None
    assert client.delete(block_url, headers=_headers(visitor)).status_code == 204

    assert client.patch(f"/api/v1/equipes/{team['id']}", headers=_headers(owner), json={
        "nome": "Clássicos ES", "visibilidade": "privada",
    }).status_code == 200
    assert client.get(url, headers=_headers(visitor)).json()["equipe_atual"] is None
    assert client.get(url, headers=_headers(owner)).json()["equipe_atual"]["id"] == team["id"]
