# Manutenção de estabilidade e acabamento — 23/09/2026

Branch: `maintenance/stability-polish`, criada de `origin/main` após a PR #194.

## Revisão e correções

Revisão transversal dos fluxos ativos: autenticação e armazenamento de sessão,
schemas públicos/privados, upload, projetos e diário, interações, equipes,
conversas, encontros, componentes visuais, testes, migrations e Docker.
Não é auditoria exaustiva de cada linha, pentest ou teste de carga.

- Trocar senha invalida access tokens anteriores imediatamente. A migration
  0018 adiciona a versão da autenticação; tokens antigos continuam compatíveis
  com a versão inicial. Login, troca de senha e refresh coordenam bloqueios do
  usuário; a resposta é montada antes de liberar a transação.
- Logout encerra a sessão local mesmo quando a chamada HTTP falha.
- Refresh atrasado não sobrescreve nem apaga tokens de uma sessão diferente.
- Retry de upload após refresh clona o formulário multipart consumido.
- Transferir liderança, alterar cargo, remover membro e encerrar equipe usam
  bloqueio da equipe para serializar essas operações concorrentes.
- Confirmação/retirada de presença individual e da equipe usam o mesmo bloqueio
  da comunidade empregado ao editar/cancelar suas edições.
- Chats não iniciam polling quando outra rota os cobre ou o app está em segundo
  plano, nem sobrepõem consultas periódicas. Chamadas já em curso podem concluir.
- Testes passam a usar mídia temporária e uma instância de API por teste.
  `backend/media/` fica fora do Git; os arquivos existentes foram preservados.

## Acabamento visual

Identidade, cores e organização preservadas. Ajustes compartilhados em diálogos,
menus, dicas, seleção de texto, campos com erro multilinha, alça dos painéis e
margens dos avisos. Horários das mensagens ficaram maiores e mais legíveis.
A navegação anuncia contadores para acessibilidade. O teste de layout agora
percorre as cinco abas atuais em 390 px e 320 px com fonte ampliada.

## Limitações e próximos cuidados

- As rotas de mídia continuam estáticas/públicas. Privacidade de equipe não é
  garantia de sigilo de uma URL de imagem; entrega autenticada exige mudança
  coordenada entre API, cache e carregamento mobile.
- Rate limiting, moderação e bloqueio/denúncia ainda precisam ser implementados
  antes de ampliar o público.
- Listas sem paginação e consultas adicionais por encontro permanecem riscos
  de escala, não foram reestruturadas nesta pequena manutenção.
- A suíte backend usa SQLite; aplicação da migration no PostgreSQL não substitui
  testes concorrentes com múltiplas conexões.
- Conferência visual em aparelho e rede móvel real permanece manual.

## Validação manual

Automatizado: 50 testes backend e 46 Flutter passaram; `flutter analyze
--fatal-infos` sem problemas; APK debug compilado. Migration 0018 aplicada no
PostgreSQL local. Backend emitiu apenas dois avisos de depreciação das bibliotecas
de teste. `git diff --check` sem erros.

1. Login incorreto, login correto, troca de senha e novo login (senha antiga deve
   falhar). Se possível, confirmar expiração imediata em uma segunda sessão.
2. Sair com API inacessível: voltar à tela de login; reconectar e entrar novamente.
3. Upload de avatar/foto, criação de projeto e atualização da garagem no Perfil.
4. Chat direto e da equipe: enviar, receber, sair da tela, voltar do segundo plano
   e conferir histórico e badges.
5. Transferência de liderança e permissões do antigo dono; confirmação/cancelamento
   de edição e presença no encontro.
6. Percorrer cinco abas, menus, painéis e formulários, incluindo fonte ampliada.

Alterações locais aguardam validação Android antes de commit/push.
