from fastapi.testclient import TestClient
import pytest
from uuid import uuid4


def cadastrar(client: TestClient, username: str) -> dict:
    resposta = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": username,
            "username": username,
            "email": f"{username}@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


def auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_editar_e_apagar_mensagem_direta_sem_expor_texto_antigo(client: TestClient) -> None:
    autor = cadastrar(client, "autor.dm")
    outro = cadastrar(client, "outro.dm")
    terceiro = cadastrar(client, "terceiro.dm")
    conversa = client.post(
        "/api/v1/conversas/diretas",
        headers=auth(autor),
        json={"usuario_id": outro["usuario"]["id"]},
    ).json()
    base = f"/api/v1/conversas/{conversa['id']}/mensagens"
    mensagem = client.post(
        base, headers=auth(autor), json={"conteudo": "texto antigo"}
    ).json()
    caminho = f"{base}/{mensagem['id']}"

    assert client.patch(caminho, json={"conteudo": "invasao"}).status_code == 401
    assert client.patch(caminho, headers=auth(outro), json={"conteudo": "invasao"}).status_code == 404
    assert client.delete(caminho, headers=auth(terceiro)).status_code == 404
    assert client.patch(caminho, headers=auth(autor), json={"conteudo": "   "}).status_code == 422

    editada = client.patch(
        caminho, headers=auth(autor), json={"conteudo": "  texto novo  "}
    )
    assert editada.status_code == 200
    assert editada.json()["conteudo"] == "texto novo"
    assert editada.json()["editada_em"] is not None
    assert editada.json()["criada_em"] == mensagem["criada_em"]

    assert client.delete(caminho, headers=auth(autor)).status_code == 204
    assert client.delete(caminho, headers=auth(autor)).status_code == 204
    assert client.patch(caminho, headers=auth(autor), json={"conteudo": "novo"}).status_code == 409
    pagina = client.get(base, headers=auth(outro)).json()
    assert pagina["itens"][0]["conteudo"] == ""
    assert pagina["itens"][0]["excluida_em"] is not None
    assert client.get("/api/v1/conversas", headers=auth(outro)).json()[0]["ultima_mensagem"]["conteudo"] == ""
    assert client.get("/api/v1/conversas/nao-lidas", headers=auth(outro)).json() == {"total": 0}


def test_editar_e_apagar_mensagem_da_equipe_exige_autoria_e_vinculo(client: TestClient) -> None:
    dono = cadastrar(client, "dono.edicao")
    membro = cadastrar(client, "membro.edicao")
    fora = cadastrar(client, "fora.edicao")
    equipe = client.post(
        "/api/v1/equipes", headers=auth(dono), json={"nome": "Oficina"}
    ).json()
    base = f"/api/v1/equipes/{equipe['id']}"
    assert client.post(f"{base}/solicitacoes", headers=auth(membro)).status_code == 204
    solicitacao = client.get(base, headers=auth(dono)).json()["solicitacoes_pendentes"][0]["id"]
    assert client.patch(
        f"{base}/solicitacoes/{solicitacao}",
        headers=auth(dono),
        json={"decisao": "aprovar"},
    ).status_code == 204
    mensagem = client.post(
        f"{base}/chat", headers=auth(dono), json={"conteudo": "texto antigo"}
    ).json()
    caminho = f"{base}/chat/{mensagem['id']}"

    assert client.patch(caminho, headers=auth(membro), json={"conteudo": "invasao"}).status_code == 404
    assert client.delete(caminho, headers=auth(fora)).status_code == 404
    assert client.patch(caminho, headers=auth(dono), json={"conteudo": "  texto novo "}).json()["conteudo"] == "texto novo"
    assert client.delete(caminho, headers=auth(dono)).status_code == 204
    assert client.patch(caminho, headers=auth(dono), json={"conteudo": "outro"}).status_code == 409
    pagina = client.get(f"{base}/chat", headers=auth(membro)).json()
    assert pagina["itens"][0]["conteudo"] == ""
    assert pagina["itens"][0]["excluida_em"] is not None
    resumo = client.get("/api/v1/equipes/meu-chat/resumo", headers=auth(membro)).json()
    assert resumo["ultima_mensagem"]["conteudo"] == ""
    assert resumo["total_nao_lidas"] == 0


@pytest.mark.parametrize("equipe", [False, True])
def test_resposta_exige_mesma_conversa_e_nao_guarda_texto_apagado(client: TestClient, equipe: bool) -> None:
    autor = cadastrar(client, "autor.resposta")
    outro = cadastrar(client, "outro.resposta")
    terceiro = cadastrar(client, "terceiro.resposta")
    if equipe:
        grupo = client.post("/api/v1/equipes", headers=auth(autor), json={"nome": "Garagem"}).json()
        outro_grupo = client.post("/api/v1/equipes", headers=auth(terceiro), json={"nome": "Outra"}).json()
        base = f"/api/v1/equipes/{grupo['id']}/chat"
        base_alheia = f"/api/v1/equipes/{outro_grupo['id']}/chat"
        # O integrante responde à mensagem de outra pessoa da mesma equipe.
        equipe_base = f"/api/v1/equipes/{grupo['id']}"
        client.post(f"{equipe_base}/solicitacoes", headers=auth(outro))
        pedido = client.get(equipe_base, headers=auth(autor)).json()["solicitacoes_pendentes"][0]["id"]
        client.patch(f"{equipe_base}/solicitacoes/{pedido}", headers=auth(autor), json={"decisao": "aprovar"})
    else:
        conversa = client.post("/api/v1/conversas/diretas", headers=auth(autor), json={"usuario_id": outro["usuario"]["id"]}).json()
        alheia = client.post("/api/v1/conversas/diretas", headers=auth(terceiro), json={"usuario_id": outro["usuario"]["id"]}).json()
        base = f"/api/v1/conversas/{conversa['id']}/mensagens"
        base_alheia = f"/api/v1/conversas/{alheia['id']}/mensagens"
    original = client.post(base, headers=auth(autor), json={"conteudo": "Onde será?"}).json()
    privada = client.post(base_alheia, headers=auth(terceiro), json={"conteudo": "Conteúdo de outra conversa"}).json()
    for referencia in [privada["id"], str(uuid4())]:
        falha = client.post(base, headers=auth(outro), json={"conteudo": "resposta", "resposta_a_id": referencia})
        assert falha.status_code == 422
        assert "Conteúdo de outra conversa" not in falha.text
    assert client.post(base, headers=auth(terceiro), json={"conteudo": "invasão", "resposta_a_id": original["id"]}).status_code == 404
    resposta = client.post(base, headers=auth(outro), json={"conteudo": "Na praça", "resposta_a_id": original["id"]})
    assert resposta.status_code == 201
    citada = resposta.json()["resposta_a"]
    assert citada["id"] == original["id"]
    assert citada["conteudo"] == "Onde será?"
    assert "resposta_a" not in citada
    caminho = f"{base}/{original['id']}"
    assert client.patch(caminho, headers=auth(autor), json={"conteudo": "Qual praça?"}).status_code == 200
    itens = client.get(base, headers=auth(outro)).json()["itens"]
    assert next(item for item in itens if item["id"] == resposta.json()["id"])["resposta_a"]["conteudo"] == "Qual praça?"
    assert client.delete(caminho, headers=auth(autor)).status_code == 204
    itens = client.get(base, headers=auth(outro)).json()["itens"]
    citada = next(item for item in itens if item["id"] == resposta.json()["id"])["resposta_a"]
    assert citada["conteudo"] == ""
    assert citada["excluida_em"] is not None
    assert client.post(base, headers=auth(outro), json={"conteudo": "tarde", "resposta_a_id": original["id"]}).status_code == 422
