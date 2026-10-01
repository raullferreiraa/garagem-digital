# Garona · identidade do aplicativo

## Direção

Nome oficial: **Garona**. Esta entrega estabelece a identidade da interface;
slogan, posicionamento e desenvolvimento definitivo da marca ficam para uma
próxima etapa, conforme solicitado. O monograma G é uma proposta aplicada ao
produto, que poderá evoluir junto com essa etapa.

## Direção vigente: garagem noturna

A direção clara foi rejeitada pelo usuário. Garona deve ser escuro, underground,
premium e ligado a encontros de antigos, ao Omega e a projetos modificados.
A barra de navegação independente foi aprovada e permanece.

- Preto esverdeado `#090E0C`, superfícies `#101813` / `#18251D`, texto
  marfim `#F1F1E7`. O cinza e o coral da rodada anterior foram substituídos.
- Amarelo-lima fosco `#D6EA78` nas ações e seleção; âmbar `#D3AA77` em
  datas, anos e informações secundárias. O brilho é reservado aos destaques.
- Descoberta com capa de projeto: fotografia, ano e identificação sobrepostos,
  com gradiente para leitura. O primeiro resultado da ordenação recebe a capa;
  os demais são entradas compactas, sem alegação de curadoria editorial.
- Perfil aberto com avatar à esquerda junto ao nome, estatísticas compactas
  e garagem. Espaços vazios e ações duplicadas reduzidos.
- Coleção com miniatura lateral; adaptação vertical em telas estreitas/fonte alta.
- Ficha técnica em painel único, com divisórias e adaptação para telas estreitas
  e fonte ampliada. Proprietário e história apresentados sem caixas extras.
- Entrada tipográfica, sem fotografia ou ilustração. Interface e controles
  usam Manrope; títulos de capa e entrada usam Barlow Condensed.
- Carrossel do diário e fotos completas preservados.

A validação visual usa dados de teste e imagens de substituição quando não há
foto. Não representa fotografia real dos carros do usuário.

## Refinamento underground e formas arredondadas

O usuário rejeitou os cantos duros e pediu mais personalidade. A revisão amplia
as formas curvas e a linguagem da garagem noturna ao restante do aplicativo:

- Cantos suaves, sem arredondar tudo como pílulas: controles e informações com
  raios de 12–16 px; abas Descobrir/Seguindo e Recentes/Em alta com raio 14.
  Cartões maiores usam 20–24 px. Fundos escuros com nuances verdes;
  navegação independente com raio 24 e seleção citron.
- A área reservada aos gestos/botões do Android fica fora do fundo da barra;
  itens centralizados, altura compacta e alvos de toque de pelo menos 48 px.
- Assinatura de três segmentos arredondados inspirada em lanternas; wordmark
  inclinado. As fontes continuam locais e as decorações não recebem foco.
- Imagem gerada da entrada removida do código, do manifesto de assets e do
  repositório a pedido do usuário. O login usa marca, tipografia e formulário.
- Cards de projeto e miniaturas arredondados; especificações em linha na capa.
- Diário arredondado, informações de data/categoria/km em etiquetas no detalhe,
  comentários organizados por conversa e composição de mensagens com topo curvo.
- Encontros tratados como convites, com data/local legíveis. Equipes com capa,
  emblema, estatísticas e vitrine dos carros.
- Conversas, balões e avisos com superfícies arredondadas e sinalização de não
  lidas. Leitura de notificações ao visualizar permanece como escolha do usuário.
- Busca e formulários acompanham filtros, campos e botões arredondados.

Não há imagem gerada por IA incorporada ao app. Fotos são conteúdo dos usuários;
o desenho vetorial sinaliza capas de projeto sem foto. Monograma, slogan e estratégia de marca seguem passíveis
de refinamento posterior, conforme o escopo original.

## Entrega

- Nome Garona no aplicativo, Android, compartilhamentos, documentação corrente
  e título padrão da API.
- Pacote Dart `garona_mobile`, classe raiz `GaronaApp`, componentes `Garona*`
  e arquivos do sistema visual renomeados.
- Monograma vetorial, assinatura GARONA, ícone adaptativo Android com suporte
  monocromático e abertura preta com marca (incluindo Android 12+).
- Entrada com assinatura GARONA e título condensado;
  cadastro com apresentação compacta. O desenho técnico de carroceria serve
  como imagem ausente de projeto e mantém a proporção em miniaturas.
- Explorar com assinatura da marca; capa de projeto e entradas compactas,
  proprietário, ano, estado, história e ação de abertura.
- Abas de descoberta com cantos moderados e seleção tonal, perfis com identificação
  GARONA / GARAGEM e fundos com linhas discretas de carroceria. Cartões do diário
  recebem superfícies verdes escuras e borda uniforme, mantendo a navegação horizontal validada.
- Tema global revisado: superfícies, títulos, campos, botões, filtros tonais,
  navegação, diálogos, menus, carregamento e estados vazios.
- Apresentações de equipes, encontros e formulários com menos caixas e uma
  hierarquia editorial. Ações rápidas de equipe mais compactas e discretas.
- Perfil, projeto, conversas e evoluções recebem o sistema visual compartilhado.
  Carrossel horizontal, fotos completas, rascunhos, privacidade da placa,
  reconhecimento de proprietário e leitura automática de notificações mantidos.

## Compatibilidade

O identificador Android `br.com.garagem.garagem_mobile` e canais nativos existentes
são mantidos deliberadamente: a instalação deve atualizar o aplicativo existente
e preservar dados locais/sessão. Não são textos exibidos ao usuário. Chaves de
armazenamento, nomes de banco/volumes, rotas e diretório do checkout também
permanecem compatíveis. Não houve acesso ao conteúdo do `.env`.

Arquivos históricos em `docs/` e `legacy/`, URLs reais do repositório e pesquisas
de nomes anteriores preservam o contexto original. Apenas Android está
configurado no repositório; não se afirma validação em iOS.

## Verificação

Suíte completa: 149 testes aprovados após a revisão de cores e navegação.

Testes de layout incluem 390 px, 320 px com fonte em 140%, teclado, ações e
navegação de retorno. Regressão da barra testada com insets Android de 0, 24 e
48 px: o espaço do sistema não aumenta o fundo da barra e os cinco destinos
continuam acessíveis e centralizados.
Expectativas visuais antigas foram atualizadas; o teste dos filtros agora
verifica contraste mínimo de 4,5:1 da seleção.

Prévias renderizadas pelo Flutter em `mobile/build/garona-preview/` e
inspecionadas visualmente. APK Android debug compilado. Análise estática limpa.
Validação manual no emulador pelo usuário ainda pendente.

## Validar no emulador

1. Encerrar o Flutter anterior com `q` e executar novamente; hot reload não
   atualiza o nome e o ícone nativos.
2. Conferir ícone e nome Garona na lista de apps e a abertura do aplicativo.
3. Conferir Explorar, busca e filtros, projetos com e sem foto e retorno da tela.
4. Abrir o próprio projeto por Explorar e confirmar as ações de edição.
5. Conferir perfil, equipe e encontros, com filtros e ações acessíveis.
6. Abrir evoluções, deslizar o carrossel e ampliar uma foto vertical/horizontal.
7. Conferir conversa, comentário editado, teclado e restauração do rascunho.
8. Conferir login/cadastro e formulário de projeto com a fonte Android maior.

```powershell
cd C:\Users\rauls\Documentos\projetos\garagem-digital\garagem-digital\mobile
flutter run -d emulator-5554 --no-pub --no-dds
```

API/banco já existentes podem continuar em execução. Se estiverem parados,
na raiz do repositório: `docker compose up -d`.
