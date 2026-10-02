import base64
import json
import asyncio

import pytest
from fastapi import HTTPException
from sqlalchemy import event

from app.api.routes.feed import _decode_cursor
from app.core.database import get_db
from app.services import carros, chat_equipe, conversas, projetos_salvos
from test_feed_seguindo import auth, cadastrar, criar_evolucao
from test_carros_flow import imagem_png


@pytest.mark.parametrize("decode", [
    carros._decodificar_cursor,
    carros._decodificar_cursor_busca,
    carros._decodificar_cursor_em_alta,
    conversas._decodificar_cursor,
    projetos_salvos._decodificar_cursor,
    chat_equipe._ler_cursor,
    _decode_cursor,
])
@pytest.mark.parametrize("invalid_id", [42, [], {}, True])
def test_cursor_rejeita_id_de_tipo_invalido(decode, invalid_id):
    payload = dict(id=invalid_id, carro_id=invalid_id, relevancia=1, pontuacao=1,
                   data="2026-10-01T12:00:00+00:00",
                   criado_em="2026-10-01T12:00:00+00:00",
                   criada_em="2026-10-01T12:00:00+00:00")
    cursor = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode()
    with pytest.raises((ValueError, HTTPException)):
        decode(cursor)


def test_feed_nao_faz_uma_consulta_por_projeto(client):
    leitor = cadastrar(client, "leitor.custo")
    seguido = cadastrar(client, "seguido.custo")
    client.put(f"/api/v1/usuarios/{seguido['usuario']['id']}/seguir", headers=auth(leitor))
    for i in range(5):
        criar_evolucao(client, seguido, f"Projeto {i}", f"Etapa {i}")

    provider = client.app.dependency_overrides[get_db]()
    db = next(provider)
    statements = []

    def count(_conn, _cursor, statement, _parameters, _context, _many):
        if statement.lstrip().upper().startswith("SELECT"):
            statements.append(statement)

    event.listen(db.bind, "before_cursor_execute", count)
    try:
        small = client.get("/api/v1/feed/seguindo/pagina?limite=1", headers=auth(leitor))
        small_count = len(statements)
        statements.clear()
        large = client.get("/api/v1/feed/seguindo/pagina?limite=5", headers=auth(leitor))
        assert small.status_code == large.status_code == 200
        assert len(large.json()["itens"]) == 5
        assert len(statements) <= small_count, (small_count, len(statements))
        assert len(statements) == 3
    finally:
        event.remove(db.bind, "before_cursor_execute", count)
        provider.close()


@pytest.mark.parametrize("kind", ["avatar", "carro", "evolucao", "equipe", "encontro"])
def test_processamento_de_imagem_nao_bloqueia_event_loop(client, monkeypatch, kind):
    from app.services import media

    tokens = cadastrar(client, "avatar.worker")
    if kind == "avatar":
        path = "/api/v1/usuarios/me/avatar"
    elif kind in {"carro", "evolucao"}:
        evolution = criar_evolucao(client, tokens, "Omega", "Reforma")
        path = f"/api/v1/carros/{evolution['carro_id']}"
        path += ("/foto-principal" if kind == "carro"
                 else f"/evolucoes/{evolution['id']}/fotos")
    elif kind == "equipe":
        response = client.post("/api/v1/equipes", headers=auth(tokens),
                               json={"nome": "Equipe de teste"})
        assert response.status_code == 201
        path = f"/api/v1/equipes/{response.json()['id']}/imagens/avatar"
    else:
        response = client.post("/api/v1/eventos", headers=auth(tokens),
                               json={"nome": "Encontro de teste", "cidade": "Vila Velha",
                                     "estado": "ES", "organizador": "usuario"})
        assert response.status_code == 201
        path = f"/api/v1/eventos/{response.json()['id']}/capa"
    original = media._salvar_imagem
    running_on_loop = []

    def checked_save(*args):
        try:
            asyncio.get_running_loop()
        except RuntimeError:
            running_on_loop.append(False)
        else:
            running_on_loop.append(True)
        return original(*args)

    monkeypatch.setattr(media, "_salvar_imagem", checked_save)
    response = client.post(path, headers=auth(tokens),
                           files={"arquivo": ("foto.png", imagem_png(), "image/png")})
    assert response.status_code == 200
    assert running_on_loop == [False]


def test_feed_devolve_400_para_cursor_com_id_numerico(client):
    tokens = cadastrar(client, "cursor.invalido")
    cursor = base64.urlsafe_b64encode(json.dumps({
        "data": "2026-10-01T12:00:00+00:00", "id": 42,
    }).encode()).decode()
    response = client.get("/api/v1/feed/seguindo/pagina", headers=auth(tokens),
                          params={"cursor": cursor})
    assert response.status_code == 400
