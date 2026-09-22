from fastapi.testclient import TestClient


def cadastrar(client: TestClient, username: str) -> dict:
    return client.post("/api/v1/auth/cadastro", json={"nome": username, "username": username, "email": f"{username}@example.com", "senha": "senha-segura-123"}).json()


def auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_chat_exige_membro_e_ordena_mensagens(client: TestClient) -> None:
    dono, membro, fora = (cadastrar(client, name) for name in ("donochat", "membrochat", "forachat"))
    equipe = client.post("/api/v1/equipes", headers=auth(dono), json={"nome": "Turma do Chat"}).json()
    base = f"/api/v1/equipes/{equipe['id']}"
    assert client.post(f"{base}/solicitacoes", headers=auth(membro)).status_code == 204
    solicitacao = client.get(base, headers=auth(dono)).json()["solicitacoes_pendentes"][0]["id"]
    assert client.patch(f"{base}/solicitacoes/{solicitacao}", headers=auth(dono), json={"decisao": "aprovar"}).status_code == 204
    assert client.get(f"{base}/chat", headers=auth(fora)).status_code == 404
    assert client.post(f"{base}/chat", headers=auth(fora), json={"conteudo": "invasao"}).status_code == 404
    for index in range(3):
        response = client.post(f"{base}/chat", headers=auth(dono), json={"conteudo": f"  Oficina {index} "})
        assert response.status_code == 201
        assert response.json()["conteudo"] == f"Oficina {index}"
    pagina = client.get(f"{base}/chat", headers=auth(membro), params={"limite": 2}).json()
    assert [item["conteudo"] for item in pagina["itens"]] == ["Oficina 1", "Oficina 2"]
    assert pagina["itens"][-1]["autor"]["username"] == "donochat"
    anterior = client.get(f"{base}/chat", headers=auth(membro), params={"cursor": pagina["proximo_cursor"]}).json()
    assert [item["conteudo"] for item in anterior["itens"]] == ["Oficina 0"]
    resumo_lido = client.get("/api/v1/equipes/meu-chat/resumo", headers=auth(membro)).json()
    assert resumo_lido["equipe_id"] == equipe["id"]
    assert resumo_lido["total_nao_lidas"] == 0

    nova = client.post(
        f"{base}/chat",
        headers=auth(dono),
        json={"conteudo": "Cheguei depois"},
    )
    assert nova.status_code == 201
    resumo_novo = client.get("/api/v1/equipes/meu-chat/resumo", headers=auth(membro)).json()
    assert resumo_novo["total_nao_lidas"] == 1
    assert resumo_novo["ultima_mensagem"]["conteudo"] == "Cheguei depois"

    client.get(f"{base}/chat", headers=auth(membro), params={"cursor": pagina["proximo_cursor"]})
    assert client.get("/api/v1/equipes/meu-chat/resumo", headers=auth(membro)).json()["total_nao_lidas"] == 1
    assert client.get(f"{base}/chat", headers=auth(membro), params={"cursor": "invalido"}).status_code == 422
    assert client.get("/api/v1/equipes/meu-chat/resumo", headers=auth(membro)).json()["total_nao_lidas"] == 1

    client.get(f"{base}/chat", headers=auth(membro))
    resumo_aberto = client.get("/api/v1/equipes/meu-chat/resumo", headers=auth(membro)).json()
    assert resumo_aberto["total_nao_lidas"] == 0


def test_resumo_chat_sem_equipe_retorna_nulo(client: TestClient) -> None:
    usuario = cadastrar(client, "semclachat")
    response = client.get("/api/v1/equipes/meu-chat/resumo", headers=auth(usuario))
    assert response.status_code == 200
    assert response.json() is None
