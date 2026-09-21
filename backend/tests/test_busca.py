from fastapi.testclient import TestClient


def cadastrar(client: TestClient, username: str, nome: str) -> dict[str, object]:
    response = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": nome,
            "username": username,
            "email": f"{username}@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert response.status_code == 201
    return response.json()


def auth(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_busca_reune_pessoas_projetos_e_equipes(client: TestClient) -> None:
    visitante = cadastrar(client, "visitante.busca", "Visitante")
    criador = cadastrar(client, "raul.omega", "Raul Omega")

    carro = client.post(
        "/api/v1/carros",
        headers=auth(criador),
        json={
            "modelo": "Omega CD 4.1",
            "ano": 1996,
            "cor": "Bordô",
            "motor": "Seis cilindros",
            "preparacao": "Aspirado de rua",
        },
    )
    assert carro.status_code == 201

    projeto_com_termo_apenas_no_historico = client.post(
        "/api/v1/carros",
        headers=auth(criador),
        json={
            "modelo": "Gol GTI",
            "historia": "Projeto inspirado no Omega",
        },
    )
    assert projeto_com_termo_apenas_no_historico.status_code == 201

    equipe = client.post(
        "/api/v1/equipes",
        headers=auth(criador),
        json={"nome": "Oficina Omega", "cidade": "Vila Velha"},
    )
    assert equipe.status_code == 201

    pessoas = client.get(
        "/api/v1/usuarios",
        params={"busca": "omega"},
        headers=auth(visitante),
    )
    assert pessoas.status_code == 200
    assert [item["username"] for item in pessoas.json()] == ["raul.omega"]

    pessoas_com_arroba = client.get(
        "/api/v1/usuarios",
        params={"busca": "@raul"},
        headers=auth(visitante),
    )
    assert pessoas_com_arroba.status_code == 200
    assert [item["username"] for item in pessoas_com_arroba.json()] == [
        "raul.omega"
    ]

    projetos_por_proprietario = client.get(
        "/api/v1/carros",
        params={"busca": "raul"},
        headers=auth(visitante),
    )
    assert projetos_por_proprietario.status_code == 200
    assert projetos_por_proprietario.json()["itens"] == []

    projetos = client.get(
        "/api/v1/carros",
        params={"busca": "omega"},
        headers=auth(visitante),
    )
    assert projetos.status_code == 200
    assert [item["modelo"] for item in projetos.json()["itens"]] == [
        "OMEGA CD 4.1",
        "GOL GTI",
    ]

    for detalhe in ("bord", "cil", "asp", "ru", "199"):
        encontrados = client.get(
            "/api/v1/carros",
            params={"busca": detalhe},
            headers=auth(visitante),
        )
        assert encontrados.status_code == 200
        assert [item["modelo"] for item in encontrados.json()["itens"]] == [
            "OMEGA CD 4.1"
        ]

    trecho_no_meio_da_palavra = client.get(
        "/api/v1/carros",
        params={"busca": "ra"},
        headers=auth(visitante),
    )
    assert trecho_no_meio_da_palavra.status_code == 200
    assert trecho_no_meio_da_palavra.json()["itens"] == []

    trecho_no_meio_do_modelo = client.get(
        "/api/v1/carros",
        params={"busca": "meg"},
        headers=auth(visitante),
    )
    assert trecho_no_meio_do_modelo.status_code == 200
    assert [
        item["modelo"] for item in trecho_no_meio_do_modelo.json()["itens"]
    ] == ["OMEGA CD 4.1"]

    equipes = client.get(
        "/api/v1/equipes",
        params={"busca": "oficina"},
        headers=auth(visitante),
    )
    assert equipes.status_code == 200
    assert [item["nome"] for item in equipes.json()] == ["Oficina Omega"]


def test_busca_nao_expoe_equipe_privada_para_nao_membro(
    client: TestClient,
) -> None:
    visitante = cadastrar(client, "visitante.privado", "Visitante Privado")
    dono = cadastrar(client, "dono.privado", "Dono Privado")
    response = client.post(
        "/api/v1/equipes",
        headers=auth(dono),
        json={"nome": "Projeto Secreto", "visibilidade": "privada"},
    )
    assert response.status_code == 201

    resultado = client.get(
        "/api/v1/equipes",
        params={"busca": "secreto"},
        headers=auth(visitante),
    )
    assert resultado.status_code == 200
    assert resultado.json() == []
