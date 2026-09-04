# Backend mobile

Nova API do projeto, criada para atender o aplicativo Flutter.

## Decisoes desta fundacao

- FastAPI como camada HTTP.
- PostgreSQL como banco relacional.
- PostGIS preparado para eventos e buscas por proximidade.
- SQLAlchemy para conexoes e transacoes.
- Configuracao exclusivamente por variaveis de ambiente.
- Dominio padronizado em portugues, usando `equipe` em vez de `clube`.
- A garagem coletiva usa uma associacao explicita: entrar em uma equipe nao publica
  automaticamente todos os carros do integrante.

O backend Flask que esta na raiz continua sendo a referencia funcional durante a
migracao. Nenhuma tela ou rota antiga deve ser removida antes de existir uma
substituta testada na API nova.

## Execucao local

### Opcao recomendada: Docker

Na raiz do repositorio:

```bash
cp .env.compose.example .env
# Preencha POSTGRES_PASSWORD e JWT_SECRET com valores locais fortes.
# Para a senha local do PostgreSQL, use letras e numeros para evitar codificacao na URL.
docker compose up --build
```

Esse comando inicia a API em `http://127.0.0.1:8000` e um PostgreSQL 17 com
PostGIS 3.5. Antes de iniciar o servidor, o Alembic aplica todas as migrations.

Para recriar completamente o banco de desenvolvimento:

```bash
docker compose down --volumes
docker compose up --build
```

Esse comando remove apenas o volume local criado pelo Compose. Nao deve ser usado
em um ambiente que contenha dados importantes.

### Opcao manual

1. Copie `.env.example` para `.env`.
2. Inicie o PostgreSQL com PostGIS e execute `database/schema.sql`.
3. Crie um ambiente virtual e instale as dependencias:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt -r requirements-dev.txt
```

4. Inicie a API:

```bash
uvicorn app.main:app --reload
```

5. Verifique `http://127.0.0.1:8000/api/v1/health`.

## Banco e migrations

`database/schema.sql` e o snapshot imutavel da primeira versao do banco. Mudancas
posteriores devem ser criadas como novas revisions em `backend/alembic/versions`.

```bash
alembic upgrade head
alembic current
```

Para criar uma migration futura:

```bash
alembic revision -m "descreva a mudanca"
```

## Contratos disponiveis

### Autenticacao

- `POST /api/v1/auth/cadastro`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

### Perfis

- `PATCH /api/v1/usuarios/me`
- `GET /api/v1/usuarios/{usuario_id}`
- `GET /api/v1/usuarios/{usuario_id}/carros`

### Carros

- `POST /api/v1/carros`
- `GET /api/v1/carros`
- `GET /api/v1/carros/meus`
- `GET /api/v1/carros/{carro_id}`
- `PATCH /api/v1/carros/{carro_id}`
- `DELETE /api/v1/carros/{carro_id}`

O feed usa paginacao por cursor. Campos privados, como email e placa, nao sao
expostos em perfis e carros publicos. A placa so aparece publicamente quando seu
proprietario habilita `placa_visivel` de forma explicita.
