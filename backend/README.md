# Backend da Garagem Digital

API FastAPI usada pelo aplicativo Flutter.

## Arquitetura

- FastAPI como camada HTTP.
- PostgreSQL como banco relacional.
- PostGIS preparado para eventos e buscas por proximidade.
- SQLAlchemy para conexoes e transacoes.
- Configuracao exclusivamente por variaveis de ambiente.
- Dominio padronizado em portugues, usando `equipe` em vez de `clube`.
- A garagem coletiva usa uma associacao explicita: entrar em uma equipe nao publica
  automaticamente todos os carros do integrante.

O backend Flask em [`legacy/web/`](../legacy/web/) pertence a versao web anterior.
Consulte a branch `legacy/web-v1` para o snapshot original; o desenvolvimento
ativo usa esta API.
As duas versoes tem bancos separados e nao compartilham automaticamente os dados.

## Execucao local

### Opcao recomendada: Docker

Na raiz do repositorio:

```bash
cp .env.example .env
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

Execute os comandos desta opção a partir de `backend/`.

1. Copie `.env.example` para `.env` e configure `DATABASE_URL` e
   `JWT_SECRET`.
2. Inicie o PostgreSQL com PostGIS.
3. Crie um ambiente virtual e instale as dependências:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt -r requirements-dev.txt
```

No Linux ou macOS, substitua a linha de ativação por `source .venv/bin/activate`.

4. Aplique todas as migrations: `alembic upgrade head`.
5. Inicie a API: `uvicorn app.main:app --reload`.
6. Verifique `http://127.0.0.1:8000/api/v1/health`.

Para executar os testes locais após instalar as dependências de desenvolvimento, use
`python -m pytest -q tests` dentro de `backend/`.

## Banco e migrations

`../database/schema.sql` e o snapshot inicial da primeira versao do banco. Mudancas
posteriores devem ser criadas como novas revisions em `backend/alembic/versions`.

```bash
alembic upgrade head
alembic current
```

Para criar uma migration futura:

```bash
alembic revision -m "descreva a mudanca"
```

## Algumas rotas disponíveis

A documentação completa e atualizada da API em execução fica em
`http://127.0.0.1:8000/docs`. A lista abaixo mostra apenas as rotas principais.

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

### Diario de evolucoes

- `GET /api/v1/carros/{carro_id}/evolucoes`
- `POST /api/v1/carros/{carro_id}/evolucoes`
- `PATCH /api/v1/carros/{carro_id}/evolucoes/{evolucao_id}`
- `DELETE /api/v1/carros/{carro_id}/evolucoes/{evolucao_id}`

O feed e o diario sao publicos para leitura. Somente o proprietario pode alterar o
carro e registrar, editar ou excluir suas evolucoes. Campos privados, como email e
placa, nao sao expostos em perfis e carros publicos. A placa so aparece publicamente
quando seu proprietario habilita `placa_visivel` de forma explicita.
