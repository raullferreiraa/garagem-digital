from io import BytesIO

from fastapi.testclient import TestClient
from PIL import Image


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


def criar_carro(client: TestClient, tokens: dict[str, object]) -> dict[str, object]:
    response = client.post(
        "/api/v1/carros",
        headers=auth_header(tokens),
        json={"modelo": "Omega CD 4.1", "ano": 1996},
    )
    assert response.status_code == 201
    return response.json()


def imagem_png(cor: str = "blue") -> bytes:
    conteudo = BytesIO()
    Image.new("RGB", (120, 80), cor).save(conteudo, format="PNG")
    return conteudo.getvalue()


def test_diario_publico_e_mutacoes_exclusivas_do_dono(client: TestClient) -> None:
    dono = cadastrar(client, "dono.diario")
    intruso = cadastrar(client, "outro.diario")
    carro = criar_carro(client, dono)
    endpoint = f"/api/v1/carros/{carro['id']}/evolucoes"
    dados = {
        "titulo": "Primeira revisao",
        "descricao": "Troca de oleo e filtros.",
        "categoria": "manutencao",
        "ocorreu_em": "2026-09-05T12:00:00Z",
        "quilometragem_km": 185000,
    }

    assert client.post(endpoint, json=dados).status_code == 401
    assert (
        client.post(endpoint, headers=auth_header(intruso), json=dados).status_code
        == 404
    )

    criado = client.post(endpoint, headers=auth_header(dono), json=dados)
    assert criado.status_code == 201
    evolucao = criado.json()
    assert evolucao["titulo"] == "Primeira revisao"
    assert evolucao["quilometragem_km"] == 185000
    assert evolucao["autor"]["username"] == "dono.diario"
    assert evolucao["fotos"] == []

    diario_publico = client.get(endpoint)
    assert diario_publico.status_code == 200
    assert [item["id"] for item in diario_publico.json()] == [evolucao["id"]]

    item_endpoint = f"{endpoint}/{evolucao['id']}"
    bloqueado = client.patch(
        item_endpoint,
        headers=auth_header(intruso),
        json={"titulo": "Alteracao indevida"},
    )
    assert bloqueado.status_code == 404

    atualizado = client.patch(
        item_endpoint,
        headers=auth_header(dono),
        json={"titulo": "Revisao concluida", "quilometragem_km": 185100},
    )
    assert atualizado.status_code == 200
    assert atualizado.json()["titulo"] == "Revisao concluida"
    assert atualizado.json()["quilometragem_km"] == 185100

    assert (
        client.delete(item_endpoint, headers=auth_header(intruso)).status_code == 404
    )
    assert client.delete(item_endpoint, headers=auth_header(dono)).status_code == 204
    assert client.get(endpoint).json() == []


def test_galeria_da_evolucao_e_publica_e_exclusiva_do_dono(
    client: TestClient,
) -> None:
    dono = cadastrar(client, "fotos.diario")
    intruso = cadastrar(client, "fotos.intruso")
    carro = criar_carro(client, dono)
    diario_url = f"/api/v1/carros/{carro['id']}/evolucoes"
    evolucao = client.post(
        diario_url,
        headers=auth_header(dono),
        json={
            "titulo": "Suspensao nova",
            "descricao": "Antes e depois da instalacao.",
        },
    ).json()
    fotos_url = f"{diario_url}/{evolucao['id']}/fotos"

    assert (
        client.post(
            fotos_url,
            files={"arquivo": ("foto.png", imagem_png(), "image/png")},
        ).status_code
        == 401
    )
    assert (
        client.post(
            fotos_url,
            headers=auth_header(intruso),
            files={"arquivo": ("foto.png", imagem_png(), "image/png")},
        ).status_code
        == 404
    )
    assert (
        client.post(
            fotos_url,
            headers=auth_header(dono),
            files={"arquivo": ("foto.jpg", b"invalida", "image/jpeg")},
        ).status_code
        == 415
    )

    primeira = client.post(
        fotos_url,
        headers=auth_header(dono),
        files={"arquivo": ("antes.png", imagem_png("blue"), "image/png")},
    )
    segunda = client.post(
        fotos_url,
        headers=auth_header(dono),
        files={"arquivo": ("depois.png", imagem_png("red"), "image/png")},
    )
    assert primeira.status_code == 200
    assert segunda.status_code == 200
    fotos = segunda.json()["fotos"]
    assert len(fotos) == 2
    assert all(
        foto["url"].startswith(
            f"/media/carros/{carro['id']}/evolucoes/{evolucao['id']}/"
        )
        for foto in fotos
    )

    diario_publico = client.get(diario_url).json()
    assert [foto["id"] for foto in diario_publico[0]["fotos"]] == [
        foto["id"] for foto in fotos
    ]
    for foto in fotos:
        assert client.get(foto["url"]).status_code == 200

    exclusao_bloqueada = client.delete(
        f"{fotos_url}/{fotos[0]['id']}",
        headers=auth_header(intruso),
    )
    assert exclusao_bloqueada.status_code == 404

    removida = client.delete(
        f"{fotos_url}/{fotos[0]['id']}",
        headers=auth_header(dono),
    )
    assert removida.status_code == 200
    assert len(removida.json()["fotos"]) == 1
    assert client.get(fotos[0]["url"]).status_code == 404

    item_url = f"{diario_url}/{evolucao['id']}"
    assert client.delete(item_url, headers=auth_header(dono)).status_code == 204
    assert client.get(fotos[1]["url"]).status_code == 404
