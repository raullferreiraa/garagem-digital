from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select

from app.core.database import get_db
from app.models.evento import Encontro, Evento, ParticipacaoEquipeEvento, PresencaEvento, SeguidorEncontro
from tests.test_eventos import auth, cadastrar


def preparar(client):
    dono = cadastrar(client, 'foto.dono')
    membro = cadastrar(client, 'foto.membro')
    externo = cadastrar(client, 'foto.externo')
    equipe = client.post('/api/v1/equipes', headers=auth(dono), json={'nome': 'Equipe Fotos'}).json()
    base = f"/api/v1/equipes/{equipe['id']}"
    assert client.post(f'{base}/solicitacoes', headers=auth(membro)).status_code == 204
    pedido = client.get(base, headers=auth(dono)).json()['solicitacoes_pendentes'][0]['id']
    assert client.patch(f'{base}/solicitacoes/{pedido}', headers=auth(dono), json={'decisao': 'aprovar'}).status_code == 204
    encontro = client.post('/api/v1/eventos', headers=auth(externo), json={
        'nome': 'Comunidade teste',
        'proxima_edicao': {'inicio': (datetime.now(timezone.utc) + timedelta(days=3)).isoformat()},
    }).json()
    return dono, membro, externo, equipe, encontro


def test_confirmacao_coletiva_respeita_cancelamento_individual(client):
    dono, membro, externo, equipe, encontro = preparar(client)
    base = f"/api/v1/eventos/{encontro['id']}"
    params = {'edicao_id': encontro['edicao_id']}
    dados = {'confirmar_integrantes': True}
    assert client.put(f'{base}/minha-equipe', headers=auth(membro), params=params, json=dados).status_code == 403
    assert client.put(f'{base}/minha-equipe', headers=auth(externo), params=params, json=dados).status_code == 403
    # Opt-in only: simply taking the team does not confirm its members.
    resposta = client.put(f'{base}/minha-equipe', headers=auth(dono), params=params, json={}).json()
    assert resposta['total_confirmados'] == 0
    assert resposta['minha_equipe_total_integrantes'] == 2
    for _ in range(2):
        resposta = client.put(f'{base}/minha-equipe', headers=auth(dono), params=params, json=dados)
        assert resposta.status_code == 200
        assert resposta.json()['total_confirmados'] == 2
    assert client.delete(f'{base}/minha-presenca', headers=auth(membro), params=params).json()['minha_presenca'] is None
    assert client.put(f'{base}/minha-equipe', headers=auth(dono), params=params, json=dados).json()['total_confirmados'] == 1
    # Removing a team does not remove individual confirmations.
    assert client.delete(f'{base}/minha-equipe', headers=auth(dono), params=params).json()['total_confirmados'] == 1
    assert client.put(f'{base}/minha-presenca', headers=auth(membro), params=params, json={}).json()['total_confirmados'] == 2


def test_excluir_comunidade_exige_organizacao_e_remove_dependencias(client):
    dono, membro, externo, equipe, encontro = preparar(client)
    base = f"/api/v1/eventos/{encontro['id']}"
    client.put(f'{base}/minha-equipe', headers=auth(dono), json={'confirmar_integrantes': True})
    assert client.delete(base, headers=auth(dono)).status_code == 403
    assert client.delete(base, headers=auth(membro)).status_code == 403
    assert client.get(base, headers=auth(externo)).status_code == 200
    assert client.delete(base, headers=auth(externo)).status_code == 204
    assert client.get(base, headers=auth(externo)).status_code == 404
    with next(client.app.dependency_overrides[get_db]()) as db:
        for model in [Encontro, Evento, PresencaEvento, ParticipacaoEquipeEvento, SeguidorEncontro]:
            assert db.scalar(select(func.count()).select_from(model)) == 0
    assert client.get(f"/api/v1/equipes/{equipe['id']}", headers=auth(dono)).status_code == 200


def test_detalhe_equipe_informa_vinculo_atual(client):
    dono, membro, externo, equipe, encontro = preparar(client)
    outra = client.post('/api/v1/equipes', headers=auth(externo), json={'nome': 'Outra equipe'}).json()
    resposta = client.get(f"/api/v1/equipes/{outra['id']}", headers=auth(membro)).json()
    assert resposta['meu_papel'] is None
    assert resposta['minha_equipe_id'] == equipe['id']
    assert resposta['minha_equipe_nome'] == equipe['nome']
