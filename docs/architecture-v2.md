# Arquitetura v2

## Objetivo

Transformar o projeto em um produto mobile sem carregar as limitacoes do frontend
web atual. O sistema legado permanece como referencia de regras e comportamento.

## Componentes

```text
Flutter -> API FastAPI -> PostgreSQL/PostGIS
                    \-> armazenamento de midia
```

O aplicativo nunca acessa o banco diretamente. Identidade, autorizacao, propriedade
de carros e permissoes de equipe sao verificadas pela API.

## Regras confirmadas

1. Um carro e um perfil permanente, nao uma publicacao descartavel.
2. Evolucoes formam o diario e alimentam o feed social.
3. Entrar em uma equipe nao adiciona carros automaticamente a garagem coletiva.
4. O proprietario escolhe quais carros quer associar a cada equipe.
5. O vocabulario tecnico e visual usa `equipe`, nunca `clube`.
6. Localizacao e opcional e serve para eventos e comunidades, nao rastreamento.

## Limites da primeira fundacao

- Autenticacao usa access token JWT curto e refresh token opaco, rotativo e
  revogavel. Apenas o hash do refresh token e armazenado no banco.
- Rotas protegidas obtem a identidade pelo token; nao aceitam `usuario_id` como
  prova de identidade.
- O provedor de armazenamento de imagens sera decidido antes do primeiro upload.
- O frontend Flutter sera criado depois que os contratos iniciais da API estiverem
  autenticados e testados.
- Participacao em uma ou varias equipes permanece flexivel no banco. A regra final
  pode ser aplicada na API sem nova migracao estrutural.
