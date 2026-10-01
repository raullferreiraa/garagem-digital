import pytest
from fastapi.testclient import TestClient

from test_edicao_mensagens import auth, cadastrar


@pytest.mark.parametrize("equipe", [False, True])
def test_busca_paginada_e_original_respeitam_privacidade(client: TestClient, equipe: bool) -> None:
    autor = cadastrar(client, "autor.busca")
    leitor = cadastrar(client, "leitor.busca")
    fora = cadastrar(client, "fora.busca")
    if equipe:
        grupo = client.post("/api/v1/equipes", headers=auth(autor), json={"nome": "Garagem"}).json()
        grupo_base = f"/api/v1/equipes/{grupo['id']}"
        client.post(f"{grupo_base}/solicitacoes", headers=auth(leitor))
        pedido = client.get(grupo_base, headers=auth(autor)).json()["solicitacoes_pendentes"][0]["id"]
        client.patch(f"{grupo_base}/solicitacoes/{pedido}", headers=auth(autor), json={"decisao": "aprovar"})
        base = f"{grupo_base}/chat"
        outro = client.post("/api/v1/equipes", headers=auth(fora), json={"nome": "Outra"}).json()
        base_alheia = f"/api/v1/equipes/{outro['id']}/chat"
    else:
        conversa = client.post("/api/v1/conversas/diretas", headers=auth(autor), json={"usuario_id": leitor["usuario"]["id"]}).json()
        base = f"/api/v1/conversas/{conversa['id']}/mensagens"
        outra = client.post("/api/v1/conversas/diretas", headers=auth(fora), json={"usuario_id": autor["usuario"]["id"]}).json()
        base_alheia = f"/api/v1/conversas/{outra['id']}/mensagens"
    ids = []
    for texto in ["Oficina 100% pronta", "oficina antiga", "OFICINA nova", "sem resultado"]:
        ids.append(client.post(base, headers=auth(autor), json={"conteudo": texto}).json()["id"])
    privada = client.post(base_alheia, headers=auth(fora), json={"conteudo": "oficina privada"}).json()
    pagina = client.get(base, headers=auth(leitor), params={"busca": " oficina ", "limite": 2}).json()
    assert {m["id"] for m in pagina["itens"]} == set(ids[1:3])
    assert pagina["proximo_cursor"]
    antiga = client.get(base, headers=auth(leitor), params={"busca": "oficina", "limite": 2, "cursor": pagina["proximo_cursor"]}).json()
    assert [m["id"] for m in antiga["itens"]] == ids[:1]
    assert antiga["proximo_cursor"] is None
    literal = client.get(base, headers=auth(leitor), params={"busca": "100%"}).json()
    assert [m["id"] for m in literal["itens"]] == ids[:1]
    assert client.get(base, headers=auth(leitor), params={"busca": "__"}).json()["itens"] == []
    assert client.get(base, headers=auth(leitor), params={"busca": "  "}).status_code == 422
    assert client.get(base, headers=auth(leitor), params={"busca": "oficina", "cursor": "invalido"}).status_code == 422
    original = f"{base}/{ids[0]}"
    assert client.get(original, headers=auth(leitor)).json()["conteudo"] == "Oficina 100% pronta"
    assert client.get(f"{base}/{privada['id']}", headers=auth(leitor)).status_code == 404
    assert client.get(original, headers=auth(fora)).status_code == 404
    assert client.get(base, headers=auth(fora), params={"busca": "oficina"}).status_code == 404
    assert client.get(original).status_code == 401
    if equipe:
        # Searching/inspecting an old message must not mark the whole chat read.
        assert client.get("/api/v1/equipes/meu-chat/resumo", headers=auth(leitor)).json()["total_nao_lidas"] == 4
    client.patch(original, headers=auth(autor), json={"conteudo": "outro texto"})
    assert client.get(original, headers=auth(leitor)).json()["conteudo"] == "outro texto"
    assert client.get(base, headers=auth(leitor), params={"busca": "100%"}).json()["itens"] == []
    client.delete(original, headers=auth(autor))
    apagada = client.get(original, headers=auth(leitor)).json()
    assert apagada["conteudo"] == "" and apagada["excluida_em"]
    assert client.get(base, headers=auth(leitor), params={"busca": "outro texto"}).json()["itens"] == []
    if equipe:
        assert client.delete(f"{grupo_base}/membros/{leitor['usuario']['id']}", headers=auth(autor)).status_code == 204
    else:
        assert client.put(f"/api/v1/usuarios/{leitor['usuario']['id']}/bloqueio", headers=auth(autor)).status_code == 204
    assert client.get(original, headers=auth(leitor)).status_code == 404
    assert client.get(base, headers=auth(leitor), params={"busca": "oficina"}).status_code == 404
