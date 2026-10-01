# Garona — revisão antes da validação manual

Data: 01/10/2026. Branch: `feat/next-product-cycle`.
PR: https://github.com/raullferreiraa/garagem-digital/pull/196

## Escopo

Revisão das mudanças acumuladas da identidade e dos componentes compartilhados,
com conferência dos fluxos de sessão, projetos, descoberta, perfis, equipes,
encontros, conversas, evoluções, notificações e compartilhamento. Renomeações
de imports foram separadas das mudanças de comportamento. Também foram
conferidos assets, configuração Android, testes, grafo de migrations e CI.

## Correções

1. **Rascunhos apagados ao limpar tokens:** `deleteAll()` removia também os
   rascunhos no armazenamento seguro. A limpeza agora remove apenas access e
   refresh tokens; os rascunhos continuam separados por conta e conversa.
2. **Abertura travada quando o armazenamento seguro falha:** a consulta inicial
   da sessão estava fora do tratamento de erro, e a limpeza de sessão expirada
   também podia propagar falha. Ambos os casos agora chegam à tela de recuperação
   com opção de tentar novamente.
3. **Atalhos da equipe sem ação para leitor de tela:** os nós semânticos indicavam
   botão, mas não expunham toque. A ação foi adicionada e o teste abre o destino
   por ação semântica.
4. **Cartão de projeto ultrapassando a largura:** contadores grandes com fonte
   ampliada estouravam a linha. O rodapé agora quebra em linhas e mantém os
   números completos e a abertura do projeto.

Os testes de regressão reproduziram essas falhas antes das correções e passaram
depois. A falha de leitura do token no interceptor já encerrava corretamente a
requisição; esse comportamento foi verificado sem alterar o interceptor.

## Limpeza

- Removidos cinco ícones PNG padrão do Flutter; mantidos os vetores Garona e o
  ícone adaptativo Android.
- Removida animação de escala que mantinha sempre o valor 1.
- Removido botão duplicado de editar perfil; permanece a ação do cabeçalho.
- Imagem gerada anteriormente continua fora do código, manifesto e APK.
- Sem harness temporário em `tool/`. Logs, scripts auxiliares e prévias desta
  revisão ficam em `mobile/build/`, ignorado pelo Git.
- Pesquisas históricas de nomes e mudanças existentes foram preservadas.

## Verificações

| Verificação | Resultado |
| --- | --- |
| Flutter analyze com `--fatal-infos` | Sem problemas |
| Suíte completa Flutter | 155 testes aprovados |
| Suíte completa backend | 75 testes aprovados em SQLite isolado |
| Sintaxe Python de app e migrations | 87 arquivos válidos |
| Grafo Alembic | Um único head: `20260929_0025` |
| APK Android debug | Compilado |
| Conteúdo do APK | Sem imagem gerada e sem ícones PNG antigos |
| Diff check | Sem erros de whitespace |

A cobertura automatizada inclui autenticação/renovação, falhas de rede,
paginação/filtros, proprietário e placa privada, comentários/editado, rascunhos,
bloqueios/denúncias, convites/cargos/equipes, encontros/participantes,
notificações e compartilhamento. Layouts incluem 320 px com fonte ampliada,
teclado e área de navegação Android de 0/24/48 px. Notificações continuam
marcadas como lidas ao visualizar, conforme escolha do usuário.

O backend emitiu um aviso de depreciação da integração Starlette/httpx de testes;
nenhum teste falhou. Dependências não foram atualizadas nesta revisão.

## Limites e preparação do merge

- Docker estava parado: migrations não foram aplicadas a PostgreSQL local
  nesta execução. Os testes da API usam banco isolado, sem apagar dados do usuário.
- A validação visual e de uso no emulador ainda depende da próxima rodada.
- Na consulta feita durante a revisão, a PR #196 estava em rascunho e sem
  conflito informado pelo GitHub. Seu head remoto `3fe9f7f` tinha CI aprovado,
  mas estava sete commits atrás do HEAD local `f03444e`, além destas alterações
  ainda não commitadas. Esse CI não certifica o estado atual.
- Após a validação manual: commit das mudanças revisadas, publicação da branch,
  checks da versão atual e então merge autorizado. Esta revisão não fez
  commit, push ou merge.

## Roteiro manual

1. Login, perfil/edição e navegação inferior.
2. Descobrir/busca/salvos → próprio projeto → editar. Projeto alheio sem opções
   de proprietário e sem placa privada.
3. Diário → foto inteira → comentário/resposta → editar → voltar e reabrir.
4. Mensagem pendente → fechar/reabrir o app; repetir na conversa da equipe.
5. Encontros, filtros e confirmação; equipe, convites e conversa.
6. Atividade: visualizar continua limpando o indicador de não lidas.

```powershell
cd C:\Users\rauls\Documentos\projetos\garagem-digital\garagem-digital\mobile
flutter run -d emulator-5554 --no-pub --no-dds
```

Se API/banco estiverem parados, execute `docker compose up -d` na raiz do projeto
antes de iniciar o app, com o Docker Desktop em execução.
