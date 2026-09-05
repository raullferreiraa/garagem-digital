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


def imagem_png() -> bytes:
    conteudo = BytesIO()
    Image.new("RGB", (120, 80), "blue").save(conteudo, format="PNG")
    return conteudo.getvalue()


def test_perfil_publico_nao_expoe_email_e_edicao_exige_token(
    client: TestClient,
) -> None:
    tokens = cadastrar(client, "raul.teste")
    usuario = tokens["usuario"]

    publico = client.get(f"/api/v1/usuarios/{usuario['id']}")
    assert publico.status_code == 200
    assert "email" not in publico.json()

    sem_token = client.patch("/api/v1/usuarios/me", json={"bio": "Minha garagem"})
    assert sem_token.status_code == 401

    atualizado = client.patch(
        "/api/v1/usuarios/me",
        headers=auth_header(tokens),
        json={
            "bio": "  Minha garagem  ",
            "cidade": "Vila Velha",
            "estado": "ES",
        },
    )
    assert atualizado.status_code == 200
    assert atualizado.json()["bio"] == "Minha garagem"


def test_crud_de_carro_respeita_propriedade_e_privacidade(
    client: TestClient,
) -> None:
    dono = cadastrar(client, "dono.carro")
    intruso = cadastrar(client, "outro.usuario")
    dados_carro = {
        "modelo": "  Gol CL  ",
        "ano": 1994,
        "cor": "Branco",
        "placa": "abc-1d23",
        "historia": "Projeto de rua",
    }

    sem_token = client.post("/api/v1/carros", json=dados_carro)
    assert sem_token.status_code == 401

    criado = client.post(
        "/api/v1/carros",
        headers=auth_header(dono),
        json=dados_carro,
    )
    assert criado.status_code == 201
    carro = criado.json()
    assert carro["modelo"] == "Gol CL"
    assert carro["placa"] == "ABC1D23"
    assert carro["placa_visivel"] is False
    assert carro["proprietario"]["id"] == dono["usuario"]["id"]

    detalhe_publico = client.get(f"/api/v1/carros/{carro['id']}")
    assert detalhe_publico.status_code == 200
    assert detalhe_publico.json()["placa"] is None
    assert "placa_visivel" not in detalhe_publico.json()

    tentativa_edicao = client.patch(
        f"/api/v1/carros/{carro['id']}",
        headers=auth_header(intruso),
        json={"cor": "Preto"},
    )
    assert tentativa_edicao.status_code == 404

    atualizado = client.patch(
        f"/api/v1/carros/{carro['id']}",
        headers=auth_header(dono),
        json={"cor": "Preto"},
    )
    assert atualizado.status_code == 200
    assert atualizado.json()["cor"] == "Preto"

    placa_publica = client.patch(
        f"/api/v1/carros/{carro['id']}",
        headers=auth_header(dono),
        json={"placa_visivel": True},
    )
    assert placa_publica.status_code == 200
    detalhe_com_placa = client.get(f"/api/v1/carros/{carro['id']}")
    assert detalhe_com_placa.json()["placa"] == "ABC1D23"

    modelo_nulo = client.patch(
        f"/api/v1/carros/{carro['id']}",
        headers=auth_header(dono),
        json={"modelo": None},
    )
    assert modelo_nulo.status_code == 422

    tentativa_exclusao = client.delete(
        f"/api/v1/carros/{carro['id']}",
        headers=auth_header(intruso),
    )
    assert tentativa_exclusao.status_code == 404

    exclusao = client.delete(
        f"/api/v1/carros/{carro['id']}",
        headers=auth_header(dono),
    )
    assert exclusao.status_code == 204
    assert client.get(f"/api/v1/carros/{carro['id']}").status_code == 404


def test_feed_paginado_e_garagens_publica_e_privada(client: TestClient) -> None:
    dono = cadastrar(client, "garagem.teste")

    for numero in range(3):
        response = client.post(
            "/api/v1/carros",
            headers=auth_header(dono),
            json={"modelo": f"Projeto {numero + 1}"},
        )
        assert response.status_code == 201

    primeira_pagina = client.get("/api/v1/carros?limite=2")
    assert primeira_pagina.status_code == 200
    primeira = primeira_pagina.json()
    assert len(primeira["itens"]) == 2
    assert primeira["proximo_cursor"]

    segunda_pagina = client.get(
        "/api/v1/carros",
        params={"limite": 2, "cursor": primeira["proximo_cursor"]},
    )
    assert segunda_pagina.status_code == 200
    segunda = segunda_pagina.json()
    assert len(segunda["itens"]) == 1
    assert segunda["proximo_cursor"] is None

    ids_primeira = {item["id"] for item in primeira["itens"]}
    ids_segunda = {item["id"] for item in segunda["itens"]}
    assert ids_primeira.isdisjoint(ids_segunda)

    publica = client.get(f"/api/v1/usuarios/{dono['usuario']['id']}/carros")
    privada = client.get("/api/v1/carros/meus", headers=auth_header(dono))
    assert publica.status_code == 200
    assert privada.status_code == 200
    assert len(publica.json()) == 3
    assert len(privada.json()) == 3

    cursor_invalido = client.get("/api/v1/carros?cursor=invalido")
    assert cursor_invalido.status_code == 400


def test_foto_principal_exige_dono_e_remove_metadados(
    client: TestClient,
) -> None:
    dono = cadastrar(client, "foto.dono")
    intruso = cadastrar(client, "foto.intruso")
    criado = client.post(
        "/api/v1/carros",
        headers=auth_header(dono),
        json={"modelo": "Omega CD"},
    ).json()
    url = f"/api/v1/carros/{criado['id']}/foto-principal"

    sem_token = client.post(
        url,
        files={"arquivo": ("omega.png", imagem_png(), "image/png")},
    )
    assert sem_token.status_code == 401

    outro_usuario = client.post(
        url,
        headers=auth_header(intruso),
        files={"arquivo": ("omega.png", imagem_png(), "image/png")},
    )
    assert outro_usuario.status_code == 404

    invalida = client.post(
        url,
        headers=auth_header(dono),
        files={"arquivo": ("omega.jpg", b"nao e imagem", "image/jpeg")},
    )
    assert invalida.status_code == 415

    enviada = client.post(
        url,
        headers=auth_header(dono),
        files={"arquivo": ("omega.png", imagem_png(), "image/png")},
    )
    assert enviada.status_code == 200
    foto_url = enviada.json()["foto_principal_url"]
    assert foto_url.startswith(f"/media/carros/{criado['id']}/")
    assert foto_url.endswith(".jpg")

    publica = client.get(foto_url)
    assert publica.status_code == 200
    assert publica.headers["content-type"] == "image/jpeg"
    with Image.open(BytesIO(publica.content)) as foto_processada:
        assert foto_processada.format == "JPEG"
        assert not foto_processada.getexif()

    removida = client.delete(url, headers=auth_header(dono))
    assert removida.status_code == 200
    assert removida.json()["foto_principal_url"] is None
    assert client.get(foto_url).status_code == 404
