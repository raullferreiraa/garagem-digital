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


def test_perfil_publico_e_fluxo_de_seguir(client: TestClient) -> None:
    raul = cadastrar(client, "raul.social")
    amigo = cadastrar(client, "amigo.social")
    raul_id = raul["usuario"]["id"]
    amigo_id = amigo["usuario"]["id"]

    carro = client.post(
        "/api/v1/carros",
        headers=auth(amigo),
        json={"modelo": "Opala"},
    )
    assert carro.status_code == 201

    perfil_inicial = client.get(
        f"/api/v1/usuarios/{amigo_id}",
        headers=auth(raul),
    )
    assert perfil_inicial.status_code == 200
    assert perfil_inicial.json()["total_projetos"] == 1
    assert perfil_inicial.json()["total_seguidores"] == 0
    assert perfil_inicial.json()["seguido_por_mim"] is False

    seguido = client.put(
        f"/api/v1/usuarios/{amigo_id}/seguir",
        headers=auth(raul),
    )
    assert seguido.status_code == 204
    repetido = client.put(
        f"/api/v1/usuarios/{amigo_id}/seguir",
        headers=auth(raul),
    )
    assert repetido.status_code == 204

    perfil_seguido = client.get(
        f"/api/v1/usuarios/{amigo_id}",
        headers=auth(raul),
    ).json()
    assert perfil_seguido["total_seguidores"] == 1
    assert perfil_seguido["seguido_por_mim"] is True

    seguidores = client.get(
        f"/api/v1/usuarios/{amigo_id}/seguidores"
    )
    assert seguidores.status_code == 200
    assert [item["id"] for item in seguidores.json()] == [raul_id]

    seguindo = client.get(
        f"/api/v1/usuarios/{raul_id}/seguindo"
    )
    assert seguindo.status_code == 200
    assert [item["id"] for item in seguindo.json()] == [amigo_id]

    perfil_raul = client.get(
        f"/api/v1/usuarios/{raul_id}",
        headers=auth(raul),
    ).json()
    assert perfil_raul["total_seguindo"] == 1

    proprio = client.put(
        f"/api/v1/usuarios/{raul_id}/seguir",
        headers=auth(raul),
    )
    assert proprio.status_code == 400

    removido = client.delete(
        f"/api/v1/usuarios/{amigo_id}/seguir",
        headers=auth(raul),
    )
    assert removido.status_code == 204
    perfil_final = client.get(
        f"/api/v1/usuarios/{amigo_id}",
        headers=auth(raul),
    ).json()
    assert perfil_final["total_seguidores"] == 0
    assert perfil_final["seguido_por_mim"] is False
