# Revisão de manutenção — 22/09/2026

## Escopo e limites

Revisão transversal do projeto ativo: arquitetura Flutter/API/banco, fluxos de
autenticação, cadastro de carros, perfil/garagem, Explorar e busca, diário,
equipes e permissões, conversas, notificações, compartilhamento, armazenamento
de imagens, migrations, Docker e workflows de CI. Foram inspecionados pontos de
entrada, serviços, schemas e mecanismos de atualização dos fluxos principais,
além da suíte automatizada. Não equivale a auditoria exaustiva de cada linha,
pentest, teste de carga ou homologação em aparelhos reais.
`legacy/web/` não foi alterado.

## Encontros: mudança de produto

A comunidade passa a existir independentemente de uma data. É possível criá-la
sem edição, editar nome/apresentação/cidade, carregar capa e seguir a comunidade.
A página reúne identidade visual, organização, seguidores, próxima edição,
outras datas futuras e histórico. A listagem permite buscar nome/cidade e filtrar
Todos, Seguindo e Organizo.

O organizador pode agendar novas edições pela interface. Confirmações de pessoas
e equipes pertencem a uma edição; seguidores pertencem à comunidade. A próxima
edição é selecionada por início crescente e ID como desempate. Depois do início,
ela entra no histórico e a comunidade permanece acessível. A tela apresenta as
50 edições mais recentes; paginação desse histórico continua pendente.

A comunidade possui uma região-base. Cada edição pode reutilizá-la ou informar
outra cidade/estado e endereço, permitindo encontros itinerantes. Edições futuras
podem ser editadas ou canceladas; cancelamentos ficam identificados no histórico,
não recebem novas confirmações e a próxima data válida assume automaticamente.

O app envia o ID da edição vista ao confirmar/cancelar presença. Se a próxima
edição mudou, a API recusa a operação em vez de aplicá-la silenciosamente a outra
data. O usuário deve atualizar a página e confirmar de novo.

## Problemas corrigidos

- Comunidades sumiam quando não existia data futura; listagem e detalhe agora
  permanecem disponíveis, inclusive seguir/deixar de seguir.
- Nome composto só de espaços podia passar pela validação anterior. Normalização
  ocorre antes da validação de tamanho.
- Datas com e sem fuso podiam provocar comparação inválida. A entrada é
  normalizada para UTC.
- O criador de um encontro de equipe mantinha gestão independentemente de seu
  cargo. A autorização acompanha a equipe e os cargos atuais; sem a equipe
  organizadora, permanece o responsável individual.
- Renovação de token apagava a sessão em falhas transitórias. Erros de rede/5xx
  preservam tokens; a inicialização oferece nova tentativa.
- Paginação do histórico do chat da equipe marcava mensagens novas como lidas.
  Apenas a consulta da página atual atualiza a leitura; cursor inválido não altera
  o estado.
- Leitura automática da central de avisos marcava todas as notificações do servidor,
  inclusive as não carregadas. Agora reconhece apenas os IDs carregados e consulta
  novamente o total de não lidas.
- Respostas atrasadas da garagem podiam sobrescrever dados mais recentes. O perfil
  usa geração de requisição e conserva o projeto recém-criado durante reconciliação.
- A regra de equipe única tinha trigger sem exclusão mútua entre transações.
  A migration 0016 adiciona UNIQUE(usuario_id); a entrada na equipe também bloqueia
  a linha do usuário durante a verificação no PostgreSQL.

## Banco

Migrations novas: 0015 (capa), 0016 (equipe única sob concorrência) e 0017
(status das edições para cancelamento sem perda de histórico).
Não foi necessário limpar usuários, equipes, carros ou encontros.
A restrição única interrompe a migration se houver duplicidades preexistentes;
não escolhe arbitrariamente qual vínculo excluir.

A suíte de rotas usa SQLite; aplicar migrations no PostgreSQL local verifica
outro aspecto, mas não substitui um teste de concorrência com múltiplas sessões.
As migrations até 0017 foram aplicadas no ambiente local.

## Pontos preservados e observados

- Placas públicas usam o campo calculado placa_publica; schemas públicos e privados
  continuam separados. Compartilhamento atual não inclui placa ou e-mail.
- Busca mobile e listas principais possuem controle de respostas atrasadas;
  a lista de encontros também passa a manter conteúdo durante refresh/erro.
- Rotas de chat verificam participação; upload valida conteúdo, limite de bytes,
  resolução e reprocessa a imagem.
- Migrations antigas foram preservadas; nenhuma dependência foi atualizada em massa.
- Manifesto Android libera HTTP em debug. Release precisa de API HTTPS.
- Não foram encontrados arquivos .env, .key ou .pem versionados na checagem por
  extensão; isso não substitui varredura histórica de segredos.

## Pendências antes de ampliar o público

1. Mídias são servidas em /media por StaticFiles, sem autorização individual.
   URLs não devem ser tratadas como proteção para conteúdo privado.
   Mídia realmente privada precisa de entrega autenticada ou URLs temporárias.
2. Proteção contra abuso: limites de tentativas de autenticação, envio de mensagens
   e uploads; bloqueio/denúncia e moderação precisam de um ciclo próprio.
3. Troca de senha revoga refresh tokens, mas access tokens já emitidos continuam
   válidos até expirar. Revogação imediata exige versionamento/validação de sessão.
4. Escala: algumas listas são limitadas ou não paginadas (busca, conversas,
   seguidores e encontros). Há consultas adicionais por comunidade/edição.
   Buscar com relevância e cursor temporal merece cobertura específica antes de
   acrescentar paginação na busca mobile.
5. Compartilhamento envia texto, ainda sem links universais para abrir o destino.
6. Conversas atualizam por consultas periódicas; não há entrega push/WebSocket.
7. Alterações e cancelamentos de edições ainda não disparam avisos específicos
   para seguidores e pessoas confirmadas; esse encaixe pertence ao próximo ciclo
   de notificações.
8. Não houve validação de carga, rede móvel real, acessibilidade com leitor de tela
   ou imagens em aparelhos físicos. Essas validações permanecem manuais.

## Validação

Resultado local: 50 testes backend e 40 testes Flutter passaram; análise Flutter
sem problemas; APK debug compilado; migrations até 0017 e health check OK.
Foram adicionadas regressões para comunidade sem data, histórico,
permissões, datas inválidas, capa, troca/cancelamento de edição, locais itinerantes
e sessão sob falha transitória;
os testes de notificações e ciclo de vida foram ajustados para os novos contratos.

As alterações seguem locais na branch da PR. Commit/push aguardam validação manual.
