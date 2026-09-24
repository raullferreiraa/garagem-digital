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


def usuario_id(tokens: dict[str, object]) -> str:
    return str(tokens["usuario"]["id"])  # type: ignore[index]


def test_conversa_direta_e_unica_e_protegida(client: TestClient) -> None:
    raul = cadastrar(client, "raulchat")
    bia = cadastrar(client, "biachat")
    intruso = cadastrar(client, "intrusochat")

    criada = client.post(
        "/api/v1/conversas/diretas",
        headers=auth_header(raul),
        json={"usuario_id": usuario_id(bia)},
    )
    assert criada.status_code == 200
    conversa = criada.json()
    assert conversa["outro_usuario"]["id"] == usuario_id(bia)
    assert "email" not in conversa["outro_usuario"]

    inversa = client.post(
        "/api/v1/conversas/diretas",
        headers=auth_header(bia),
        json={"usuario_id": usuario_id(raul)},
    )
    assert inversa.status_code == 200
    assert inversa.json()["id"] == conversa["id"]
    assert inversa.json()["outro_usuario"]["id"] == usuario_id(raul)

    consigo = client.post(
        "/api/v1/conversas/diretas",
        headers=auth_header(raul),
        json={"usuario_id": usuario_id(raul)},
    )
    assert consigo.status_code == 400

    caminho = f"/api/v1/conversas/{conversa['id']}"
    for metodo, sufixo in (
        (client.get, "/mensagens"),
        (client.post, "/lida"),
    ):
        resposta = metodo(caminho + sufixo, headers=auth_header(intruso))
        assert resposta.status_code == 404
    resposta = client.post(
        caminho + "/mensagens",
        headers=auth_header(intruso),
        json={"conteudo": "Tentativa indevida"},
    )
    assert resposta.status_code == 404


def test_mensagens_paginacao_e_leitura(client: TestClient) -> None:
    remetente = cadastrar(client, "remetentechat")
    destinatario = cadastrar(client, "destinatariochat")
    conversa = client.post(
        "/api/v1/conversas/diretas",
        headers=auth_header(remetente),
        json={"usuario_id": usuario_id(destinatario)},
    ).json()
    caminho = f"/api/v1/conversas/{conversa['id']}"

    vazia = client.post(
        caminho + "/mensagens",
        headers=auth_header(remetente),
        json={"conteudo": "   \n  "},
    )
    assert vazia.status_code == 422

    ids_enviados: list[str] = []
    for indice in range(35):
        resposta = client.post(
            caminho + "/mensagens",
            headers=auth_header(remetente),
            json={"conteudo": f"  Mensagem {indice:02d}  "},
        )
        assert resposta.status_code == 201
        assert resposta.json()["conteudo"] == f"Mensagem {indice:02d}"
        ids_enviados.append(resposta.json()["id"])

    caixa = client.get(
        "/api/v1/conversas",
        headers=auth_header(destinatario),
    )
    assert caixa.status_code == 200
    assert len(caixa.json()) == 1
    assert caixa.json()[0]["ultima_mensagem"]["conteudo"] == "Mensagem 34"
    assert caixa.json()[0]["total_nao_lidas"] == 35
    assert client.get(
        "/api/v1/conversas/nao-lidas",
        headers=auth_header(destinatario),
    ).json() == {"total": 1}
    assert client.get(
        "/api/v1/conversas/nao-lidas",
        headers=auth_header(remetente),
    ).json() == {"total": 0}

    primeira = client.get(
        caminho + "/mensagens",
        headers=auth_header(destinatario),
        params={"limite": 10},
    ).json()
    assert [item["conteudo"] for item in primeira["itens"]] == [
        f"Mensagem {indice:02d}" for indice in range(25, 35)
    ]
    assert primeira["proximo_cursor"]

    segunda = client.get(
        caminho + "/mensagens",
        headers=auth_header(destinatario),
        params={"limite": 10, "cursor": primeira["proximo_cursor"]},
    ).json()
    assert [item["conteudo"] for item in segunda["itens"]] == [
        f"Mensagem {indice:02d}" for indice in range(15, 25)
    ]
    assert not (
        {item["id"] for item in primeira["itens"]}
        & {item["id"] for item in segunda["itens"]}
    )
    assert ids_enviados[-1] == primeira["itens"][-1]["id"]

    lida = client.post(
        caminho + "/lida",
        headers=auth_header(destinatario),
    )
    assert lida.status_code == 204
    assert client.get(
        "/api/v1/conversas/nao-lidas",
        headers=auth_header(destinatario),
    ).json() == {"total": 0}

    resposta = client.post(
        caminho + "/mensagens",
        headers=auth_header(destinatario),
        json={"conteudo": "Recebido!"},
    )
    assert resposta.status_code == 201
    assert client.get(
        "/api/v1/conversas/nao-lidas",
        headers=auth_header(remetente),
    ).json() == {"total": 1}


def test_cursor_de_mensagem_invalido(client: TestClient) -> None:
    usuario_a = cadastrar(client, "cursorachat")
    usuario_b = cadastrar(client, "cursorbchat")
    conversa = client.post(
        "/api/v1/conversas/diretas",
        headers=auth_header(usuario_a),
        json={"usuario_id": usuario_id(usuario_b)},
    ).json()

    for cursor in ("cursor-invalido", "a"):
        resposta = client.get(
            f"/api/v1/conversas/{conversa['id']}/mensagens",
            headers=auth_header(usuario_a),
            params={"cursor": cursor},
        )
        assert resposta.status_code == 422
