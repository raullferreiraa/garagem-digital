# Cultura da Lata 027 - Garagem Digital 🚘

Uma aplicação web Full Stack criada para catalogar, documentar e exibir projetos automotivos da cena de rua (antigos, rebaixados e modificados), fora dos algoritmos das redes sociais tradicionais. 

O foco visual é uma estética "low profile", escura e minimalista, dando destaque absoluto às máquinas e suas especificações técnicas.

## 🛠️ Tecnologias Utilizadas

* **Back-end:** Python + Flask (API RESTful)
* **Banco de Dados:** MySQL
* **Front-end:** HTML5, CSS3 e JavaScript (Vanilla)
* **Controle de Versão:** Git / GitHub

## ⚙️ Funcionalidades (O Motor)

- [x] **Catálogo Dinâmico:** Listagem de veículos puxada diretamente do banco de dados relacional.
- [x] **Cadastro de Projetos (POST):** Inserção de dados técnicos (Modelo, Aro, Suspensão, etc).
- [x] **Upload de Imagens:** Salvamento de arquivos físicos no servidor e linkagem no banco de dados (`multipart/form-data`).
- [x] **Segurança e Exclusão (DELETE):** Remoção de projetos protegida por validação de senha do proprietário.

## 🚀 Como rodar o projeto na sua máquina

1. Clone este repositório: `git clone https://github.com/raullferreiraa/garagem-digital.git`
2. Importe o arquivo garagem_digital.sql (incluso na raiz do projeto) no seu servidor MySQL para criar o banco e a tabela automaticamente.
3. Instale as dependências do Python: `pip install flask mysql-connector-python flask-cors werkzeug`
4. Crie uma pasta chamada `uploads` na raiz do projeto.
5. Inicie o servidor: `python app.py`
6. Abra o arquivo `index.html` no seu navegador.