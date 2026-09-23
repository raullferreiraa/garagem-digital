# Chats — refinamentos de usabilidade

Ciclo posterior ao commit 3c68b56, validado manualmente pelo usuário.
Validação automatizada: 70 testes Flutter passaram e análise estática sem problemas.

- Conversas diretas e da equipe permitem selecionar/copiar texto das mensagens.
- Envio fica desativado para texto vazio ou composto apenas de espaços.
- Contador aparece a partir de 1.800 caracteres, mantendo o limite de 2.000.
- Campo e envio aguardam o histórico inicial: uma resposta atrasada não deve
  sobrescrever uma mensagem enviada enquanto a conversa ainda estava carregando.
- Testes dos dois chats cobrem carga inicial pendente e falha de envio,
  verificando preservação do texto e liberação do botão para nova tentativa.

## Validação manual

1. Nos dois chats, abrir em rede lenta e aguardar o histórico antes de digitar.
2. Conferir botão desativado com campo vazio/espaços e ativado ao escrever.
3. Enviar texto normal; selecionar/copiar uma mensagem existente.
4. Colar texto longo e conferir contador próximo ao limite.
5. Parar somente o container da API depois de abrir a conversa e tentar enviar: após o erro,
   texto deve continuar no campo, sem carregamento infinito.
6. Iniciar novamente a API e tentar enviar; conferir mensagem e histórico.

No emulador, desligar a internet não necessariamente interrompe o acesso à API
local. O usuário confirmou falha com a API parada e envio bem-sucedido após reiniciá-la.

Não há reenvio automático nem rascunho persistente ao sair da tela neste ciclo.
