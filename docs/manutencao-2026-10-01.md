# Manutenção Garona — 01/10/2026

Branch: `codex/manutencao-geral`, criada de `origin/main` após o merge da PR #196.

## Revisão

Inspeção dos caminhos de autenticação, paginação/busca, feed, upload de mídia,
rascunhos, ciclo de vida das conversas, notificações, projetos, equipes,
encontros e compartilhamento, complementada pelas suítes automatizadas.
As alterações desta PR se concentram nos problemas reproduzidos abaixo.
Não representa uma certificação de ausência de defeitos em todos os fluxos.

## Problemas reproduzidos e corrigidos

1. **Feed Seguindo com consultas por projeto.** A serialização carregava cada
   carro individualmente. O relacionamento agora é carregado junto da consulta
   das evoluções. No teste com cinco projetos distintos, as consultas SELECT
   caíram de 8 para 3, incluindo autenticação e fotos. A comparação entre páginas
   de um e cinco itens confirma que a contagem não cresce por projeto.
2. **Cursor inválido causava exceção interna.** IDs numéricos, listas, objetos e
   booleanos chegavam ao construtor UUID e lançavam AttributeError. Validação de
   tipo em sete decodificadores conserva o tratamento de cursor inválido.
   Testes cobrem os tipos malformados e a resposta HTTP 400 do feed.
3. **Rascunhos apagados ao fechar a tela.** Conversas direta e da equipe salvavam
   texto vazio ao sair antes de terminar a leitura local. Comentários também
   apagavam o rascunho após falha temporária de leitura. Agora a saída só salva
   quando o editor sofreu alteração. Seis testes cobrem três telas com leitura
   pendente ou falha. Os testes existentes de restauração, envio e limpeza
   continuam aprovados.
4. **Uploads bloqueavam a thread assíncrona da API.** Cinco rotas async faziam
   SQL síncrono e conversão de imagem nessa thread. As rotas agora são síncronas,
   executadas no pool de threads do framework, com leitura limitada do arquivo.
   Um teste por tipo de upload verifica que a conversão ocorre fora do event loop
   e que a resposta continua correta.

## Verificações locais

- Flutter analyze --no-pub --fatal-infos: sem problemas.
- Suíte Flutter: 161 testes aprovados.
- Suíte backend: 105 testes aprovados; depois, os 35 testes direcionados passaram
  com cinco casos adicionais (quatro uploads e resposta HTTP de cursor inválido).
- git diff --check: sem problemas.
- Backend usa SQLite isolado nos testes; dados locais do usuário não são usados.
- CI da PR executa também migrations no PostgreSQL/PostGIS e build do APK.

O aviso existente de depreciação Starlette/httpx permanece; não houve atualização
de dependências. A medição do feed conta consultas, não simula carga de produção.
Concorrência de uploads entre múltiplos processos não foi ensaiada neste ciclo.

## Validação manual sugerida

1. Conversa direta e equipe: escrever, sair/reabrir, confirmar o rascunho e enviar.
2. Evolução: repetir com comentário e resposta; conferir a limpeza após publicar.
3. Seguindo: abrir e carregar a próxima página, verificando projetos e fotos.
4. Enviar foto de perfil, projeto e evolução; conferir também imagem da equipe
   e capa de encontro quando disponíveis.

Para atualizar a API local, com Docker Desktop aberto, na raiz do projeto:

```powershell
docker compose up -d --build
```

Para abrir o app, no diretório `mobile`:

```powershell
flutter run -d emulator-5554 --no-pub --no-dds
```

Mantidos identidade visual, leitura automática das notificações, identificadores
do app e documentos locais de pesquisa de nomes. Merge depende da validação
desta rodada.
