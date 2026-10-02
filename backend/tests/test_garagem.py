from datetime import date, timedelta

from test_carros_flow import imagem_png
from test_feed_seguindo import auth, cadastrar, criar_evolucao


def test_identidade_opcional_preserva_projetos_antigos_e_edicao_parcial(client):
    owner = cadastrar(client, "garagem.dono")
    response = client.post('/api/v1/carros', headers=auth(owner), json={'modelo': 'Omega'})
    assert response.status_code == 201
    car = response.json()
    assert car['nome_projeto'] is None
    path = f"/api/v1/carros/{car['id']}"
    data = {'nome_projeto': '  Meu seis canecos  ', 'proposta': 'Uso diário e estrada',
            'adquirido_em': '2020-01-15', 'estado_inicial': 'Original',
            'configuracao_original': '4.1 manual', 'modificacoes': 'Rodas e suspensão',
            'placa': 'ABC1234', 'placa_visivel': False}
    assert client.patch(path, headers=auth(owner), json=data).status_code == 200
    assert client.patch(path, headers=auth(owner), json={'cor': 'preto'}).status_code == 200
    public = client.get(path).json()
    assert public['nome_projeto'] == 'Meu seis canecos'
    assert public['configuracao_original'] == '4.1 manual'
    assert public['placa'] is None
    assert client.patch(path, headers=auth(owner), json={'adquirido_em': (date.today()+timedelta(days=1)).isoformat()}).status_code == 422
    assert client.patch(path, headers=auth(owner), json={'adquirido_em': '2020-02-31'}).status_code == 422
    assert client.patch(path, headers=auth(owner), json={'nome_projeto': ' '}).json()['nome_projeto'] is None


def test_galeria_permissoes_ordem_legendas_e_capa_independente(client):
    owner = cadastrar(client, 'galeria.dono')
    visitor = cadastrar(client, 'galeria.visita')
    evolution = criar_evolucao(client, owner, 'Omega', 'Começo')
    base = f"/api/v1/carros/{evolution['carro_id']}"
    upload = {'arquivo': ('foto.png', imagem_png(), 'image/png')}
    assert client.post(base+'/galeria', headers=auth(visitor), files=upload).status_code == 404
    assert client.post(base+'/galeria', files=upload).status_code == 401
    assert client.post(base+'/galeria', headers=auth(owner), files={'arquivo': ('x.png', b'bad', 'image/png')}).status_code == 415
    photos = []
    for _ in range(2):
        response = client.post(base+'/galeria', headers=auth(owner), files=upload)
        assert response.status_code == 201
        photos.append(response.json())
    first, second = photos
    assert client.patch(base+f"/galeria/{first['id']}", headers=auth(owner), json={'legenda': 'Na rua'}).json()['legenda'] == 'Na rua'
    assert client.put(base+'/galeria/ordem', headers=auth(owner), json={'ids': [first['id'], first['id']]}).status_code == 409
    assert client.put(base+'/galeria/ordem', headers=auth(owner), json={'ids': [second['id'], first['id']]}).status_code == 204
    assert [f['id'] for f in client.get(base+'/garagem').json()['fotos']] == [second['id'], first['id']]
    cover = client.put(base+f"/galeria/{first['id']}/capa", headers=auth(owner))
    assert cover.status_code == 200
    cover_url = cover.json()['foto_principal_url']
    assert cover_url != first['url']
    assert client.delete(base+f"/galeria/{first['id']}", headers=auth(owner)).status_code == 204
    assert client.get(first['url']).status_code == 404
    assert client.get(cover_url).status_code == 200
    assert client.delete(base, headers=auth(owner)).status_code == 204
    assert client.get(cover_url).status_code == 404
    assert client.get(second['url']).status_code == 404


def test_etapas_validam_dono_status_e_evolucao_do_mesmo_carro(client):
    owner = cadastrar(client, 'etapas.dono')
    visitor = cadastrar(client, 'etapas.visita')
    evolution = criar_evolucao(client, owner, 'Omega', 'Motor pronto')
    other = criar_evolucao(client, owner, 'Gol', 'Pintura')
    base = f"/api/v1/carros/{evolution['carro_id']}"
    payload = {'titulo': 'Revisar motor', 'status': 'planejada'}
    assert client.post(base+'/etapas', headers=auth(visitor), json=payload).status_code == 404
    assert client.post(base+'/etapas', headers=auth(owner), json={'titulo': ' '}).status_code == 422
    created = client.post(base+'/etapas', headers=auth(owner), json=payload)
    assert created.status_code == 201
    path = base+f"/etapas/{created.json()['id']}"
    assert client.put(path, headers=auth(owner), json={**payload, 'evolucao_id': evolution['id']}).status_code == 422
    completed = {**payload, 'status': 'concluida', 'evolucao_id': evolution['id']}
    assert client.put(path, headers=auth(owner), json={**completed, 'evolucao_id': other['id']}).status_code == 404
    assert client.put(path, headers=auth(owner), json=completed).status_code == 200
    assert client.get(base+'/garagem').json()['etapas'][0]['evolucao_id'] == evolution['id']
    assert client.put(path, headers=auth(owner), json={**payload, 'status': 'em_andamento'}).json()['evolucao_id'] is None
    assert client.delete(path, headers=auth(visitor)).status_code == 404
    assert client.delete(path, headers=auth(owner)).status_code == 204
    assert client.get(base+'/evolucoes').json()[0]['id'] == evolution['id']


def test_galeria_limita_doze_fotos_e_rejeita_foto_de_outro_carro(client):
    owner = cadastrar(client, 'galeria.limite')
    first = criar_evolucao(client, owner, 'Omega', 'Começo')
    other = criar_evolucao(client, owner, 'Gol', 'Começo')
    base = f"/api/v1/carros/{first['carro_id']}"
    for _ in range(12):
        response = client.post(base+'/galeria', headers=auth(owner), files={'arquivo': ('a.png', imagem_png(), 'image/png')})
        assert response.status_code == 201
    assert client.post(base+'/galeria', headers=auth(owner), files={'arquivo': ('a.png', imagem_png(), 'image/png')}).status_code == 409
    photo_id = response.json()['id']
    assert client.put(f"/api/v1/carros/{other['carro_id']}/galeria/{photo_id}/capa", headers=auth(owner)).status_code == 404


def test_excluir_evolucao_desvincula_etapa_sem_apagar_planejamento(client):
    from sqlalchemy import text
    from app.core.database import get_db

    # Exercita a mesma ação SET NULL da FK no PostgreSQL.
    session_generator = client.app.dependency_overrides[get_db]()
    session = next(session_generator)
    session.execute(text("PRAGMA foreign_keys=ON"))
    session.commit()
    session_generator.close()
    owner = cadastrar(client, 'vinculo.dono')
    evolution = criar_evolucao(client, owner, 'Omega', 'Revisão pronta')
    base = f"/api/v1/carros/{evolution['carro_id']}"
    stage = client.post(base+'/etapas', headers=auth(owner), json={
        'titulo': 'Revisar motor', 'status': 'concluida', 'evolucao_id': evolution['id']})
    assert stage.status_code == 201
    assert client.delete(base+f"/evolucoes/{evolution['id']}", headers=auth(owner)).status_code == 204
    remaining = client.get(base+'/garagem').json()['etapas']
    assert len(remaining) == 1
    assert remaining[0]['evolucao_id'] is None
    assert remaining[0]['status'] == 'concluida'
