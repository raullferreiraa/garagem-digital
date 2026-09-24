# Refinamento de usabilidade — 23/09/2026

Escopo: revisão transversal de navegação, ações, formulários, busca, mensagens,
estados vazios/erro e componentes compartilhados. Sem redesign, alterações de
regras de negócio, banco ou endpoints neste ciclo. Não substitui inspeção manual
de todas as telas no Android.

## Ajustes

- Formulários de projeto, evolução, equipe, encontro, cadastro e perfil levam
  até o primeiro campo inválido. Também aplicado à troca de senha.
- Rolagem fecha o teclado nos formulários tratados; envio fecha o teclado antes
  de validar. A seleção de fotos oferece câmera e galeria com cancelamento seguro.
- Busca de encontros tem limpeza rápida e recuperação dos filtros. Falha inicial
  não aparece como comunidade vazia; resultado inexistente ganha mensagem própria.
- Conversas com conteúdo têm cabeçalho compacto e atalho para encontrar pessoas.
  Falha de refresh mantém a lista com aviso e tentativa novamente explícita.
- Remover avatar pede confirmação. Falhas ao abrir câmera/galeria do perfil são
  tratadas e salvamento dos dados não concorre com atualização da foto.
- Singular/plural corrigido nos indicadores e cabeçalho do chat da equipe.

## Conferência manual consolidada

1. Criar equipe: foto quadrada compacta, capa proporcional, troca/remoção de seleção.
2. Página da equipe: botão de conversa com badge; lápis reúne dados e imagens.
3. Formulário longo: tentar salvar com campo obrigatório vazio retorna ao erro.
4. Fotos: escolher câmera ou galeria, cancelar, recortar e salvar.
5. Encontros: busca inexistente, limpar busca, filtro vazio e ver todos.
6. Conversas: cabeçalho compacto, acesso à descoberta e recuperação após desconexão.
7. Perfil: cancelar remoção de foto não altera avatar; confirmar remove.
8. Regressão: criação com foto, conversa direta/equipe, presença coletiva e exclusão
   de comunidade continuam seguindo o roteiro do ciclo anterior.

Melhorias maiores (rascunhos persistentes, pesquisa dentro das mensagens e mídia
privada autenticada) ficam para ciclos próprios, com definição de comportamento.
