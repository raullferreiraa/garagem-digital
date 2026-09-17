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


def equipe_com_membro(client: TestClient) -> tuple[dict, dict, dict]:
    dono = cadastrar(client, "dono.membros")
    membro = cadastrar(client, "membro.removivel")
    equipe = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Equipe de Membros"},
    ).json()
    client.post(
        f"/api/v1/equipes/{equipe['id']}/convites",
        headers=auth(dono),
        json={"usuario_id": membro["usuario"]["id"]},
    )
    client.patch(
        f"/api/v1/equipes/{equipe['id']}/meu-convite",
        headers=auth(membro),
        json={"decisao": "aceitar"},
    )
    return dono, membro, equipe


def test_dono_remove_integrante(client: TestClient) -> None:
    dono, membro, equipe = equipe_com_membro(client)
    resposta = client.delete(
        f"/api/v1/equipes/{equipe['id']}/membros/{membro['usuario']['id']}",
        headers=auth(dono),
    )
    assert resposta.status_code == 204
    detalhe = client.get(
        f"/api/v1/equipes/{equipe['id']}",
        headers=auth(dono),
    ).json()
    assert detalhe["total_membros"] == 1


def test_integrante_sai_da_equipe(client: TestClient) -> None:
    dono, membro, equipe = equipe_com_membro(client)
    resposta = client.delete(
        f"/api/v1/equipes/{equipe['id']}/membros/{membro['usuario']['id']}",
        headers=auth(membro),
    )
    assert resposta.status_code == 204


def test_dono_nao_pode_ser_removido(client: TestClient) -> None:
    dono, _, equipe = equipe_com_membro(client)
    resposta = client.delete(
        f"/api/v1/equipes/{equipe['id']}/membros/{dono['usuario']['id']}",
        headers=auth(dono),
    )
    assert resposta.status_code == 409
