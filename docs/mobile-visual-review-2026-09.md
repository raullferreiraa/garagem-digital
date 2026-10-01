# Revisão visual do aplicativo — setembro de 2026

## Direção

Identidade automotiva baseada em grafite frio, superfícies de painel, tipografia
Barlow Condensed para títulos e Manrope para leitura. Laranja identifica ações,
seleções e informações em destaque. Traços de instrumentos aparecem discretamente
nos painéis de identidade, introduções e imagens ausentes.

## Áreas revisadas

| Área | Refinamento aplicado |
| --- | --- |
| Tema e navegação | Paleta de superfícies, bordas mais discretas, títulos proporcionais, ícones, botões, campos, listas, diálogos e barra inferior |
| Login e cadastro | Painel de marca com traçado de pista e hierarquia compartilhada |
| Explorar e garagens | Cartão de projeto compartilhado, nome legível abaixo da foto, ano separado, estado do projeto, ficha resumida e ação de abertura |
| Projeto | História em painel e ficha técnica com rótulos e valores hierarquizados |
| Evoluções | Tema aplicado ao carrossel, galeria, comentários e formulário; fotos completas também na aba Seguindo |
| Perfis | Painéis de identidade e indicadores sociais, avatar consistente, coleção com o mesmo cartão de projeto |
| Perfil público | Ações Seguir/Mensagem em coluna quando a largura ou fonte exige mais espaço |
| Equipes | Painel de identidade, indicadores, selos de papel/visibilidade, introdução e avatares de convites |
| Encontros | Introdução, capa e selo de calendário para a próxima edição |
| Conversas | Superfície compartilhada para composição de mensagens/comentários, bolhas delimitadas e movimento reduzido |
| Busca, carregamento e falhas | Estados vazios compartilhados, apresentação de imagem ausente e mensagens de falha com ação separada |
| Formulários | Introduções compartilhadas, campos e foco consistentes, largura de conteúdo limitada a 640 px e rolagem para validação |
| Telas auxiliares | Segurança, salvos, conexões, bloqueados, participantes, histórico e seletores recebem os componentes e o tema global |

## Componentes

- `AppTheme`: cores, tipografia e componentes Material.
- `GdPanel`, `GdIntro`, `GdEyebrow`: superfícies e títulos de seção.
- `GdBadge`: metadados; sobre fotografias usa fundo escuro quase opaco.
- `GdEmptyState`: mensagem, explicação e ação de recuperação.
- `GdComposerSurface`: acabamento de chats e comentários.
- `GdActionPair`: ações adaptadas à largura e à escala de texto.
- `GdProjectCard`: apresentação de projetos em Explorar e nos perfis.

Os desenhos técnicos são estáticos, não participam da leitura por acessibilidade
e ficam limitados à área de pintura. A interface usa as fontes locais do projeto.

## Verificação

`flutter analyze --no-pub` sem problemas; suíte completa com 147 testes aprovados.

Os testes de layout cobrem 390 px com escala normal e 320 px com fonte ampliada
em 40%, incluindo abas com conteúdo, perfil público, seis formulários, teclado
aberto, abertura e retorno de projetos e privacidade da placa. A suíte inclui
os fluxos de filtros, paginação, edição, rascunhos, conversas e gestão de equipes.

As prévias são produzidas em `mobile/build/premium-after` usando
`GD_PREVIEW_DIR` nos testes. Esses arquivos são artefatos locais de revisão.

## Validação no emulador

1. Explorar: comparar projetos com foto e sem foto; abrir e voltar; usar Em alta.
2. Perfis: conferir identidade e coleção; abrir outro perfil e usar suas ações.
3. Projeto: conferir história, ficha técnica, carrossel e galeria completa.
4. Equipes e encontros: verificar indicadores, papéis e data da próxima edição.
5. Conversas: digitar com o teclado aberto, responder e conferir rascunho.
6. Formulários: conferir criação/edição, foto, seletor de cidade e campo inválido.
7. Android com fonte maior: conferir leitura e acesso às ações nas mesmas telas.

## Encerramento

Validação visual confirmada pelo usuário em 29/09/2026, com aprovação do
acabamento mais premium. Ciclo concluído com a identidade visual compartilhada
e a revisão de apresentação de projetos, perfis, equipes, encontros e formulários.
APK de depuração compilado com sucesso. O nome oficial permanece em discussão.
