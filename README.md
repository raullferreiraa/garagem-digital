# Garagem Digital 🚘

A Garagem Digital é um projeto social para registrar carros, acompanhar suas evoluções e reunir pessoas em equipes automotivas.

**Versão atual:** aplicativo Flutter para Android, acompanhado por uma API FastAPI e PostgreSQL/PostGIS. Esta é uma primeira versão mobile em desenvolvimento, validada localmente; ainda não é uma publicação nas lojas de aplicativos.

## Estrutura do repositório

| Diretório ou arquivo | Finalidade |
| --- | --- |
| [`mobile/`](mobile/) | Aplicativo Flutter |
| [`backend/`](backend/) | API FastAPI e migrations Alembic |
| [`database/`](database/) | Snapshot inicial do esquema PostgreSQL |
| [`compose.yaml`](compose.yaml) | Ambiente local da API e do banco |
| [`legacy/web/`](legacy/web/) | Versão web anterior (Flask, MySQL, HTML, CSS e JavaScript), com código e capturas de tela |

A [versão web legada](legacy/web/README.md) está organizada em `legacy/web/`, inclusive com as capturas de tela. Seu estado original antes da versão mobile também está preservado na branch [`legacy/web-v1`](https://github.com/raullferreiraa/garagem-digital/tree/legacy/web-v1). Ela usa Flask e MySQL/MariaDB; não se conecta automaticamente ao banco ou à API mobile. O desenvolvimento ativo acontece no aplicativo e no novo backend.

## Rodar localmente (Windows / PowerShell)

Requisitos: Docker Desktop em execução, Flutter configurado e um emulador Android aberto.

Na raiz do repositório, prepare as variáveis locais:

```powershell
Copy-Item .env.compose.example .env
```

Abra `.env` e defina valores **não vazios** para `POSTGRES_PASSWORD` e `JWT_SECRET`. Não inclua esse arquivo em commits. Inicie o banco e a API:

```powershell
docker compose up --build
```

Em outro terminal, na raiz do repositório:

```powershell
cd mobile
flutter pub get
flutter run
```

O emulador Android acessa a API do computador por `http://10.0.2.2:8000/api/v1` por padrão. Para testar em um celular físico, use `flutter run --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:8000/api/v1` e configure a rede para permitir o acesso à porta 8000. A API oferece um health check em `http://localhost:8000/api/v1/health`.

Instruções complementares: [aplicativo](mobile/README.md) e [backend](backend/README.md).

## Funcionalidades da primeira versão mobile

- Cadastro e login, perfil, seguidores e notificações.
- Garagem pessoal, fotos dos carros e histórico de evoluções.
- Explorar projetos, pesquisa, comentários, respostas e curtidas.
- Equipes, convites, solicitações e gestão dos integrantes.

O projeto segue em evolução: experiência visual, desempenho e funcionalidades continuam sendo aprimorados. O código mobile atual foi testado principalmente no Android; a disponibilidade em iOS exige configuração e testes próprios.

## Autor

Desenvolvido por [Raul Ferreira](https://github.com/raullferreiraa).
