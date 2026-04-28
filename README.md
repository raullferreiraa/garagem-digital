# Garagem Digital - Cultura da Lata 027 🚘

Uma aplicação web full stack criada para catalogar, documentar e exibir projetos automotivos da cena de rua — antigos, rebaixados, modificados, daily cars e projetos em andamento.

O projeto nasceu com a proposta de criar uma **garagem digital** fora dos algoritmos das redes sociais tradicionais, valorizando a identidade de cada carro, sua ficha técnica, sua história e a cultura automotiva local.

A Garagem Digital evoluiu de um CRUD de veículos para a base inicial de uma plataforma automotiva social, com cadastro de usuários, login, garagem pessoal, feed geral de projetos, curtidas, comentários, perfis simples e controle de propriedade por usuário.

A interface utiliza uma estética escura, minimalista e low profile, inspirada em revistas automotivas modernas e aplicativos sociais, dando destaque absoluto às máquinas, suas configurações reais e suas histórias.

---

## 📌 Status do Projeto

🚧 Projeto em evolução.

A Garagem Digital já conta com autenticação de usuários, cadastro de veículos, feed geral, área de projetos pessoais, upload de imagens, filtros de busca, sistema de curtidas, comentários, modal de visualização detalhada, perfil simples de usuário e controle de propriedade para edição e exclusão.

As próximas melhorias planejadas incluem evolução do perfil, sistema de seguidores, feed social, ranking de projetos, responsividade mobile mais refinada e deploy online.

---

## 🛠️ Tecnologias Utilizadas

- **Back-end:** Python + Flask
- **Banco de Dados:** MySQL / MariaDB
- **Front-end:** HTML5, CSS3 e JavaScript Vanilla
- **Autenticação:** Cadastro e login de usuários
- **Segurança:** Hash de senha com Werkzeug
- **Upload:** Validação de imagem e nomes únicos com UUID
- **Configuração:** Variáveis de ambiente com python-dotenv
- **Controle de Versão:** Git / GitHub

---

## ⚙️ Funcionalidades

- [x] **Cadastro de Usuários:** criação de contas com nome, email e senha.
- [x] **Login de Usuários:** autenticação simples para acessar a aplicação.
- [x] **Hash de Senha:** senhas dos usuários não são salvas em texto puro no banco.
- [x] **Catálogo Dinâmico:** listagem de veículos consumindo API REST.
- [x] **Feed Geral:** aba com todos os projetos cadastrados na plataforma.
- [x] **Garagem Pessoal:** aba com apenas os projetos do usuário logado.
- [x] **Cadastro de Projetos:** criação de veículos com ficha técnica completa.
- [x] **Vínculo com Usuário:** cada projeto fica associado ao usuário que cadastrou.
- [x] **Controle de Propriedade:** apenas o dono do projeto pode editar ou remover.
- [x] **Selo de Identificação:** projetos do usuário logado exibem a tag “Seu projeto”.
- [x] **Edição de Projetos:** alteração de dados do veículo pelo proprietário.
- [x] **Exclusão de Projetos:** remoção permitida somente ao dono do projeto.
- [x] **História do Projeto:** campo para descrição, modificações e proposta visual.
- [x] **Visualização Detalhada:** modal com imagem, ficha técnica completa, história, curtidas e comentários.
- [x] **Upload de Imagens:** envio de fotos via formulário.
- [x] **Validação de Upload:** aceita apenas PNG, JPG, JPEG e WEBP.
- [x] **Nome Único para Imagens:** evita sobrescrita de arquivos com UUID.
- [x] **Limite de Upload:** arquivos limitados a 5 MB.
- [x] **Filtros de Busca:** busca por modelo, tipo de suspensão e aro.
- [x] **Sistema de Curtidas:** usuários logados podem curtir e remover curtidas dos projetos.
- [x] **Curtidas no Modal:** o usuário pode curtir ou remover curtida diretamente na visualização detalhada.
- [x] **Contador de Curtidas:** cada projeto exibe o total de curtidas recebidas.
- [x] **Estado de Curtida por Usuário:** a interface indica se o usuário já curtiu o projeto.
- [x] **Animação de Curtida:** feedback visual com animação e partículas.
- [x] **Sistema de Comentários:** usuários logados podem comentar em projetos.
- [x] **Comentários no Modal:** comentários são exibidos dentro da visualização detalhada do projeto.
- [x] **Perfil Simples de Usuário:** exibe nome, contador de projetos e cards dos carros cadastrados.
- [x] **Cards Clicáveis no Perfil:** carros exibidos no perfil podem abrir a visualização detalhada.
- [x] **Nomes Clicáveis:** nome do proprietário e autor de comentário podem abrir o perfil.
- [x] **Mensagem de Lista Vazia:** feedback visual quando não há projetos encontrados.
- [x] **Modo de Edição:** interface muda visualmente ao editar um projeto.
- [x] **Interface Dark Premium:** cards, botões e modal com visual mais moderno.
- [x] **Interface Responsiva:** ajustes para melhor uso em dispositivos móveis.
- [x] **Página Completa Documentada:** screenshot geral mostrando a aplicação em funcionamento.
- [x] **SQL Limpo:** script de banco sem dados pessoais ou sensíveis.

---

## 📸 Interface e Demonstração

### Cadastro e Login de Usuários

![Cadastro e Login](screenshots/01-login-cadastro.png)

*Área inicial da aplicação com autenticação de usuários.*

### Registro de Projetos

![Registro de Projeto](screenshots/02-registro-projeto.png)

*Formulário de cadastro com ficha técnica, upload de imagem e história do projeto.*

### Feed Geral de Projetos

![Feed Geral](screenshots/03-feed-geral.png)

*Aba com todos os projetos cadastrados na Garagem Digital.*

### Garagem Pessoal

![Garagem Pessoal](screenshots/04-meus-projetos.png)

*Aba “Meus projetos”, exibindo apenas os veículos cadastrados pelo usuário logado.*

### Visualização Detalhada do Projeto

![Visualização Detalhada](screenshots/05-visualizacao-detalhada.png)

*Modal com imagem, ficha técnica completa, história do projeto, curtidas e comentários.*

### Comentários no Projeto

![Comentários](screenshots/06-comentarios.png)

*Área de comentários dentro do modal do projeto.*

### Perfil de Usuário

![Perfil de Usuário](screenshots/07-perfil-usuario.png)

*Perfil simples com nome do usuário, quantidade de projetos e cards dos carros cadastrados.*

### Edição pelo Proprietário

![Edição de Projeto](screenshots/08-editando-projeto.png)

*Modo de edição disponível apenas para o usuário proprietário do projeto.*

### Página Completa

![Página Completa](screenshots/09-pagina-completa.png)

*Visão geral da aplicação com autenticação, cadastro de projetos, filtros, feed e listagem da garagem.*

---

## 🔐 Segurança e Controle de Acesso

O projeto foi evoluído para aplicar boas práticas básicas de segurança e organização:

- credenciais do banco removidas do código-fonte;
- uso de arquivo `.env` para configuração local;
- `.env` ignorado pelo Git;
- `.env.example` disponível como modelo;
- senhas de usuários armazenadas com hash;
- validação de formato de imagem no front-end e no back-end;
- limite de tamanho para upload;
- geração de nomes únicos para imagens;
- remoção de dados pessoais do script SQL;
- vínculo de projetos ao usuário proprietário;
- edição e exclusão permitidas apenas ao dono do projeto;
- curtidas vinculadas ao usuário logado;
- prevenção de curtidas duplicadas por meio de restrição única no banco;
- comentários vinculados ao usuário logado;
- controle visual para exibir ações de edição e exclusão apenas ao proprietário.

> Observação: a autenticação atual é simples e adequada para fins de estudo/portfólio. Futuramente, o projeto pode evoluir para uso de sessões, tokens JWT ou outro modelo mais robusto de autenticação.

---

## 🗄️ Banco de Dados

O projeto utiliza MySQL/MariaDB.

O arquivo `garagem_digital.sql` cria a estrutura necessária para a aplicação, incluindo:

- banco `garagem_digital`;
- tabela `usuarios`;
- tabela `carros`;
- tabela `curtidas`;
- tabela `comentarios`;
- relacionamento entre carros e usuários;
- relacionamento entre curtidas, usuários e carros;
- relacionamento entre comentários, usuários e carros;
- campos principais da ficha técnica;
- campo de história/descrição do projeto;
- campos de data `criado_em` e `atualizado_em`.

> Observação: os dados de teste devem ser criados pela própria aplicação para garantir que senhas, vínculos, curtidas e comentários sejam salvos corretamente.

---

## 🚀 Como rodar o projeto na sua máquina

### 1. Clone este repositório

    git clone https://github.com/raullferreiraa/garagem-digital.git

### 2. Acesse a pasta do projeto

    cd garagem-digital

### 3. Instale as dependências

    pip install -r requirements.txt

### 4. Configure as variáveis de ambiente

Crie um arquivo `.env` na raiz do projeto com base no `.env.example`.

Exemplo:

    DB_HOST=localhost
    DB_USER=root
    DB_PASSWORD=
    DB_NAME=garagem_digital
    DEBUG=True

### 5. Configure o banco de dados

Importe o arquivo:

    garagem_digital.sql

Você pode importar pelo phpMyAdmin ou pelo terminal do MySQL.

### 6. Inicie o servidor Flask

    python app.py

O servidor será iniciado em:

    http://127.0.0.1:5000

### 7. Acesse a aplicação

Abra o arquivo `index.html` diretamente no navegador.

---

## 📁 Estrutura do Projeto

    garagem-digital/
    ├── app.py
    ├── index.html
    ├── garagem_digital.sql
    ├── requirements.txt
    ├── .env.example
    ├── .gitignore
    ├── screenshots/
    └── uploads/

> A pasta `uploads/` é criada automaticamente durante a execução do projeto e não é versionada no GitHub.

---

## 🧭 Roadmap

Próximas evoluções planejadas:

- [x] Adicionar sistema de curtidas em projetos.
- [x] Adicionar comentários em projetos.
- [x] Criar perfis públicos simples de usuários.
- [x] Melhorar visual dos cards e modal.
- [ ] Adicionar avatar/foto de perfil.
- [ ] Adicionar bio no perfil.
- [ ] Criar sistema de seguidores e seguindo.
- [ ] Criar feed social personalizado.
- [ ] Criar ranking de projetos.
- [ ] Permitir editar e excluir comentários próprios.
- [ ] Exibir tempo relativo nos comentários, como “há 5 minutos”.
- [ ] Criar sistema de equipes/clubes automotivos.
- [ ] Permitir que usuários adicionem carros a uma equipe.
- [ ] Criar grupos para postagens, fotos e discussões.
- [ ] Adicionar categorias como Antigo, Rebaixado, Turbo, Daily e Projeto em andamento.
- [ ] Adicionar ordenação por mais recentes, ano, aro e modelo.
- [ ] Melhorar responsividade mobile.
- [ ] Separar CSS e JavaScript em arquivos próprios.
- [ ] Melhorar autenticação com sessões ou tokens.
- [ ] Criar deploy online.
- [ ] Gravar demonstração do sistema.

---

## 🎯 Aprendizados

Durante o desenvolvimento, foram praticados conceitos como:

- criação de API REST com Flask;
- integração entre front-end, back-end e banco de dados;
- autenticação básica de usuários;
- relacionamento entre tabelas no banco de dados;
- associação de registros ao usuário proprietário;
- controle de permissão para edição e exclusão;
- manipulação de formulários com `FormData`;
- upload e armazenamento de arquivos;
- consultas SQL com filtros dinâmicos;
- sistema de curtidas com controle por usuário;
- sistema de comentários associado a usuários e projetos;
- criação de perfil simples com dados vindos da API;
- atualização dinâmica da interface com JavaScript puro;
- controle de estado visual de curtidas;
- uso de hash para armazenamento seguro;
- configuração de ambiente com `.env`;
- organização de projeto para GitHub e portfólio;
- uso de issues, branches e pull requests;
- resolução de conflitos de branch;
- evolução incremental de um CRUD para uma aplicação com características sociais.

---

## 👨‍💻 Autor

Projeto desenvolvido por **Raul Ferreira** como parte dos estudos em Ciência da Computação na UVV, unindo desenvolvimento web, persistência de dados, aprendizado prático e cultura automotiva.
