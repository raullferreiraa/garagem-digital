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
