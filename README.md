# Garagem Digital - Cultura da Lata 027 🚘

Uma aplicação web Full Stack criada para catalogar, documentar e exibir projetos automotivos da cena de rua (antigos, rebaixados e modificados), fora dos algoritmos das redes sociais tradicionais. 

O foco visual utiliza uma estética "low profile", escura e minimalista, inspirada em revistas automotivas modernas, dando destaque absoluto às máquinas e suas configurações reais.

## 🛠️ Tecnologias Utilizadas

* **Back-end:** Python + Flask (API RESTful)
* **Banco de Dados:** MySQL (Relacional)
* **Front-end:** HTML5, CSS3 (Modern Sans-Serif) e JavaScript (Vanilla)
* **Controle de Versão:** Git / GitHub

## ⚙️ Funcionalidades (O Motor)

- [x] **Catálogo Dinâmico:** Listagem de veículos consumindo API REST com renderização dinâmica no Front-end.
- [x] **Ficha Técnica Detalhada:** Exibição padronizada de especificações como Aro e Tipo de Suspensão.
- [x] **Cadastro de Projetos (POST):** Inserção de dados técnicos e validação de campos obrigatórios.
- [x] **Edição de Projetos (PUT):** Interface para atualizar dados de um veículo existente, protegida por validação de senha do proprietário.
- [x] **Exclusão de Projetos (DELETE):** Remoção definitiva de registros do banco de dados, também protegida por senha.
- [x] **Upload de Imagens:** Processamento de arquivos via `multipart/form-data` e armazenamento no servidor.
- [x] **Filtros de Busca:** Sistema de filtragem por modelo, tipo de suspensão e tamanho do aro.

## 📸 Interface e Demonstração

### Registro de Projetos
![Interface de Registro](screenshots/01-registro-projeto.png)

*O formulário de cadastro permite inserir as especificações técnicas e definir uma senha de proteção para o projeto.*

### Visualização de Cards (Ficha Técnica)
![Card Detalhado do Omega](screenshots/02-card-carro.png)

*Os projetos são exibidos em cards padronizados, com destaque para a Ficha Técnica gerada dinamicamente.*

### Sistema de Filtros e Busca
O sistema permite filtrar projetos por modelo, tipo de suspensão e tamanho do aro em tempo real.
![Filtros Dinâmicos em Ação](screenshots/03-resultado-pesquisa.png)

*Exemplo de busca refinada retornando resultados específicos do banco de dados.*

### Edição Protegida
Toda alteração nos dados do veículo exige a autenticação via senha definida no cadastro.
![Formulário de Edição](screenshots/04-editando-projeto.png)

*O modo de edição destaca o formulário com uma borda diferenciada e altera o fluxo de salvamento do sistema.*

### Visão Geral do Sistema
![Página Completa](screenshots/05-pagina-completa.png)

*Visão completa da aplicação, integrando cadastro, filtros e galeria.*

## 🚀 Como rodar o projeto na sua máquina

1. **Clone este repositório:**
   `git clone https://github.com/raullferreiraa/garagem-digital.git`

2. **Banco de Dados:**
   Importe o arquivo `garagem_digital.sql` (incluso na raiz) no seu MySQL (via phpMyAdmin ou terminal) para estruturar a tabela `carros` automaticamente.

3. **Dependências do Python:**
   Instale as bibliotecas necessárias:
   `pip install flask mysql-connector-python flask-cors werkzeug`

4. **Inicie o servidor:**
   Execute o comando: `python app.py`
   *(O sistema criará a pasta `uploads` automaticamente se ela não existir).*

5. **Acesse a Garagem:**
   Abra o arquivo `index.html` diretamente no seu navegador.

---
*Projeto desenvolvido por Raul Ferreira como parte dos estudos de Ciência da Computação na UVV, focado em integração de sistemas e persistência de dados.*