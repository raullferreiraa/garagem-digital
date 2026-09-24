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


def cabecalho(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def id_usuario(tokens: dict[str, object]) -> str:
    return str(tokens["usuario"]["id"])  # type: ignore[index]


def test_bloqueio_corta_seguidores_e_conversa_e_pode_ser_desfeito(
    client: TestClient,
) -> None:
    ana = cadastrar(client, "anablock")
    bia = cadastrar(client, "biablock")
    ana_id, bia_id = id_usuario(ana), id_usuario(bia)
    assert client.put(f"/api/v1/usuarios/{bia_id}/seguir", headers=cabecalho(ana)).status_code == 204
    assert client.put(f"/api/v1/usuarios/{ana_id}/seguir", headers=cabecalho(bia)).status_code == 204
    conversa = client.post(
        "/api/v1/conversas/diretas",
        headers=cabecalho(ana),
        json={"usuario_id": bia_id},
    ).json()
    assert client.post(
        f"/api/v1/conversas/{conversa['id']}/mensagens",
        headers=cabecalho(ana),
        json={"conteudo": "Olá"},
    ).status_code == 201

    bloqueio = f"/api/v1/usuarios/{bia_id}/bloqueio"
    assert client.put(bloqueio, headers=cabecalho(ana)).status_code == 204
    assert client.put(bloqueio, headers=cabecalho(ana)).status_code == 204
    assert client.get("/api/v1/usuarios/me/bloqueios", headers=cabecalho(ana)).json()[0]["id"] == bia_id
    assert client.get(f"/api/v1/usuarios/{bia_id}", headers=cabecalho(ana)).json()["bloqueado_por_mim"] is True
    assert client.get(f"/api/v1/usuarios/{ana_id}", headers=cabecalho(bia)).status_code == 404
    assert client.get(f"/api/v1/usuarios/{ana_id}/seguindo", headers=cabecalho(ana)).json() == []
    assert client.get(f"/api/v1/usuarios/{bia_id}/seguidores", headers=cabecalho(bia)).json() == []
    for quem, outro in ((ana, bia_id), (bia, ana_id)):
        assert client.put(
            f"/api/v1/usuarios/{outro}/seguir", headers=cabecalho(quem)
        ).status_code == 403
        assert client.post(
            "/api/v1/conversas/diretas",
            headers=cabecalho(quem),
            json={"usuario_id": outro},
        ).status_code == 404
        assert client.get("/api/v1/conversas", headers=cabecalho(quem)).json() == []
        assert client.get("/api/v1/conversas/nao-lidas", headers=cabecalho(quem)).json()["total"] == 0
        assert client.get(
            f"/api/v1/conversas/{conversa['id']}/mensagens",
            headers=cabecalho(quem),
        ).status_code == 404
        assert client.post(
            f"/api/v1/conversas/{conversa['id']}/mensagens",
            headers=cabecalho(quem),
            json={"conteudo": "Ainda aqui"},
        ).status_code == 404

    assert client.delete(bloqueio, headers=cabecalho(ana)).status_code == 204
    assert client.get("/api/v1/usuarios/me/bloqueios", headers=cabecalho(ana)).json() == []
    assert client.get("/api/v1/conversas", headers=cabecalho(ana)).json()[0]["id"] == conversa["id"]
    assert client.get("/api/v1/conversas/nao-lidas", headers=cabecalho(bia)).json()["total"] == 0
    assert client.get("/api/v1/notificacoes/nao-lidas", headers=cabecalho(bia)).json()["total"] == 0
    assert client.get(f"/api/v1/usuarios/{bia_id}", headers=cabecalho(ana)).json()["seguido_por_mim"] is False


def test_bloqueio_some_da_busca_feed_e_impede_interacoes(client: TestClient) -> None:
    dono = cadastrar(client, "donoblock")
    visitante = cadastrar(client, "visitanteblock")
    dono_id, visitante_id = id_usuario(dono), id_usuario(visitante)
    carro = client.post(
        "/api/v1/carros", headers=cabecalho(dono), json={"modelo": "Gol GTI"}
    ).json()
    evolucao = client.post(
        f"/api/v1/carros/{carro['id']}/evolucoes",
        headers=cabecalho(dono),
        json={"titulo": "Primeira etapa", "descricao": "Projeto começou."},
    ).json()
    assert client.put(f"/api/v1/usuarios/{dono_id}/seguir", headers=cabecalho(visitante)).status_code == 204
    assert client.put(f"/api/v1/usuarios/{visitante_id}/bloqueio", headers=cabecalho(dono)).status_code == 204

    for quem, busca in ((dono, "visitanteblock"), (visitante, "donoblock")):
        assert client.get(
            "/api/v1/usuarios", headers=cabecalho(quem), params={"busca": busca}
        ).json() == []
    assert client.get("/api/v1/carros", headers=cabecalho(visitante)).json()["itens"] == []
    assert client.get(f"/api/v1/usuarios/{dono_id}/carros", headers=cabecalho(visitante)).json() == []
    assert client.get("/api/v1/feed/seguindo", headers=cabecalho(visitante)).json() == []
    assert client.post(
        f"/api/v1/carros/{carro['id']}/evolucoes/{evolucao['id']}/comentarios",
        headers=cabecalho(visitante),
        json={"conteudo": "Mensagem"},
    ).status_code == 403
    assert client.put(
        f"/api/v1/carros/{carro['id']}/evolucoes/{evolucao['id']}/curtida",
        headers=cabecalho(visitante),
    ).status_code == 403
    assert client.put(
        f"/api/v1/usuarios/{visitante_id}/bloqueio", headers=cabecalho(visitante)
    ).status_code == 400


def test_bloqueio_impede_convites_e_pedidos_de_equipe(client: TestClient) -> None:
    dono = cadastrar(client, "donoequipe.block")
    pessoa = cadastrar(client, "pessoaequipe.block")
    dono_id, pessoa_id = id_usuario(dono), id_usuario(pessoa)
    equipe = client.post(
        "/api/v1/equipes",
        headers=cabecalho(dono),
        json={"nome": "Equipe da Pista"},
    ).json()
    base = f"/api/v1/equipes/{equipe['id']}"
    bloqueio = f"/api/v1/usuarios/{pessoa_id}/bloqueio"

    assert client.put(bloqueio, headers=cabecalho(dono)).status_code == 204
    assert client.get(base, headers=cabecalho(pessoa)).json()["bloqueio_dono"] is True
    assert client.post(
        f"{base}/convites",
        headers=cabecalho(dono),
        json={"usuario_id": pessoa_id},
    ).status_code == 403
    assert client.post(f"{base}/solicitacoes", headers=cabecalho(pessoa)).status_code == 403

    assert client.delete(bloqueio, headers=cabecalho(dono)).status_code == 204
    assert client.get(base, headers=cabecalho(pessoa)).json()["bloqueio_dono"] is False
    assert client.post(
        f"{base}/convites",
        headers=cabecalho(dono),
        json={"usuario_id": pessoa_id},
    ).status_code == 204
    assert client.put(
        f"/api/v1/usuarios/{dono_id}/bloqueio", headers=cabecalho(pessoa)
    ).status_code == 204
    assert client.patch(
        f"{base}/meu-convite",
        headers=cabecalho(pessoa),
        json={"decisao": "aceitar"},
    ).status_code == 403
    assert client.patch(
        f"{base}/meu-convite",
        headers=cabecalho(pessoa),
        json={"decisao": "recusar"},
    ).status_code == 204

    assert client.delete(
        f"/api/v1/usuarios/{dono_id}/bloqueio", headers=cabecalho(pessoa)
    ).status_code == 204
    assert client.post(f"{base}/solicitacoes", headers=cabecalho(pessoa)).status_code == 204
    pedido_id = client.get(base, headers=cabecalho(dono)).json()[
        "solicitacoes_pendentes"
    ][0]["id"]
    assert client.put(bloqueio, headers=cabecalho(dono)).status_code == 204
    assert client.get(base, headers=cabecalho(dono)).json()[
        "solicitacoes_pendentes"
    ][0]["bloqueio_para_aprovacao"] is True
    assert client.patch(
        f"{base}/solicitacoes/{pedido_id}",
        headers=cabecalho(dono),
        json={"decisao": "aprovar"},
    ).status_code == 403
    assert client.patch(
        f"{base}/solicitacoes/{pedido_id}",
        headers=cabecalho(dono),
        json={"decisao": "recusar"},
    ).status_code == 204
