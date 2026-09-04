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

