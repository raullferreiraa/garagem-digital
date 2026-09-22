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


def criar_carro(client: TestClient, tokens: dict[str, object], modelo: str) -> dict:
    response = client.post(
        "/api/v1/carros", headers=auth(tokens), json={"modelo": modelo}
    )
    assert response.status_code == 201
    return response.json()


def test_fluxo_de_equipe_pedido_e_carro_escolhido(client: TestClient) -> None:
    dono = cadastrar(client, "dono.equipe")
    membro = cadastrar(client, "novo.membro")
    intruso = cadastrar(client, "pessoa.fora")
    carro_um = criar_carro(client, membro, "Omega")
    carro_dois = criar_carro(client, membro, "Opala")
    carro_intruso = criar_carro(client, intruso, "Gol")

    criada = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Equipe Omega ES", "cidade": "Vila Velha", "estado": "ES"},
    )
    assert criada.status_code == 201
    equipe = criada.json()
    assert equipe["slug"] == "equipe-omega-es"
    assert equipe["meu_papel"] == "dono"
    assert equipe["total_membros"] == 1

    pedido = client.post(
        f"/api/v1/equipes/{equipe['id']}/solicitacoes", headers=auth(membro)
    )
    assert pedido.status_code == 204
    assert pedido.content == b""

    repetido = client.post(
        f"/api/v1/equipes/{equipe['id']}/solicitacoes", headers=auth(membro)
    )
    assert repetido.status_code == 409

    detalhe_dono = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(dono)
    ).json()
    assert len(detalhe_dono["solicitacoes_pendentes"]) == 1
    solicitacao_id = detalhe_dono["solicitacoes_pendentes"][0]["id"]

    proibida = client.patch(
        f"/api/v1/equipes/{equipe['id']}/solicitacoes/{solicitacao_id}",
        headers=auth(intruso),
        json={"decisao": "aprovar"},
    )
    assert proibida.status_code == 403

    aprovada = client.patch(
        f"/api/v1/equipes/{equipe['id']}/solicitacoes/{solicitacao_id}",
        headers=auth(dono),
        json={"decisao": "aprovar"},
    )
    assert aprovada.status_code == 204

    escolhido = client.put(
        f"/api/v1/equipes/{equipe['id']}/meu-carro",
        headers=auth(membro),
        json={"carro_id": carro_um["id"]},
    )
    assert escolhido.status_code == 204

    trocado = client.put(
        f"/api/v1/equipes/{equipe['id']}/meu-carro",
        headers=auth(membro),
        json={"carro_id": carro_dois["id"]},
    )
    assert trocado.status_code == 204
    detalhe = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(membro)
    ).json()
    assert detalhe["total_membros"] == 2
    assert detalhe["meu_papel"] == "membro"
    assert [carro["id"] for carro in detalhe["carros"]] == [carro_dois["id"]]

    carro_de_outro = client.put(
        f"/api/v1/equipes/{equipe['id']}/meu-carro",
        headers=auth(membro),
        json={"carro_id": carro_intruso["id"]},
    )
    assert carro_de_outro.status_code == 403

    removido = client.delete(
        f"/api/v1/equipes/{equipe['id']}/meu-carro", headers=auth(membro)
    )
    assert removido.status_code == 204
    detalhe_sem_carro = client.get(
        f"/api/v1/equipes/{equipe['id']}", headers=auth(membro)
    ).json()
    assert detalhe_sem_carro["carros"] == []


def test_apenas_dono_edita_dados_da_equipe(client: TestClient) -> None:
    dono = cadastrar(client, "dono.edita")
    integrante = cadastrar(client, "membro.edita")
    visitante = cadastrar(client, "visitante.edita")
    criada = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Equipe Antiga", "descricao": "Antes", "cidade": "Vila Velha"},
    )
    assert criada.status_code == 201
    equipe = criada.json()
    caminho = f"/api/v1/equipes/{equipe['id']}"

    pedido = client.post(f"{caminho}/solicitacoes", headers=auth(integrante))
    assert pedido.status_code == 204
    detalhe_dono = client.get(caminho, headers=auth(dono)).json()
    solicitacao = detalhe_dono["solicitacoes_pendentes"][0]["id"]
    aprovada = client.patch(
        f"{caminho}/solicitacoes/{solicitacao}",
        headers=auth(dono),
        json={"decisao": "aprovar"},
    )
    assert aprovada.status_code == 204

    alteracoes = {
        "nome": "Equipe Nova",
        "descricao": "",
        "cidade": "Vitória",
        "estado": "ES",
        "visibilidade": "privada",
    }
    for usuario in (integrante, visitante):
        negada = client.patch(caminho, headers=auth(usuario), json=alteracoes)
        assert negada.status_code == 403

    editada = client.patch(caminho, headers=auth(dono), json=alteracoes)
    assert editada.status_code == 200
    dados = editada.json()
    assert dados["nome"] == "Equipe Nova"
    assert dados["slug"] == equipe["slug"]
    assert dados["descricao"] is None
    assert dados["cidade"] == "Vitória"
    assert dados["estado"] == "ES"
    assert dados["visibilidade"] == "privada"
    assert dados["total_membros"] == 2
    assert client.get(caminho, headers=auth(integrante)).status_code == 200
    assert client.get(caminho, headers=auth(visitante)).status_code == 404

    invalida = client.patch(
        caminho, headers=auth(dono), json={**alteracoes, "nome": " "}
    )
    assert invalida.status_code == 422
    assert client.get(caminho, headers=auth(dono)).json()["nome"] == "Equipe Nova"


def test_usuario_so_pode_pertencer_a_uma_equipe(client: TestClient) -> None:
    dono = cadastrar(client, "dono.cla")
    candidato = cadastrar(client, "candidato.cla")
    primeira = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Clã de Origem"},
    ).json()
    segunda = client.post(
        "/api/v1/equipes",
        headers=auth(candidato),
        json={"nome": "Outro Clã"},
    ).json()

    criar_outra = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Terceiro Clã"},
    )
    assert criar_outra.status_code == 409
    assert "já faz parte" in criar_outra.json()["detail"]

    pedido = client.post(
        f"/api/v1/equipes/{primeira['id']}/solicitacoes",
        headers=auth(candidato),
    )
    assert pedido.status_code == 409
    assert "já faz parte" in pedido.json()["detail"]

    convite = client.post(
        f"/api/v1/equipes/{primeira['id']}/convites",
        headers=auth(dono),
        json={"usuario_id": candidato["usuario"]["id"]},
    )
    assert convite.status_code == 409
    assert "já faz parte" in convite.json()["detail"]
    assert segunda["meu_papel"] == "dono"


def test_dono_transfere_lideranca_e_novo_dono_pode_encerrar_equipe(
    client: TestClient,
) -> None:
    dono = cadastrar(client, "dono.lideranca")
    integrante = cadastrar(client, "integrante.lideranca")
    equipe = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Clã da Liderança"},
    ).json()
    base = f"/api/v1/equipes/{equipe['id']}"
    assert client.post(f"{base}/solicitacoes", headers=auth(integrante)).status_code == 204
    pedido_id = client.get(base, headers=auth(dono)).json()["solicitacoes_pendentes"][0]["id"]
    assert client.patch(
        f"{base}/solicitacoes/{pedido_id}",
        headers=auth(dono),
        json={"decisao": "aprovar"},
    ).status_code == 204

    transferida = client.patch(
        f"{base}/lideranca",
        headers=auth(dono),
        json={"usuario_id": integrante["usuario"]["id"]},
    )
    assert transferida.status_code == 204
    detalhe = client.get(base, headers=auth(integrante)).json()
    assert detalhe["dono_id"] == integrante["usuario"]["id"]
    assert detalhe["meu_papel"] == "dono"

    encerrada = client.delete(base, headers=auth(integrante))
    assert encerrada.status_code == 204
    assert client.get(base, headers=auth(dono)).status_code == 404
