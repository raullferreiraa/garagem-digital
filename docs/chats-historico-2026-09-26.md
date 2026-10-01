# Conversas: busca e leitura da mensagem original

## Entrega

- Lupa no cabeçalho da DM e do chat da equipe: busca no histórico do servidor, com no mínimo dois caracteres e no máximo 100.
- Resultados do mais recente para o mais antigo, com autor, prévia, data/hora e paginação. O filtro não se limita às mensagens carregadas na conversa.
- Toque no resultado ou na citação de uma resposta: volta direto ao ponto correspondente da conversa, carregando páginas antigas quando necessário e destacando brevemente a mensagem.
- Mensagens apagadas não aparecem na busca. A consulta individual exibe apenas o estado apagado, sem ações de copiar/responder.
- Busca e consulta individual respeitam acesso à conversa, bloqueios em DM e vínculo com a equipe. Buscar no chat da equipe não altera a leitura de todo o histórico.
- Respostas atrasadas de consultas anteriores são descartadas ao mudar ou limpar a busca. Falhas permitem tentar novamente.

## API

O parâmetro opcional `busca` foi adicionado a `GET /conversas/{id}/mensagens` e `GET /equipes/{id}/chat`. Mantém-se a paginação por cursor; `%` e `_` são tratados como texto literal.

Consulta individual: `GET /conversas/{id}/mensagens/{mensagem_id}` e `GET /equipes/{id}/chat/{mensagem_id}`. Não marca a conversa como lida.

Este ciclo não adiciona migrações. Permanecem necessárias as migrações de edição/exclusão e respostas do ciclo anterior.

## Validação manual com um emulador

1. Recriar/iniciar a API com `docker compose up --build` na raiz do repositório. Reiniciar o Flutter com `flutter run` na pasta `mobile`.
2. Abrir uma DM, tocar na lupa e buscar uma palavra de uma mensagem antiga conhecida. Conferir autor e data e tocar no resultado: deve voltar ao chat, rolar até a mensagem e destacá-la.
3. Tocar diretamente na citação de uma resposta: deve rolar até a mensagem original e destacá-la, sem abrir um painel intermediário.
4. Responder a uma mensagem própria, apagar a original e tocar na citação. Deve localizar a bolha “Mensagem apagada”. O texto apagado não deve voltar nos resultados de uma nova busca.
5. Buscar algo inexistente e depois limpar o campo. Não deve manter resultados antigos nem ficar carregando indefinidamente.
6. Repetir os mesmos passos no chat da equipe. Paginação aparece quando há mais de 30 resultados; não é necessário produzir esse volume manualmente, pois a paginação está coberta pelos testes automatizados.

## Cobertura automatizada

- Backend: busca/paginação, escape de caracteres, edição/exclusão, acesso sem autenticação, referência de outra conversa, bloqueio em DM e remoção de integrante.
- Flutter: descarte de respostas atrasadas, limpeza de busca, paginação sem duplicação, retry e navegação direta até mensagens antigas nas duas telas de chat.
