CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(100) NOT NULL,
    username VARCHAR(30) NOT NULL,
    email VARCHAR(254) NOT NULL,
    senha_hash TEXT NOT NULL,
    avatar_url TEXT,
    bio VARCHAR(280),
    cidade VARCHAR(120),
    estado VARCHAR(120),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT usuarios_username_unico UNIQUE (username),
    CONSTRAINT usuarios_email_unico UNIQUE (email),
    CONSTRAINT usuarios_username_formato
        CHECK (username ~ '^[a-z0-9._]{3,30}$')
);

CREATE TABLE sessoes_refresh (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token_hash CHAR(64) NOT NULL UNIQUE,
    expira_em TIMESTAMPTZ NOT NULL,
    revogada_em TIMESTAMPTZ,
    criada_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX sessoes_refresh_usuario_idx ON sessoes_refresh(usuario_id);
CREATE INDEX sessoes_refresh_ativas_idx
    ON sessoes_refresh(usuario_id, expira_em)
    WHERE revogada_em IS NULL;

CREATE TABLE carros (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proprietario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    modelo VARCHAR(100) NOT NULL,
    ano SMALLINT,
    cor VARCHAR(50),
    placa VARCHAR(10),
    placa_visivel BOOLEAN NOT NULL DEFAULT FALSE,
    tipo_suspensao VARCHAR(50),
    aro_roda SMALLINT,
    foto_principal_url TEXT,
    historia TEXT,
    motor VARCHAR(100),
    cambio VARCHAR(50),
    combustivel VARCHAR(120),
    potencia_estimada VARCHAR(50),
    preparacao VARCHAR(100),
    status_projeto VARCHAR(50),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT carros_ano_valido CHECK (ano IS NULL OR ano BETWEEN 1886 AND 2200),
    CONSTRAINT carros_aro_valido CHECK (aro_roda IS NULL OR aro_roda BETWEEN 1 AND 40)
);

CREATE INDEX carros_proprietario_idx ON carros(proprietario_id);

CREATE TABLE evolucoes_projeto (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    carro_id UUID NOT NULL REFERENCES carros(id) ON DELETE CASCADE,
    autor_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    titulo VARCHAR(120) NOT NULL,
    descricao TEXT NOT NULL,
    categoria VARCHAR(30),
    ocorreu_em TIMESTAMPTZ,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT evolucoes_categoria_valida CHECK (
        categoria IS NULL OR categoria IN (
            'mecanica', 'estetica', 'manutencao', 'evento', 'historia', 'outra'
        )
    )
);

CREATE INDEX evolucoes_carro_data_idx
    ON evolucoes_projeto(carro_id, criado_em DESC);

CREATE TABLE midias_evolucao (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evolucao_id UUID NOT NULL REFERENCES evolucoes_projeto(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    tipo VARCHAR(10) NOT NULL DEFAULT 'imagem',
    ordem SMALLINT NOT NULL DEFAULT 0,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT midias_evolucao_tipo_valido CHECK (tipo IN ('imagem', 'video')),
    CONSTRAINT midias_evolucao_ordem_valida CHECK (ordem >= 0),
    CONSTRAINT midias_evolucao_ordem_unica UNIQUE (evolucao_id, ordem)
);

CREATE TABLE equipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dono_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    nome VARCHAR(100) NOT NULL,
    slug VARCHAR(120) NOT NULL UNIQUE,
    descricao VARCHAR(500),
    avatar_url TEXT,
    capa_url TEXT,
    cidade VARCHAR(120),
    estado VARCHAR(120),
    visibilidade VARCHAR(20) NOT NULL DEFAULT 'publica',
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT equipes_visibilidade_valida
        CHECK (visibilidade IN ('publica', 'privada'))
);

CREATE TABLE membros_equipe (
    equipe_id UUID NOT NULL REFERENCES equipes(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    papel VARCHAR(20) NOT NULL DEFAULT 'membro',
    entrou_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (equipe_id, usuario_id),
    CONSTRAINT membros_equipe_papel_valido
        CHECK (papel IN ('dono', 'administrador', 'moderador', 'membro'))
);

CREATE INDEX membros_equipe_usuario_idx ON membros_equipe(usuario_id);

CREATE TABLE solicitacoes_equipe (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipe_id UUID NOT NULL REFERENCES equipes(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente',
    analisada_por UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    criada_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    analisada_em TIMESTAMPTZ,
    CONSTRAINT solicitacoes_equipe_status_valido
        CHECK (status IN ('pendente', 'aprovada', 'recusada', 'cancelada'))
);

CREATE UNIQUE INDEX solicitacoes_equipe_pendente_unica_idx
    ON solicitacoes_equipe(equipe_id, usuario_id)
    WHERE status = 'pendente';

CREATE TABLE carros_equipe (
    equipe_id UUID NOT NULL REFERENCES equipes(id) ON DELETE CASCADE,
    carro_id UUID NOT NULL REFERENCES carros(id) ON DELETE CASCADE,
    adicionado_por UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    adicionado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (equipe_id, carro_id)
);

CREATE INDEX carros_equipe_carro_idx ON carros_equipe(carro_id);

CREATE TABLE eventos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizador_usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    organizador_equipe_id UUID REFERENCES equipes(id) ON DELETE SET NULL,
    nome VARCHAR(140) NOT NULL,
    descricao TEXT,
    inicio TIMESTAMPTZ NOT NULL,
    termino TIMESTAMPTZ,
    localizacao GEOGRAPHY(POINT, 4326) NOT NULL,
    endereco_publico TEXT,
    cidade VARCHAR(120),
    estado VARCHAR(120),
    visibilidade VARCHAR(20) NOT NULL DEFAULT 'publico',
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT eventos_organizador_obrigatorio CHECK (
        organizador_usuario_id IS NOT NULL OR organizador_equipe_id IS NOT NULL
    ),
    CONSTRAINT eventos_periodo_valido CHECK (termino IS NULL OR termino >= inicio),
    CONSTRAINT eventos_visibilidade_valida
        CHECK (visibilidade IN ('publico', 'privado', 'somente_equipe'))
);

CREATE INDEX eventos_localizacao_idx ON eventos USING GIST(localizacao);
CREATE INDEX eventos_inicio_idx ON eventos(inicio);

CREATE TABLE presencas_evento (
    evento_id UUID NOT NULL REFERENCES eventos(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    carro_id UUID REFERENCES carros(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'confirmada',
    confirmada_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (evento_id, usuario_id),
    CONSTRAINT presencas_evento_status_valido
        CHECK (status IN ('interessado', 'confirmada', 'cancelada'))
);

COMMENT ON TABLE carros_equipe IS
    'Garagem coletiva explicita. A API deve validar que adicionado_por e o proprietario do carro e membro da equipe.';

COMMENT ON COLUMN eventos.localizacao IS
    'Localizacao de evento ou ponto publico; nunca residencia ou rastreamento em tempo real.';
