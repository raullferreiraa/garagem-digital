-- Banco de dados: garagem_digital
-- Script de criação da estrutura principal do projeto Garagem Digital

CREATE DATABASE IF NOT EXISTS garagem_digital
CHARACTER SET utf8mb4
COLLATE utf8mb4_general_ci;

USE garagem_digital;

DROP TABLE IF EXISTS comentarios;
DROP TABLE IF EXISTS curtidas;
DROP TABLE IF EXISTS carros;
DROP TABLE IF EXISTS usuarios;

CREATE TABLE usuarios (
    id INT NOT NULL AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE carros (
    id INT NOT NULL AUTO_INCREMENT,
    usuario_id INT,
    nome_dono VARCHAR(100) NOT NULL,
    modelo VARCHAR(100) NOT NULL,
    ano INT,
    cor VARCHAR(50),
    placa VARCHAR(10),
    tipo_suspensao VARCHAR(50),
    aro_roda INT,
    foto_url VARCHAR(255),
    historia TEXT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_carros_usuarios
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE curtidas (
    id INT NOT NULL AUTO_INCREMENT,
    usuario_id INT NOT NULL,
    carro_id INT NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY curtida_unica (usuario_id, carro_id),
    CONSTRAINT fk_curtidas_usuarios
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_curtidas_carros
        FOREIGN KEY (carro_id) REFERENCES carros(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

<<<<<<< HEAD
CREATE TABLE comentarios (
    id INT NOT NULL AUTO_INCREMENT,
    usuario_id INT NOT NULL,
    carro_id INT NOT NULL,
    texto TEXT NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_comentarios_usuarios
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_comentarios_carros
        FOREIGN KEY (carro_id) REFERENCES carros(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Observação:
-- Este script cria apenas a estrutura limpa do banco.
-- Usuários, projetos, curtidas e comentários devem ser criados pela própria aplicação
-- para garantir hashes de senha válidos e vínculos corretos entre tabelas.
=======
-- Observação:
-- Este script cria apenas a estrutura limpa do banco.
-- Usuários, projetos e curtidas devem ser criados pela própria aplicação
-- para garantir hashes de senha válidos e vínculos corretos entre tabelas.
>>>>>>> main
