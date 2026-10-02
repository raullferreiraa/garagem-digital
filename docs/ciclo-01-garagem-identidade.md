# Ciclo 1 — Garagem com identidade

## Entregas

- Nome e proposta opcionais do projeto; origem, data de aquisição, configuração original e modificações. Prévia antes de salvar e confirmação ao descartar alterações.
- Apresentação compacta: história e ficha expansíveis, nome nos cards, busca e compartilhamento. Projetos antigos continuam usando modelo como título.
- Galeria própria com até 12 fotos, legenda, ordenação, ampliação e escolha de capa. Capa e foto da galeria são arquivos independentes.
- Até 60 etapas por projeto, agrupadas em planejadas, em andamento e concluídas. Conclusão pode ser vinculada a uma evolução do mesmo carro; excluir etapa não exclui a evolução.
- Visitantes consultam; somente o proprietário altera. Campos privados continuam protegidos. Evoluções permanecem no carrossel.

## Banco e compatibilidade

Migration `20261002_0026`: seis campos opcionais em carros, fotos_projeto e etapas_projeto. Não exige preenchimento nos projetos existentes. Subir a API atualizada antes do app; a imagem Docker executa Alembic na inicialização. Nenhuma alteração no SDK/Gradle foi necessária.

## Verificação local

- Backend: 114 testes aprovados.
- Flutter: 166 testes aprovados; testes direcionados novamente aprovados após ajuste de vínculo removido.
- flutter analyze --no-pub --fatal-infos: sem problemas.
- flutter build apk --debug --no-pub: APK gerado.
- Telas de projeto, galeria e etapas renderizadas em teste de widget para revisão visual.
- Validação manual no emulador e migração PostgreSQL em CI complementam os testes locais.

## Roteiro de validação manual

Na raiz do repositório:

```powershell
docker compose up -d --build
docker compose ps
```

No diretório mobile:

```powershell
flutter run -d emulator-5554
```

1. Abrir projeto antigo; conferir ficha, histórico e carrossel. Editar nome, proposta, origem e modificações; abrir prévia, salvar e reabrir. Buscar pelo nome novo.
2. Alterar um campo e voltar: continuar editando deve manter o conteúdo; descartar deve sair sem salvar.
3. Em Galeria e etapas, adicionar fotos horizontal e vertical; legendar, reorganizar e ampliar. Escolher capa, excluir sua foto da galeria e confirmar que a capa continua disponível ao voltar ao projeto.
4. Criar etapas nos três estados. Concluir uma vinculando uma evolução; abrir a evolução. Reabrir etapa, editar e excluir; o diário deve permanecer intacto.
5. Abrir o projeto com outra conta: conferir apresentação e galeria, sem controles de edição nem placa privada. Reabrir com o dono pelo Descobrir e conferir os controles.

Após aprovação manual e CI verde, concluir a PR e fazer merge. Os documentos anteriores de pesquisa de nome não fazem parte deste ciclo.

## Refinamento após validação do proprietário

- Capas do Descobrir, projeto e cards do perfil em 16:10, sem novo corte automático. Informações no Descobrir ficam abaixo da imagem. Busca, salvos e equipes preservam toda a imagem nas miniaturas.
- Selecionar capa pela galeria abre o editor e mantém a foto completa na galeria. Fotos antigas de outra proporção podem ter margens para preservar conteúdo; reenquadrar uma nova capa em 16:10 elimina essas margens. Conteúdo já cortado no arquivo antigo só pode ser recuperado reenviando o original.
- Campos narrativos com 3 a 7 linhas, parágrafos, exemplos e instruções; opcionalidade explícita. Proposta explica objetivo/estilo, história explica trajetória, estado inicial descreve a aquisição.
- Prévia inclui capa existente; seções vazias não aparecem no projeto; alteração da visibilidade da placa também aciona proteção ao sair.
- Teste de exclusão de evolução verifica SET NULL e preservação da etapa; teste de reabertura verifica remoção do vínculo no envio. A evolução publicada no formulário existe independentemente de salvar a etapa, conforme texto explicativo.

### Revalidar

1. Conferir a mesma capa em Descobrir, perfil, busca, salvos, equipe e projeto; usar uma foto de carro horizontal e uma vertical na galeria.
2. Definir capa pela galeria, cancelar o recorte (não deve mudar) e repetir confirmando. Conferir que o original da galeria permaneceu completo.
3. Preencher campos opcionais com parágrafos e conferir prévia/detalhes. Deixar campos vazios não deve criar seções vazias.
4. Concluir etapa com evolução existente, abrir o vínculo, reabrir a etapa e conferir que a evolução continua no diário. Excluir uma evolução vinculada deve preservar a etapa sem link quebrado.

## Revisão de galeria, etapas e aquisição

- Galeria em duas colunas (uma em telas muito estreitas ou com fonte grande), miniaturas sem corte, legenda visível e visualizador com zoom, navegação e legenda completa.
- Publicação de foto abre prévia com legenda opcional. Foto e legenda são enviadas juntas; falha mantém o preenchimento e permite tentar novamente. Organizar revela os controles de ordem, exclusivos do proprietário.
- Etapas agrupadas em Planejadas, Em andamento e Concluídas, com menos espaço entre grupos e ação Ver evolução.
- Comigo desde aceita ano e mês opcional. Datas completas antigas permanecem armazenadas até edição explícita; apresentação usa mês/ano. Sem migration adicional (campo continua string de até 10 caracteres).
- Preparação removida do formulário; conteúdo já salvo continua preservado. A ficha mantém a leitura do dado antigo.
- Prévia usa o mesmo componente de capa da página do projeto; espaçamentos internos de origem/história reduzidos e ícone de suspensão atualizado.

Atualize a API com `docker compose up -d --build` antes de testar o app: esta revisão altera a validação da data e o envio da legenda no upload. Depois, em `mobile`, execute `flutter run -d emulator-5554`.

Revalidar: publicar foto com legenda e sem legenda; simular falha e repetir; navegar por fotos verticais/horizontais; organizar e reabrir; comparar acesso do dono e visitante; salvar somente ano e depois mês/ano; conferir que edição de outro campo preserva data antiga e preparação; concluir/reabrir etapa vinculada sem apagar evolução.

Verificação desta revisão: 116 testes backend e 174 testes Flutter aprovados; análise estática sem problemas; APK debug gerado. Validação com fotos reais pelo proprietário e CI da PR ainda complementam os testes locais.

### Acabamento final após os prints
- Menu da galeria ao lado da legenda; ordenação em linha separada apenas no modo Organizar.
- Evoluções sem foto com altura menor ajustada ao texto e à escala da fonte. Navegação ocultada quando há somente um resultado.
- Prévia de edição orienta salvar alterações.
- 21 testes dos fluxos afetados aprovados e análise estática sem problemas. Alterações apenas no app.
