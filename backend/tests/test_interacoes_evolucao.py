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


def auth_header(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_curtidas_e_comentarios_da_evolucao(client: TestClient) -> None:
    dono = cadastrar(client, "dono.social")
    visitante = cadastrar(client, "visitante.social")
    outro = cadastrar(client, "outro.social")

    carro_response = client.post(
        "/api/v1/carros",
        headers=auth_header(dono),
        json={"modelo": "Omega CD 4.1", "ano": 1996},
    )
    assert carro_response.status_code == 201
    carro = carro_response.json()

    diario_url = f"/api/v1/carros/{carro['id']}/evolucoes"
    evolucao_response = client.post(
        diario_url,
        headers=auth_header(dono),
        json={
            "titulo": "Motor montado",
            "descricao": "Primeira partida depois da montagem.",
        },
    )
    assert evolucao_response.status_code == 201
    evolucao = evolucao_response.json()
    base = f"{diario_url}/{evolucao['id']}"

    assert client.get(f"{base}/interacoes").status_code == 401

    curtida_url = f"{base}/curtida"
    assert client.put(curtida_url, headers=auth_header(visitante)).status_code == 204
    assert client.put(curtida_url, headers=auth_header(visitante)).status_code == 204

    interacoes = client.get(
        f"{base}/interacoes",
        headers=auth_header(visitante),
    )
    assert interacoes.status_code == 200
    assert interacoes.json()["total_curtidas"] == 1
    assert interacoes.json()["curtido_por_mim"] is True
    assert interacoes.json()["comentarios"] == []

    comentario_response = client.post(
        f"{base}/comentarios",
        headers=auth_header(visitante),
        json={"conteudo": "  Ficou muito bom!  "},
    )
    assert comentario_response.status_code == 201
    comentario = comentario_response.json()
    assert comentario["conteudo"] == "Ficou muito bom!"
    assert comentario["autor"]["username"] == "visitante.social"
    assert comentario["total_curtidas"] == 0
    assert comentario["curtido_por_mim"] is False
    assert comentario["respostas"] == []

    resposta_url = f"{base}/comentarios/{comentario['id']}/respostas"
    resposta_response = client.post(
        resposta_url,
        headers=auth_header(outro),
        json={"conteudo": "Também gostei desse resultado."},
    )
    assert resposta_response.status_code == 201
    resposta = resposta_response.json()
    assert resposta["comentario_pai_id"] == comentario["id"]
    assert resposta["autor"]["username"] == "outro.social"

    resposta_aninhada = client.post(
        f"{base}/comentarios/{resposta['id']}/respostas",
        headers=auth_header(dono),
        json={"conteudo": "Uma resposta de segundo nível."},
    )
    assert resposta_aninhada.status_code == 422

    curtida_comentario_url = f"{base}/comentarios/{comentario['id']}/curtida"
    assert (
        client.put(curtida_comentario_url, headers=auth_header(dono)).status_code
        == 204
    )
    assert (
        client.put(curtida_comentario_url, headers=auth_header(dono)).status_code
        == 204
    )
    assert (
        client.put(curtida_comentario_url, headers=auth_header(outro)).status_code
        == 204
    )

    curtida_resposta_url = f"{base}/comentarios/{resposta['id']}/curtida"
    assert (
        client.put(curtida_resposta_url, headers=auth_header(visitante)).status_code
        == 204
    )

    interacoes_visitante = client.get(
        f"{base}/interacoes",
        headers=auth_header(visitante),
    ).json()
    comentario_atual = interacoes_visitante["comentarios"][0]
    assert comentario_atual["total_curtidas"] == 2
    assert comentario_atual["curtido_por_mim"] is False
    assert [item["id"] for item in comentario_atual["respostas"]] == [
        resposta["id"]
    ]
    assert comentario_atual["respostas"][0]["total_curtidas"] == 1
    assert comentario_atual["respostas"][0]["curtido_por_mim"] is True

    interacoes_dono = client.get(
        f"{base}/interacoes",
        headers=auth_header(dono),
    ).json()
    assert interacoes_dono["total_curtidas"] == 1
    assert interacoes_dono["curtido_por_mim"] is False
    assert [item["id"] for item in interacoes_dono["comentarios"]] == [
        comentario["id"]
    ]

    comentario_url = f"{base}/comentarios/{comentario['id']}"
    assert (
        client.delete(comentario_url, headers=auth_header(outro)).status_code == 404
    )
    assert (
        client.delete(comentario_url, headers=auth_header(visitante)).status_code
        == 204
    )
    assert client.delete(curtida_url, headers=auth_header(visitante)).status_code == 204
    assert client.delete(curtida_url, headers=auth_header(visitante)).status_code == 204

    finais = client.get(
        f"{base}/interacoes",
        headers=auth_header(visitante),
    ).json()
    assert finais["total_curtidas"] == 0
    assert finais["curtido_por_mim"] is False
    assert finais["comentarios"] == []


def test_autor_edita_comentario_e_resposta_sem_alterar_autoria(client: TestClient) -> None:
    dono = cadastrar(client, "dono.edicao")
    autor = cadastrar(client, "autor.edicao")
    outro = cadastrar(client, "outro.edicao")
    carro = client.post(
        "/api/v1/carros", headers=auth_header(dono),
        json={"modelo": "Opala", "ano": 1980},
    ).json()
    evolucao = client.post(
        f"/api/v1/carros/{carro['id']}/evolucoes", headers=auth_header(dono),
        json={"titulo": "Pintura", "descricao": "Nova cor."},
    ).json()
    base = f"/api/v1/carros/{carro['id']}/evolucoes/{evolucao['id']}"
    comentario = client.post(
        f"{base}/comentarios", headers=auth_header(autor),
        json={"conteudo": "Cor azul"},
    ).json()
    resposta = client.post(
        f"{base}/comentarios/{comentario['id']}/respostas",
        headers=auth_header(dono), json={"conteudo": "Obrigado"},
    ).json()
    assert comentario["editado_em"] is None
    assert resposta["editado_em"] is None

    comentario_url = f"{base}/comentarios/{comentario['id']}"
    assert client.patch(
        comentario_url, headers=auth_header(outro),
        json={"conteudo": "Alteração indevida"},
    ).status_code == 404
    assert client.patch(
        comentario_url, headers=auth_header(autor),
        json={"conteudo": "   "},
    ).status_code == 422
    editado = client.patch(
        comentario_url, headers=auth_header(autor),
        json={"conteudo": "  Cor verde  "},
    )
    assert editado.status_code == 200
    assert editado.json()["conteudo"] == "Cor verde"
    assert editado.json()["autor"]["username"] == "autor.edicao"
    assert editado.json()["editado_em"] is not None

    resposta_url = f"{base}/comentarios/{resposta['id']}"
    assert client.patch(
        resposta_url, headers=auth_header(autor),
        json={"conteudo": "Não pode"},
    ).status_code == 404
    assert client.patch(
        resposta_url, headers=auth_header(dono),
        json={"conteudo": "Muito obrigado"},
    ).status_code == 200
    historico = client.get(base + "/interacoes", headers=auth_header(autor)).json()
    assert historico["comentarios"][0]["conteudo"] == "Cor verde"
    assert historico["comentarios"][0]["editado_em"] is not None
    assert historico["comentarios"][0]["respostas"][0]["conteudo"] == "Muito obrigado"
    assert historico["comentarios"][0]["respostas"][0]["editado_em"] is not None
