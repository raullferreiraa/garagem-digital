from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient
from uuid import UUID
from app.main import app
from app.core.database import get_db
from app.models.evento import Evento


def cadastrar(client: TestClient, username: str) -> dict:
    response = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": username.title(),
            "username": username,
            "email": f"{username}@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert response.status_code == 201
    return response.json()


def auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_encontro_individual_e_confirmacao_de_presenca(client: TestClient) -> None:
    organizador = cadastrar(client, "organizador.evento")
    visitante = cadastrar(client, "visitante.evento")
    inicio = datetime.now(timezone.utc) + timedelta(days=7)

    criado = client.post(
        "/api/v1/eventos",
        headers=auth(organizador),
        json={
            "nome": "Encontro de clássicos",
            "descricao": "Uma manhã para reunir projetos antigos.",
            "cidade": "Vila Velha",
            "estado": "ES",
            "organizador": "usuario",
            "proxima_edicao": {
                "inicio": inicio.isoformat(),
                "endereco_publico": "Praça do Motor",
            },
        },
    )
    assert criado.status_code == 201
    evento = criado.json()
    assert evento["organizador_tipo"] == "usuario"
    assert evento["total_confirmados"] == 0
    assert evento["seguindo"] is True
    assert evento["total_seguidores"] == 1

    lista = client.get("/api/v1/eventos", headers=auth(visitante))
    assert lista.status_code == 200
    assert [item["id"] for item in lista.json()] == [evento["id"]]

    seguida = client.put(
        f"/api/v1/eventos/{evento['id']}/seguindo", headers=auth(visitante)
    )
    assert seguida.status_code == 200
    assert seguida.json()["total_seguidores"] == 2

    confirmada = client.put(
        f"/api/v1/eventos/{evento['id']}/minha-presenca",
        headers=auth(visitante),
        json={"status": "confirmada"},
    )
    assert confirmada.status_code == 200
    assert confirmada.json()["minha_presenca"] == "confirmada"
    assert confirmada.json()["total_confirmados"] == 1

    cancelada = client.delete(
        f"/api/v1/eventos/{evento['id']}/minha-presenca",
        headers=auth(visitante),
    )
    assert cancelada.status_code == 200
    assert cancelada.json()["minha_presenca"] is None
    assert cancelada.json()["total_confirmados"] == 0


def test_equipe_organiza_e_apenas_lideranca_pode_representar(client: TestClient) -> None:
    dono = cadastrar(client, "dono.evento")
    membro = cadastrar(client, "membro.evento")
    equipe = client.post(
        "/api/v1/equipes", headers=auth(dono), json={"nome": "Equipe do Encontro"}
    ).json()
    base = f"/api/v1/equipes/{equipe['id']}"
    client.post(f"{base}/solicitacoes", headers=auth(membro))
    solicitacao = client.get(base, headers=auth(dono)).json()[
        "solicitacoes_pendentes"
    ][0]["id"]
    client.patch(
        f"{base}/solicitacoes/{solicitacao}",
        headers=auth(dono),
        json={"decisao": "aprovar"},
    )
    inicio = datetime.now(timezone.utc) + timedelta(days=3)

    proibido = client.post(
        "/api/v1/eventos",
        headers=auth(membro),
        json={
            "nome": "Evento indevido",
            "organizador": "equipe",
            "proxima_edicao": {"inicio": inicio.isoformat()},
        },
    )
    assert proibido.status_code == 403

    criado = client.post(
        "/api/v1/eventos",
        headers=auth(dono),
        json={
            "nome": "Rolê oficial da equipe",
            "organizador": "equipe",
            "visibilidade": "somente_equipe",
            "proxima_edicao": {"inicio": inicio.isoformat()},
        },
    )
    assert criado.status_code == 201
    evento = criado.json()
    assert evento["organizador_tipo"] == "equipe"
    assert evento["total_equipes"] == 1
    assert evento["minha_equipe_participacao"] == "confirmada"
    assert evento["posso_gerenciar"] is True

    detalhe_membro = client.get(
        f"/api/v1/eventos/{evento['id']}", headers=auth(membro)
    )
    assert detalhe_membro.status_code == 200
    assert detalhe_membro.json()["minha_equipe_nome"] == "Equipe do Encontro"


def test_comunidade_sem_data_edicoes_independentes_e_historico(client: TestClient) -> None:
    dono = cadastrar(client, "ciclo.dono")
    visitante = cadastrar(client, "ciclo.visitante")
    response = client.post("/api/v1/eventos", headers=auth(dono), json={"nome": "Domingo de clássicos"})
    assert response.status_code == 201
    comunidade = response.json()
    base = f"/api/v1/eventos/{comunidade['id']}"
    assert comunidade["edicao_id"] is None
    assert comunidade["edicoes"] == []
    assert client.get("/api/v1/eventos", headers=auth(visitante)).json()[0]["id"] == comunidade["id"]
    assert client.put(f"{base}/seguindo", headers=auth(visitante)).json()["total_seguidores"] == 2
    assert client.put(f"{base}/seguindo", headers=auth(visitante)).json()["total_seguidores"] == 2
    assert client.put(f"{base}/minha-presenca", headers=auth(visitante), json={}).status_code == 403
    data = {"inicio": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(), "endereco_publico": "Praça"}
    assert client.post(f"{base}/edicoes", headers=auth(visitante), json=data).status_code == 403
    primeira = client.post(f"{base}/edicoes", headers=auth(dono), json=data).json()
    assert primeira["edicao_id"]
    client.put(f"{base}/minha-presenca", headers=auth(visitante), json={})
    with next(app.dependency_overrides[get_db]()) as db:
        edicao = db.get(Evento, UUID(primeira["edicao_id"]))
        edicao.inicio = datetime.now(timezone.utc) - timedelta(days=1)
        db.commit()
    historico = client.get(base, headers=auth(visitante))
    assert historico.status_code == 200
    assert historico.json()["edicao_id"] is None
    assert historico.json()["edicoes"][0]["total_confirmados"] == 1
    assert client.get("/api/v1/eventos", headers=auth(visitante)).json()[0]["id"] == comunidade["id"]
    segunda = client.post(f"{base}/edicoes", headers=auth(dono), json=data).json()
    assert segunda["edicao_id"] != primeira["edicao_id"]
    assert segunda["total_confirmados"] == 0
    assert segunda["total_seguidores"] == 2
    assert client.put(f"{base}/minha-presenca", headers=auth(visitante),
                      params={"edicao_id": primeira["edicao_id"]}, json={}).status_code == 403
    assert client.get(base, headers=auth(visitante)).json()["minha_presenca"] is None


def test_edicao_datas_e_nome_invalidos(client: TestClient) -> None:
    dono = cadastrar(client, "validacao.evento")
    assert client.post("/api/v1/eventos", headers=auth(dono), json={"nome": "   "}).status_code == 422
    base = "/api/v1/eventos"
    inicio = datetime.now(timezone.utc) + timedelta(days=3)
    response = client.post(base, headers=auth(dono), json={
        "nome": "Teste datas", "proxima_edicao": {
            "inicio": inicio.isoformat(),
            "termino": (inicio - timedelta(hours=1)).replace(tzinfo=None).isoformat()
        }})
    assert response.status_code == 422


def test_criador_perde_gestao_ao_transferir_lideranca(client: TestClient) -> None:
    dono = cadastrar(client, "gestao.antigo")
    novo = cadastrar(client, "gestao.novo")
    equipe = client.post("/api/v1/equipes", headers=auth(dono), json={"nome": "Equipe clássicos"}).json()
    base = f"/api/v1/equipes/{equipe['id']}"
    client.post(f"{base}/convites", headers=auth(dono), json={"usuario_id": novo["usuario"]["id"]})
    client.patch(f"{base}/meu-convite", headers=auth(novo), json={"decisao": "aceitar"})
    encontro = client.post("/api/v1/eventos", headers=auth(dono),
                          json={"nome": "Reunião da equipe", "organizador": "equipe", "visibilidade": "somente_equipe"}).json()
    assert client.patch(f"{base}/lideranca", headers=auth(dono), json={"usuario_id": novo["usuario"]["id"]}).status_code == 204
    assert client.patch(f"{base}/membros/{dono['usuario']['id']}/papel", headers=auth(novo), json={"papel": "membro"}).status_code == 204
    url = f"/api/v1/eventos/{encontro['id']}"
    assert client.get(url, headers=auth(dono)).json()["posso_gerenciar"] is False
    assert client.patch(url, headers=auth(dono), json={"nome": "Indevido"}).status_code == 403
    assert client.get(url, headers=auth(novo)).json()["posso_gerenciar"] is True
    assert client.delete(f"{base}/membros/{dono['usuario']['id']}", headers=auth(dono)).status_code == 204
    assert client.get(url, headers=auth(dono)).status_code == 404


def test_edicao_comunidade_e_capa_exigem_organizador(client: TestClient, tmp_path, monkeypatch) -> None:
    from app.core.config import settings
    from PIL import Image
    from io import BytesIO
    monkeypatch.setattr(settings, "media_root", tmp_path)
    dono = cadastrar(client, "capa.dono")
    fora = cadastrar(client, "capa.fora")
    encontro = client.post("/api/v1/eventos", headers=auth(dono), json={"nome": "Clássicos ES"}).json()
    base = f"/api/v1/eventos/{encontro['id']}"
    assert client.patch(base, headers=auth(fora), json={"nome": "Invasão"}).status_code == 403
    edited = client.patch(base, headers=auth(dono), json={"nome": "Clássicos da praia", "descricao": "Nossa história"})
    assert edited.status_code == 200
    assert edited.json()["descricao"] == "Nossa história"
    assert client.post(f"{base}/capa", headers=auth(fora), files={"arquivo": ("capa.jpg", b"x", "image/jpeg")}).status_code == 403
    assert client.post(f"{base}/capa", headers=auth(dono), files={"arquivo": ("capa.jpg", b"x", "image/jpeg")}).status_code == 415
    image = BytesIO()
    Image.new("RGB", (32, 32), "orange").save(image, format="PNG")
    uploaded = client.post(f"{base}/capa", headers=auth(dono), files={"arquivo": ("capa.png", image.getvalue(), "image/png")})
    assert uploaded.status_code == 200
    assert uploaded.json()["capa_url"].startswith("/media/encontros/")


def test_edicoes_podem_usar_regiao_base_ou_outro_local_e_ser_canceladas(
    client: TestClient,
) -> None:
    dono = cadastrar(client, "rota.dono")
    visitante = cadastrar(client, "rota.visitante")
    inicio = datetime.now(timezone.utc) + timedelta(days=4)
    encontro = client.post(
        "/api/v1/eventos",
        headers=auth(dono),
        json={
            "nome": "Clássicos itinerantes",
            "cidade": "Vila Velha",
            "estado": "ES",
            "proxima_edicao": {
                "inicio": inicio.isoformat(),
                "endereco_publico": "Praça principal",
            },
        },
    ).json()
    base = f"/api/v1/eventos/{encontro['id']}"
    primeira_id = encontro["edicao_id"]
    assert encontro["cidade"] == "Vila Velha"
    assert encontro["edicao_cidade"] == "Vila Velha"
    assert encontro["edicoes"][0]["status"] == "agendada"

    outra = client.post(
        f"{base}/edicoes",
        headers=auth(dono),
        json={
            "inicio": (inicio + timedelta(days=10)).isoformat(),
            "endereco_publico": "Autódromo",
            "usar_regiao_comunidade": False,
            "cidade": "Curitiba",
            "estado": "PR",
        },
    )
    assert outra.status_code == 201
    outra_id = next(
        item["id"] for item in outra.json()["edicoes"] if item["id"] != primeira_id
    )
    assert next(
        item for item in outra.json()["edicoes"] if item["id"] == outra_id
    )["cidade"] == "Curitiba"

    alterada = client.patch(
        f"{base}/edicoes/{primeira_id}",
        headers=auth(dono),
        json={
            "inicio": (inicio + timedelta(hours=2)).isoformat(),
            "endereco_publico": "Píer atualizado",
            "usar_regiao_comunidade": True,
        },
    )
    assert alterada.status_code == 200
    assert alterada.json()["endereco_publico"] == "Píer atualizado"
    assert alterada.json()["edicao_cidade"] == "Vila Velha"
    assert client.patch(
        f"{base}/edicoes/{primeira_id}",
        headers=auth(visitante),
        json={"inicio": (inicio + timedelta(days=1)).isoformat()},
    ).status_code == 403

    cancelada = client.post(
        f"{base}/edicoes/{primeira_id}/cancelamento", headers=auth(dono)
    )
    assert cancelada.status_code == 200
    resultado = cancelada.json()
    assert resultado["edicao_id"] == outra_id
    assert resultado["edicao_cidade"] == "Curitiba"
    assert next(
        item for item in resultado["edicoes"] if item["id"] == primeira_id
    )["status"] == "cancelada"
    assert client.put(
        f"{base}/minha-presenca",
        headers=auth(visitante),
        params={"edicao_id": primeira_id},
        json={},
    ).status_code == 403
