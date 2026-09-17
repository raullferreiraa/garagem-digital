from io import BytesIO

from fastapi.testclient import TestClient
from PIL import Image


def cadastrar(client: TestClient, username: str) -> dict:
    response = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": username,
            "username": username,
            "email": f"{username}@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert response.status_code == 201
    return response.json()


def auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def imagem_png() -> bytes:
    conteudo = BytesIO()
    Image.new("RGB", (120, 80), "blue").save(conteudo, format="PNG")
    return conteudo.getvalue()


def test_imagens_de_equipe_respeitam_dono_e_atualizam_detalhe(
    client: TestClient,
) -> None:
    dono = cadastrar(client, "dono.imagens")
    visitante = cadastrar(client, "visitante.imagens")
    resposta = client.post(
        "/api/v1/equipes", headers=auth(dono), json={"nome": "Equipe Imagens"}
    )
    assert resposta.status_code == 201
    equipe_id = resposta.json()["id"]
    avatar = f"/api/v1/equipes/{equipe_id}/imagens/avatar"
    capa = f"/api/v1/equipes/{equipe_id}/imagens/capa"

    assert client.post(
        avatar, files={"arquivo": ("logo.png", imagem_png(), "image/png")}
    ).status_code == 401
    assert client.post(
        avatar,
        headers=auth(visitante),
        files={"arquivo": ("logo.png", imagem_png(), "image/png")},
    ).status_code == 403
    assert client.post(
        avatar,
        headers=auth(dono),
        files={"arquivo": ("logo.png", b"invalid image", "image/png")},
    ).status_code == 415

    primeiro = client.post(
        avatar,
        headers=auth(dono),
        files={"arquivo": ("logo.png", imagem_png(), "image/png")},
    )
    assert primeiro.status_code == 200
    antiga = primeiro.json()["avatar_url"]
    assert antiga.startswith(f"/media/equipes/{equipe_id}/avatar/")
    assert client.get(antiga).status_code == 200

    trocado = client.post(
        avatar,
        headers=auth(dono),
        files={"arquivo": ("logo.png", imagem_png(), "image/png")},
    )
    assert trocado.status_code == 200
    assert trocado.json()["avatar_url"] != antiga
    assert client.get(antiga).status_code == 404

    enviada = client.post(
        capa,
        headers=auth(dono),
        files={"arquivo": ("capa.png", imagem_png(), "image/png")},
    )
    assert enviada.status_code == 200
    capa_url = enviada.json()["capa_url"]
    assert capa_url.startswith(f"/media/equipes/{equipe_id}/capa/")
    assert enviada.json()["avatar_url"] == trocado.json()["avatar_url"]
    assert client.get(capa_url).status_code == 200

    resumo = client.get("/api/v1/equipes", headers=auth(dono)).json()
    equipe_resumo = next(item for item in resumo if item["id"] == equipe_id)
    assert equipe_resumo["avatar_url"] == trocado.json()["avatar_url"]
    assert equipe_resumo["capa_url"] == capa_url
    assert client.delete(capa, headers=auth(visitante)).status_code == 403

    removida = client.delete(capa, headers=auth(dono))
    assert removida.status_code == 200
    assert removida.json()["capa_url"] is None
    assert removida.json()["avatar_url"] == trocado.json()["avatar_url"]
    assert client.get(capa_url).status_code == 404
