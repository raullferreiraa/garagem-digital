# Arquitetura atual (mobile)

## Componentes

- [`mobile/`](../mobile/): aplicativo Flutter para Android; armazena tokens no
  armazenamento seguro e acessa a API por HTTP no ambiente local de depuração.
- [`backend/`](../backend/): API FastAPI em `/api/v1`, com autenticação,
  regras de acesso e SQLAlchemy.
- PostgreSQL/PostGIS: dados relacionais, com migrations em
  [`backend/alembic/versions/`](../backend/alembic/versions/).
- Imagens: salvas em `MEDIA_ROOT`. No Compose local, o volume `media_data`
  mantém os arquivos em `/data/media` e a API os serve em `/media`.

O aplicativo não acessa o banco diretamente. A API verifica identidade,
propriedade dos carros e permissões das equipes. O arquivo
[`database/schema.sql`](../database/schema.sql) é o snapshot inicial do banco;
as mudanças seguintes são aplicadas pelas migrations.

A [versão web legada](../legacy/web/) usa Flask e MySQL/MariaDB, com banco
independente. Seu estado anterior à migração está preservado na branch
[`legacy/web-v1`](https://github.com/raullferreiraa/garagem-digital/tree/legacy/web-v1).

## Regras do produto

1. Cada carro representa um projeto com ficha e histórico de evoluções.
2. Entrar em uma equipe não adiciona automaticamente os carros do integrante:
   ele escolhe qual carro representa seu projeto na garagem coletiva.
3. O aplicativo e a API usam o termo `equipe`.
4. E-mail não faz parte do perfil público. A placa só aparece quando o
   proprietário habilita a exibição de forma explícita.
5. Edição e exclusão de carros exigem autenticação e vínculo com o proprietário.
6. O catálogo de carros aceita paginação por cursor. O feed de pessoas seguidas
   tem seu próprio limite de itens.

## Estado de desenvolvimento

- Login usa access token JWT e refresh token opaco, rotativo e revogável;
  apenas o hash do refresh token fica no banco.
- Uploads de carros, evoluções, perfis e equipes já usam o armazenamento local
  descrito acima. Uma implantação futura deverá definir armazenamento durável,
  backup e URLs públicas adequadas ao ambiente de produção.
- Apenas a estrutura Android está versionada em `mobile/`. A configuração de
  iOS e os testes nessa plataforma ficam para uma etapa própria.

Para executar localmente, consulte o [README principal](../README.md).
