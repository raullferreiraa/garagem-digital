-- Banco de dados: garagem_digital
-- Script de criação da estrutura principal do projeto Garagem Digital

CREATE DATABASE IF NOT EXISTS garagem_digital
CHARACTER SET utf8mb4
COLLATE utf8mb4_general_ci;

USE garagem_digital;

DROP TABLE IF EXISTS carros;

CREATE TABLE carros (
    id INT NOT NULL AUTO_INCREMENT,
    nome_dono VARCHAR(100) NOT NULL,
    modelo VARCHAR(100) NOT NULL,
    ano INT,
    cor VARCHAR(50),
    placa VARCHAR(10),
    tipo_suspensao VARCHAR(50),
    aro_roda INT,
    foto_url VARCHAR(255),
    historia TEXT,
    senha_edicao VARCHAR(255) NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Dados fictícios opcionais para demonstração
-- Observação: as senhas abaixo são hashes de exemplo.
-- Para testar edição/exclusão, recomenda-se cadastrar novos carros pela aplicação.

INSERT INTO carros (
    nome_dono,
    modelo,
    ano,
    cor,
    placa,
    tipo_suspensao,
    aro_roda,
    foto_url,
    senha_edicao,
    usuario_id INT,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
) VALUES
(
    'Dono Exemplo',
    'Volkswagen Gol Quadrado',
    1994,
    'Prata',
    'ABC1D23',
    'Fixa',
    15,
    '',
    'scrypt:32768:8:1$exemplo$hashdemonstrativo'
);

CREATE TABLE usuarios (
    id INT NOT NULL AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);