-- ===================================================================
-- AEROPORTO — DDL (Data Definition Language)
-- Base de Dados de Benchmarking para Sistema Aeroportuário
-- PostgreSQL 14+
-- ===================================================================
-- Total: 20 tabelas (10 lookup + 10 negócio)
-- Gerado em: 2026-06-03
-- ===================================================================

-- ===================================================================
-- LIMPEZA PRÉVIA (ordem inversa de dependências)
-- ===================================================================
DROP TABLE IF EXISTS cartoes_embarque CASCADE;
DROP TABLE IF EXISTS bagagens CASCADE;
DROP TABLE IF EXISTS passagens CASCADE;
DROP TABLE IF EXISTS reservas CASCADE;
DROP TABLE IF EXISTS escalas_tripulacao CASCADE;
DROP TABLE IF EXISTS voos CASCADE;
DROP TABLE IF EXISTS funcionarios CASCADE;
DROP TABLE IF EXISTS passageiros CASCADE;
DROP TABLE IF EXISTS aeronaves CASCADE;
DROP TABLE IF EXISTS fornecedores CASCADE;
DROP TABLE IF EXISTS terminais CASCADE;
DROP TABLE IF EXISTS aeroportos CASCADE;
DROP TABLE IF EXISTS tipos_bagagem CASCADE;
DROP TABLE IF EXISTS categorias_tarifa CASCADE;
DROP TABLE IF EXISTS status_voo CASCADE;
DROP TABLE IF EXISTS cargos_funcionarios CASCADE;
DROP TABLE IF EXISTS modelos_aeronave CASCADE;
DROP TABLE IF EXISTS fabricantes CASCADE;
DROP TABLE IF EXISTS cidades CASCADE;
DROP TABLE IF EXISTS paises CASCADE;

DROP FUNCTION IF EXISTS fn_validar_capacidade_voo() CASCADE;
DROP FUNCTION IF EXISTS fn_validar_salario_cargo() CASCADE;

-- ===================================================================
-- ███████████████████████████████████████████████████████████████████
-- PARTE 1: TABELAS BÁSICAS / DICIONÁRIO (Lookup Tables) — 10 tabelas
-- ███████████████████████████████████████████████████████████████████
-- ===================================================================

-- -------------------------------------------------------------------
-- 1. PAÍSES
-- Tabela de referência com códigos ISO 3166-1
-- -------------------------------------------------------------------
CREATE TABLE paises (
    id              SERIAL       PRIMARY KEY,
    nome            VARCHAR(100) NOT NULL,
    codigo_iso2     CHAR(2)      NOT NULL UNIQUE,
    codigo_iso3     CHAR(3)      NOT NULL UNIQUE,
    continente      VARCHAR(50)  NOT NULL,

    CONSTRAINT chk_paises_iso2_formato
        CHECK (codigo_iso2 ~ '^[A-Z0-9]{2}$'),
    CONSTRAINT chk_paises_iso3_formato
        CHECK (codigo_iso3 ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_paises_continente
        CHECK (continente IN (
            'EUROPA', 'ASIA', 'AFRICA',
            'AMERICA_DO_NORTE', 'AMERICA_DO_SUL',
            'OCEANIA', 'ANTARTICA'
        ))
);

COMMENT ON TABLE paises IS 'Tabela dicionário de países com códigos ISO 3166-1.';

-- -------------------------------------------------------------------
-- 2. CIDADES
-- Cidades com referência ao país e coordenadas geográficas
-- -------------------------------------------------------------------
CREATE TABLE cidades (
    id              SERIAL        PRIMARY KEY,
    nome            VARCHAR(150)  NOT NULL,
    pais_id         INTEGER       NOT NULL REFERENCES paises(id),
    estado_provincia VARCHAR(100),
    populacao       INTEGER,
    latitude        DECIMAL(9,6),
    longitude       DECIMAL(9,6),

    CONSTRAINT chk_cidades_populacao
        CHECK (populacao IS NULL OR populacao > 0),
    CONSTRAINT chk_cidades_latitude
        CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90)),
    CONSTRAINT chk_cidades_longitude
        CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180))
);

COMMENT ON TABLE cidades IS 'Cidades do mundo com geolocalização e referência ao país.';

-- -------------------------------------------------------------------
-- 3. FABRICANTES
-- Fabricantes de aeronaves (Boeing, Airbus, Embraer, etc.)
-- -------------------------------------------------------------------
CREATE TABLE fabricantes (
    id              SERIAL       PRIMARY KEY,
    nome            VARCHAR(100) NOT NULL,
    pais_origem_id  INTEGER      NOT NULL REFERENCES paises(id),
    ano_fundacao    INTEGER,
    website         VARCHAR(255),
    ativo           BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_fabricantes_ano
        CHECK (ano_fundacao IS NULL OR (ano_fundacao >= 1900 AND ano_fundacao <= 2026))
);

COMMENT ON TABLE fabricantes IS 'Fabricantes de aeronaves com país de origem.';

-- -------------------------------------------------------------------
-- 4. MODELOS DE AERONAVE
-- Modelos específicos com características técnicas
-- -------------------------------------------------------------------
CREATE TABLE modelos_aeronave (
    id                      SERIAL        PRIMARY KEY,
    nome                    VARCHAR(100)  NOT NULL,
    fabricante_id           INTEGER       NOT NULL REFERENCES fabricantes(id),
    capacidade_passageiros  INTEGER       NOT NULL,
    alcance_km              INTEGER       NOT NULL,
    peso_max_decolagem_kg   DECIMAL(10,2),
    ano_primeiro_voo        INTEGER,
    envergadura_metros      DECIMAL(5,2),

    CONSTRAINT chk_modelos_capacidade
        CHECK (capacidade_passageiros > 0 AND capacidade_passageiros <= 1000),
    CONSTRAINT chk_modelos_alcance
        CHECK (alcance_km > 0),
    CONSTRAINT chk_modelos_peso
        CHECK (peso_max_decolagem_kg IS NULL OR peso_max_decolagem_kg > 0)
);

COMMENT ON TABLE modelos_aeronave IS 'Modelos de aeronave com especificações técnicas.';

-- -------------------------------------------------------------------
-- 5. CARGOS DE FUNCIONÁRIOS
-- Cargos possíveis dentro da operação aeroportuária
-- -------------------------------------------------------------------
CREATE TABLE cargos_funcionarios (
    id              SERIAL        PRIMARY KEY,
    nome            VARCHAR(100)  NOT NULL UNIQUE,
    descricao       TEXT,
    nivel_acesso    INTEGER       NOT NULL DEFAULT 1,
    salario_min     DECIMAL(10,2),
    salario_max     DECIMAL(10,2),

    CONSTRAINT chk_cargos_nivel
        CHECK (nivel_acesso BETWEEN 1 AND 10),
    CONSTRAINT chk_cargos_salario_min
        CHECK (salario_min IS NULL OR salario_min > 0),
    CONSTRAINT chk_cargos_salario_max
        CHECK (salario_max IS NULL OR salario_max > 0),
    CONSTRAINT chk_cargos_salario_coerente
        CHECK (salario_min IS NULL OR salario_max IS NULL OR salario_min <= salario_max)
);

COMMENT ON TABLE cargos_funcionarios IS 'Cargos disponíveis para funcionários do aeroporto e companhias.';

-- -------------------------------------------------------------------
-- 6. STATUS DE VOO
-- Estados possíveis de um voo durante o ciclo de vida
-- -------------------------------------------------------------------
CREATE TABLE status_voo (
    id              SERIAL       PRIMARY KEY,
    codigo          VARCHAR(20)  NOT NULL UNIQUE,
    descricao       VARCHAR(200) NOT NULL,
    cor_hex         CHAR(7),
    ordem_exibicao  INTEGER,

    CONSTRAINT chk_status_cor_hex
        CHECK (cor_hex IS NULL OR cor_hex ~ '^#[0-9A-Fa-f]{6}$')
);

COMMENT ON TABLE status_voo IS 'Estados possíveis de um voo (Programado, Embarque, Em Voo, etc.).';

-- -------------------------------------------------------------------
-- 7. CATEGORIAS DE TARIFA
-- Classes de tarifa com multiplicadores de preço
-- -------------------------------------------------------------------
CREATE TABLE categorias_tarifa (
    id                  SERIAL       PRIMARY KEY,
    nome                VARCHAR(50)  NOT NULL UNIQUE,
    descricao           TEXT,
    multiplicador_preco DECIMAL(4,2) NOT NULL DEFAULT 1.00,
    bagagem_inclusa_kg  INTEGER      NOT NULL DEFAULT 0,
    prioridade_embarque INTEGER,

    CONSTRAINT chk_tarifa_multiplicador
        CHECK (multiplicador_preco > 0),
    CONSTRAINT chk_tarifa_bagagem
        CHECK (bagagem_inclusa_kg >= 0),
    CONSTRAINT chk_tarifa_prioridade
        CHECK (prioridade_embarque IS NULL OR prioridade_embarque BETWEEN 1 AND 5)
);

COMMENT ON TABLE categorias_tarifa IS 'Categorias de tarifa (Económica, Executiva, Primeira Classe, etc.).';

-- -------------------------------------------------------------------
-- 8. TIPOS DE BAGAGEM
-- Classificação de bagagens com limites de peso
-- -------------------------------------------------------------------
CREATE TABLE tipos_bagagem (
    id              SERIAL       PRIMARY KEY,
    nome            VARCHAR(50)  NOT NULL UNIQUE,
    descricao       TEXT,
    peso_max_kg     DECIMAL(5,2) NOT NULL,
    dimensoes_max_cm VARCHAR(30),
    taxa_extra      DECIMAL(8,2) NOT NULL DEFAULT 0.00,

    CONSTRAINT chk_bagagem_peso_max
        CHECK (peso_max_kg > 0),
    CONSTRAINT chk_bagagem_taxa
        CHECK (taxa_extra >= 0)
);

COMMENT ON TABLE tipos_bagagem IS 'Tipos de bagagem (Mão, Porão, Especial, Oversized, etc.).';

-- ===================================================================
-- ███████████████████████████████████████████████████████████████████
-- PARTE 2: TABELAS PRINCIPAIS / NEGÓCIO (Core Business) — 10 tabelas
-- ███████████████████████████████████████████████████████████████████
-- ===================================================================

-- -------------------------------------------------------------------
-- 9. AEROPORTOS
-- Aeroportos com códigos IATA/ICAO e geolocalização
-- -------------------------------------------------------------------
CREATE TABLE aeroportos (
    id              SERIAL        PRIMARY KEY,
    nome            VARCHAR(200)  NOT NULL,
    codigo_iata     CHAR(3),
    codigo_icao     CHAR(4)       NOT NULL UNIQUE,
    cidade_id       INTEGER       NOT NULL REFERENCES cidades(id),
    latitude        DECIMAL(9,6)  NOT NULL,
    longitude       DECIMAL(9,6)  NOT NULL,
    altitude_metros INTEGER       DEFAULT 0,
    fuso_horario    VARCHAR(50),
    ativo           BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_aeroportos_iata_formato
        CHECK (codigo_iata IS NULL OR codigo_iata ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_aeroportos_icao_formato
        CHECK (codigo_icao ~ '^[A-Z]{4}$'),
    CONSTRAINT chk_aeroportos_latitude
        CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_aeroportos_longitude
        CHECK (longitude BETWEEN -180 AND 180)
);

-- Índice UNIQUE parcial para IATA (permite NULLs mas não duplicados)
CREATE UNIQUE INDEX uq_aeroportos_iata
    ON aeroportos (codigo_iata)
    WHERE codigo_iata IS NOT NULL;

COMMENT ON TABLE aeroportos IS 'Aeroportos com identificação IATA/ICAO e posição geográfica.';

-- -------------------------------------------------------------------
-- 10. TERMINAIS (lookup que depende de aeroportos)
-- Terminais e gates de cada aeroporto
-- -------------------------------------------------------------------
CREATE TABLE terminais (
    id              SERIAL       PRIMARY KEY,
    nome            VARCHAR(50)  NOT NULL,
    aeroporto_id    INTEGER      NOT NULL REFERENCES aeroportos(id),
    capacidade_gates INTEGER,
    tipo            VARCHAR(30)  DEFAULT 'DOMESTICO',
    ativo           BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_terminais_gates
        CHECK (capacidade_gates IS NULL OR capacidade_gates > 0),
    CONSTRAINT chk_terminais_tipo
        CHECK (tipo IN ('DOMESTICO', 'INTERNACIONAL', 'MISTO', 'CARGA')),
    CONSTRAINT uq_terminal_aeroporto
        UNIQUE (nome, aeroporto_id)
);

COMMENT ON TABLE terminais IS 'Terminais de aeroportos com tipo e capacidade.';

-- -------------------------------------------------------------------
-- 11. FORNECEDORES (lookup que depende de paises)
-- Empresas fornecedoras de serviços ao aeroporto
-- -------------------------------------------------------------------
CREATE TABLE fornecedores (
    id              SERIAL       PRIMARY KEY,
    nome            VARCHAR(150) NOT NULL,
    pais_id         INTEGER      NOT NULL REFERENCES paises(id),
    tipo_servico    VARCHAR(100) NOT NULL,
    telefone        VARCHAR(30),
    email           VARCHAR(150),
    cnpj_vat        VARCHAR(30),
    ativo           BOOLEAN      NOT NULL DEFAULT TRUE,
    data_contrato   DATE,

    CONSTRAINT chk_fornecedores_tipo_servico
        CHECK (tipo_servico IN (
            'CATERING', 'COMBUSTIVEL', 'LIMPEZA', 'MANUTENCAO',
            'SEGURANCA', 'HANDLING', 'TRANSPORTE', 'TECNOLOGIA',
            'LOGISTICA', 'CONSULTORIA'
        ))
);

COMMENT ON TABLE fornecedores IS 'Fornecedores de serviços aeroportuários.';

-- -------------------------------------------------------------------
-- 12. AERONAVES
-- Frota de aeronaves com matrícula e histórico
-- -------------------------------------------------------------------
CREATE TABLE aeronaves (
    id                  SERIAL       PRIMARY KEY,
    matricula           VARCHAR(15)  NOT NULL UNIQUE,
    modelo_id           INTEGER      NOT NULL REFERENCES modelos_aeronave(id),
    ano_fabricacao       INTEGER      NOT NULL,
    data_ultima_revisao  DATE,
    total_horas_voo     INTEGER      DEFAULT 0,
    ativa               BOOLEAN      NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_aeronaves_ano
        CHECK (ano_fabricacao >= 1950 AND ano_fabricacao <= 2026),
    CONSTRAINT chk_aeronaves_horas
        CHECK (total_horas_voo IS NULL OR total_horas_voo >= 0)
);

COMMENT ON TABLE aeronaves IS 'Frota de aeronaves com matrícula, modelo e estado operacional.';

-- -------------------------------------------------------------------
-- 13. PASSAGEIROS
-- Dados pessoais dos passageiros com programa de fidelidade
-- -------------------------------------------------------------------
CREATE TABLE passageiros (
    id                  SERIAL       PRIMARY KEY,
    nome                VARCHAR(100) NOT NULL,
    sobrenome           VARCHAR(100) NOT NULL,
    email               VARCHAR(200) UNIQUE,
    telefone            VARCHAR(30),
    data_nascimento     DATE         NOT NULL,
    numero_passaporte   VARCHAR(20),
    nacionalidade_id    INTEGER      NOT NULL REFERENCES paises(id),
    programa_fidelidade VARCHAR(30),
    milhas_acumuladas   INTEGER      DEFAULT 0,

    CONSTRAINT chk_passageiros_nascimento
        CHECK (data_nascimento <= CURRENT_DATE),
    CONSTRAINT chk_passageiros_milhas
        CHECK (milhas_acumuladas IS NULL OR milhas_acumuladas >= 0)
);

COMMENT ON TABLE passageiros IS 'Passageiros com dados pessoais e programa de fidelidade.';

-- -------------------------------------------------------------------
-- 14. FUNCIONÁRIOS
-- Funcionários do aeroporto e companhias aéreas
-- -------------------------------------------------------------------
CREATE TABLE funcionarios (
    id                    SERIAL       PRIMARY KEY,
    nome                  VARCHAR(100) NOT NULL,
    sobrenome             VARCHAR(100) NOT NULL,
    email                 VARCHAR(200) NOT NULL UNIQUE,
    cargo_id              INTEGER      NOT NULL REFERENCES cargos_funcionarios(id),
    aeroporto_base_id     INTEGER      NOT NULL REFERENCES aeroportos(id),
    data_contratacao      DATE         NOT NULL,
    salario               DECIMAL(10,2) NOT NULL,
    ativo                 BOOLEAN      NOT NULL DEFAULT TRUE,
    numero_identificacao  VARCHAR(30)  NOT NULL UNIQUE,

    CONSTRAINT chk_funcionarios_salario
        CHECK (salario > 0),
    CONSTRAINT chk_funcionarios_contratacao
        CHECK (data_contratacao <= CURRENT_DATE)
);

COMMENT ON TABLE funcionarios IS 'Funcionários do aeroporto com cargo, salário e base operacional.';

-- -------------------------------------------------------------------
-- 15. VOOS
-- Voos programados com origem, destino, horários e preço
-- -------------------------------------------------------------------
CREATE TABLE voos (
    id                    SERIAL         PRIMARY KEY,
    numero_voo            VARCHAR(10)    NOT NULL,
    aeronave_id           INTEGER        NOT NULL REFERENCES aeronaves(id),
    aeroporto_origem_id   INTEGER        NOT NULL REFERENCES aeroportos(id),
    aeroporto_destino_id  INTEGER        NOT NULL REFERENCES aeroportos(id),
    data_partida          TIMESTAMP WITH TIME ZONE NOT NULL,
    data_chegada          TIMESTAMP WITH TIME ZONE NOT NULL,
    status_id             INTEGER        NOT NULL REFERENCES status_voo(id),
    preco_base            DECIMAL(10,2)  NOT NULL,

    CONSTRAINT chk_voos_datas_coerentes
        CHECK (data_partida < data_chegada),
    CONSTRAINT chk_voos_rota_diferente
        CHECK (aeroporto_origem_id <> aeroporto_destino_id),
    CONSTRAINT chk_voos_preco
        CHECK (preco_base > 0)
);

COMMENT ON TABLE voos IS 'Voos programados com rota, horários, aeronave e preço base.';

-- -------------------------------------------------------------------
-- 16. ESCALAS DE TRIPULAÇÃO
-- Atribuição de tripulantes a voos
-- -------------------------------------------------------------------
CREATE TABLE escalas_tripulacao (
    id              SERIAL       PRIMARY KEY,
    funcionario_id  INTEGER      NOT NULL REFERENCES funcionarios(id),
    voo_id          INTEGER      NOT NULL REFERENCES voos(id),
    funcao          VARCHAR(50)  NOT NULL,
    data_atribuicao DATE         NOT NULL DEFAULT CURRENT_DATE,
    confirmado      BOOLEAN      NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_escala_tripulacao
        UNIQUE (funcionario_id, voo_id),
    CONSTRAINT chk_escala_funcao
        CHECK (funcao IN (
            'COMANDANTE', 'COPILOTO', 'COMISSARIO',
            'COMISSARIO_CHEFE', 'MECANICO_BORDO', 'ENGENHEIRO_VOO'
        ))
);

COMMENT ON TABLE escalas_tripulacao IS 'Escalas de tripulação para cada voo.';

-- -------------------------------------------------------------------
-- 17. RESERVAS
-- Reservas de viagem com código único e preço
-- -------------------------------------------------------------------
CREATE TABLE reservas (
    id                  SERIAL         PRIMARY KEY,
    passageiro_id       INTEGER        NOT NULL REFERENCES passageiros(id),
    voo_id              INTEGER        NOT NULL REFERENCES voos(id),
    categoria_tarifa_id INTEGER        NOT NULL REFERENCES categorias_tarifa(id),
    codigo_reserva      CHAR(6)        NOT NULL UNIQUE,
    data_reserva        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    preco_total         DECIMAL(10,2)  NOT NULL,
    status              VARCHAR(20)    NOT NULL DEFAULT 'CONFIRMADA',

    CONSTRAINT chk_reservas_preco
        CHECK (preco_total > 0),
    CONSTRAINT chk_reservas_status
        CHECK (status IN ('CONFIRMADA', 'CANCELADA', 'PENDENTE', 'EMBARCADA', 'NO_SHOW'))
);

COMMENT ON TABLE reservas IS 'Reservas de passageiros para voos com categoria e preço.';

-- -------------------------------------------------------------------
-- 18. PASSAGENS
-- Bilhetes emitidos vinculados a reservas
-- -------------------------------------------------------------------
CREATE TABLE passagens (
    id                  SERIAL         PRIMARY KEY,
    reserva_id          INTEGER        NOT NULL REFERENCES reservas(id),
    numero_passagem     VARCHAR(20)    NOT NULL UNIQUE,
    assento             VARCHAR(5),
    classe              VARCHAR(20)    NOT NULL DEFAULT 'ECONOMICA',
    emitida_em          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_passagens_classe
        CHECK (classe IN ('ECONOMICA', 'EXECUTIVA', 'PRIMEIRA_CLASSE'))
);

COMMENT ON TABLE passagens IS 'Passagens (bilhetes) emitidos a partir de reservas.';

-- -------------------------------------------------------------------
-- 19. BAGAGENS
-- Bagagens registadas por passageiro com rastreio
-- -------------------------------------------------------------------
CREATE TABLE bagagens (
    id              SERIAL        PRIMARY KEY,
    passagem_id     INTEGER       NOT NULL REFERENCES passagens(id),
    tipo_bagagem_id INTEGER       NOT NULL REFERENCES tipos_bagagem(id),
    peso_kg         DECIMAL(5,2)  NOT NULL,
    codigo_rastreio VARCHAR(20)   NOT NULL UNIQUE,
    status          VARCHAR(30)   NOT NULL DEFAULT 'DESPACHADA',

    CONSTRAINT chk_bagagens_peso
        CHECK (peso_kg > 0),
    CONSTRAINT chk_bagagens_status
        CHECK (status IN ('DESPACHADA', 'EM_TRANSITO', 'ENTREGUE', 'EXTRAVIADA', 'DANIFICADA'))
);

COMMENT ON TABLE bagagens IS 'Bagagens registadas com tipo, peso e código de rastreio.';

-- -------------------------------------------------------------------
-- 20. CARTÕES DE EMBARQUE
-- Cartões emitidos para embarque em voos
-- -------------------------------------------------------------------
CREATE TABLE cartoes_embarque (
    id              SERIAL        PRIMARY KEY,
    passagem_id     INTEGER       NOT NULL REFERENCES passagens(id) UNIQUE,
    terminal_id     INTEGER       NOT NULL REFERENCES terminais(id),
    gate            VARCHAR(10)   NOT NULL,
    zona_embarque   INTEGER       NOT NULL,
    hora_embarque   TIMESTAMP WITH TIME ZONE NOT NULL,
    codigo_barras   VARCHAR(30)   NOT NULL UNIQUE,
    impresso        BOOLEAN       NOT NULL DEFAULT FALSE,

    CONSTRAINT chk_cartoes_zona
        CHECK (zona_embarque BETWEEN 1 AND 6)
);

COMMENT ON TABLE cartoes_embarque IS 'Cartões de embarque emitidos para passageiros com gate e zona.';


-- ===================================================================
-- ███████████████████████████████████████████████████████████████████
-- PARTE 3: LÓGICA PROCEDURAL (PL/pgSQL) — Triggers e Funções
-- ███████████████████████████████████████████████████████████████████
-- ===================================================================

-- -------------------------------------------------------------------
-- TRIGGER: Validar capacidade máxima do voo antes de inserir reserva
-- -------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_capacidade_voo()
RETURNS TRIGGER AS $$
DECLARE
    v_capacidade   INTEGER;
    v_reservas     INTEGER;
BEGIN
    -- Obter capacidade da aeronave do voo
    SELECT ma.capacidade_passageiros
      INTO v_capacidade
      FROM voos v
      JOIN aeronaves a ON a.id = v.aeronave_id
      JOIN modelos_aeronave ma ON ma.id = a.modelo_id
     WHERE v.id = NEW.voo_id;

    -- Contar reservas ativas existentes para o voo
    SELECT COUNT(*)
      INTO v_reservas
      FROM reservas
     WHERE voo_id = NEW.voo_id
       AND status NOT IN ('CANCELADA', 'NO_SHOW');

    -- Verificar se há espaço disponível
    IF v_reservas >= v_capacidade THEN
        RAISE EXCEPTION 'Voo % atingiu capacidade máxima (% lugares). Reserva rejeitada.',
            NEW.voo_id, v_capacidade;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_capacidade_reserva
    BEFORE INSERT ON reservas
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_capacidade_voo();

COMMENT ON FUNCTION fn_validar_capacidade_voo() IS
    'Valida que o número de reservas ativas não excede a capacidade da aeronave.';

-- -------------------------------------------------------------------
-- TRIGGER: Validar que o salário do funcionário está dentro da faixa
-- do cargo atribuído
-- -------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_salario_cargo()
RETURNS TRIGGER AS $$
DECLARE
    v_salario_min DECIMAL(10,2);
    v_salario_max DECIMAL(10,2);
BEGIN
    SELECT salario_min, salario_max
      INTO v_salario_min, v_salario_max
      FROM cargos_funcionarios
     WHERE id = NEW.cargo_id;

    IF v_salario_min IS NOT NULL AND NEW.salario < v_salario_min THEN
        RAISE WARNING 'Salário (%) abaixo do mínimo do cargo (%). Inserção permitida com aviso.',
            NEW.salario, v_salario_min;
    END IF;

    IF v_salario_max IS NOT NULL AND NEW.salario > v_salario_max THEN
        RAISE WARNING 'Salário (%) acima do máximo do cargo (%). Inserção permitida com aviso.',
            NEW.salario, v_salario_max;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_salario_funcionario
    BEFORE INSERT OR UPDATE ON funcionarios
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_salario_cargo();

COMMENT ON FUNCTION fn_validar_salario_cargo() IS
    'Emite aviso quando o salário do funcionário está fora da faixa do cargo.';


-- ===================================================================
-- ███████████████████████████████████████████████████████████████████
-- PARTE 4: ÍNDICES PADRÃO (Foreign Keys)
-- ███████████████████████████████████████████████████████████████████
-- ===================================================================
-- Nota: PKs e UNIQUE já geram índices automaticamente.
-- Aqui criamos índices para as FKs mais usadas em JOINs.

CREATE INDEX idx_cidades_pais_id
    ON cidades (pais_id);

CREATE INDEX idx_fabricantes_pais_origem_id
    ON fabricantes (pais_origem_id);

CREATE INDEX idx_modelos_fabricante_id
    ON modelos_aeronave (fabricante_id);

CREATE INDEX idx_aeroportos_cidade_id
    ON aeroportos (cidade_id);

CREATE INDEX idx_terminais_aeroporto_id
    ON terminais (aeroporto_id);

CREATE INDEX idx_fornecedores_pais_id
    ON fornecedores (pais_id);

CREATE INDEX idx_aeronaves_modelo_id
    ON aeronaves (modelo_id);

CREATE INDEX idx_passageiros_nacionalidade_id
    ON passageiros (nacionalidade_id);

CREATE INDEX idx_funcionarios_cargo_id
    ON funcionarios (cargo_id);

CREATE INDEX idx_funcionarios_aeroporto_base_id
    ON funcionarios (aeroporto_base_id);

CREATE INDEX idx_voos_aeronave_id
    ON voos (aeronave_id);

CREATE INDEX idx_voos_aeroporto_origem_id
    ON voos (aeroporto_origem_id);

CREATE INDEX idx_voos_aeroporto_destino_id
    ON voos (aeroporto_destino_id);

CREATE INDEX idx_voos_status_id
    ON voos (status_id);

CREATE INDEX idx_escalas_funcionario_id
    ON escalas_tripulacao (funcionario_id);

CREATE INDEX idx_escalas_voo_id
    ON escalas_tripulacao (voo_id);

CREATE INDEX idx_reservas_passageiro_id
    ON reservas (passageiro_id);

CREATE INDEX idx_reservas_voo_id
    ON reservas (voo_id);

CREATE INDEX idx_reservas_categoria_tarifa_id
    ON reservas (categoria_tarifa_id);

CREATE INDEX idx_passagens_reserva_id
    ON passagens (reserva_id);

CREATE INDEX idx_bagagens_passagem_id
    ON bagagens (passagem_id);

CREATE INDEX idx_bagagens_tipo_bagagem_id
    ON bagagens (tipo_bagagem_id);

CREATE INDEX idx_cartoes_passagem_id
    ON cartoes_embarque (passagem_id);

CREATE INDEX idx_cartoes_terminal_id
    ON cartoes_embarque (terminal_id);


-- ===================================================================
-- ███████████████████████████████████████████████████████████████████
-- PARTE 5: ÍNDICES DE OTIMIZAÇÃO (Para Benchmarking)
-- ███████████████████████████████████████████████████████████████████
-- ===================================================================
-- Estes índices são criados APÓS a carga de dados para demonstrar
-- a melhoria de performance nas queries de benchmarking.
-- Execute esta secção APÓS o dml.sql.

-- -------------------------------------------------------------------
-- ÍNDICES COMPOSTOS
-- -------------------------------------------------------------------

-- Voos por rota e data (queries de rotas populares)
CREATE INDEX idx_voos_rota_data
    ON voos (aeroporto_origem_id, aeroporto_destino_id, data_partida);

-- Reservas por voo e status (filtragem de reservas ativas)
CREATE INDEX idx_reservas_voo_status
    ON reservas (voo_id, status);

-- Reservas por passageiro e data (histórico de reservas)
CREATE INDEX idx_reservas_passageiro_data
    ON reservas (passageiro_id, data_reserva);

-- Escalas por voo e função (consultas de tripulação)
CREATE INDEX idx_escalas_voo_funcao
    ON escalas_tripulacao (voo_id, funcao);

-- Funcionários por aeroporto e cargo (consultas operacionais)
CREATE INDEX idx_funcionarios_aeroporto_cargo
    ON funcionarios (aeroporto_base_id, cargo_id);

-- -------------------------------------------------------------------
-- COVERING INDEXES (Index Only Scan)
-- -------------------------------------------------------------------

-- Covering index para consultas frequentes de voos (evita heap access)
CREATE INDEX idx_voos_origem_destino_covering
    ON voos (aeroporto_origem_id, aeroporto_destino_id)
    INCLUDE (numero_voo, data_partida, data_chegada, preco_base);

-- Covering index para reservas com preço (relatórios financeiros)
CREATE INDEX idx_reservas_voo_covering
    ON reservas (voo_id)
    INCLUDE (passageiro_id, preco_total, status, categoria_tarifa_id);

-- Covering index para passageiros por nacionalidade
CREATE INDEX idx_passageiros_nac_covering
    ON passageiros (nacionalidade_id)
    INCLUDE (nome, sobrenome, email);

-- -------------------------------------------------------------------
-- ÍNDICES PARCIAIS (Filtered Indexes)
-- -------------------------------------------------------------------

-- Apenas voos ativos/programados (exclui cancelados e finalizados)
CREATE INDEX idx_voos_ativos
    ON voos (data_partida, aeroporto_origem_id)
    WHERE status_id IN (1, 2, 3);

-- Apenas reservas confirmadas (mais consultadas)
CREATE INDEX idx_reservas_confirmadas
    ON reservas (voo_id, passageiro_id)
    WHERE status = 'CONFIRMADA';

-- Apenas funcionários ativos
CREATE INDEX idx_funcionarios_ativos
    ON funcionarios (cargo_id, aeroporto_base_id)
    WHERE ativo = TRUE;

-- Apenas bagagens não entregues (operações em tempo real)
CREATE INDEX idx_bagagens_pendentes
    ON bagagens (passagem_id)
    WHERE status IN ('DESPACHADA', 'EM_TRANSITO');

-- -------------------------------------------------------------------
-- ÍNDICES DE EXPRESSÃO
-- -------------------------------------------------------------------

-- Busca case-insensitive por nome de passageiro
CREATE INDEX idx_passageiros_nome_lower
    ON passageiros (LOWER(nome), LOWER(sobrenome));

-- Busca case-insensitive por email de passageiro
CREATE INDEX idx_passageiros_email_lower
    ON passageiros (LOWER(email))
    WHERE email IS NOT NULL;

-- Busca por mês/ano de partida do voo
CREATE INDEX idx_voos_mes_partida
    ON voos (DATE_TRUNC('month', data_partida AT TIME ZONE 'UTC'));

-- Busca por ano de contratação do funcionário
CREATE INDEX idx_funcionarios_ano_contratacao
    ON funcionarios (EXTRACT(YEAR FROM data_contratacao));

-- -------------------------------------------------------------------
-- ÍNDICE PARA ORDENAÇÃO E RANKING
-- -------------------------------------------------------------------

-- Voos ordenados por data de partida (paginação eficiente)
CREATE INDEX idx_voos_data_partida
    ON voos (data_partida DESC);

-- Reservas ordenadas por data (relatórios recentes)
CREATE INDEX idx_reservas_data_reserva
    ON reservas (data_reserva DESC);

-- Passageiros com mais milhas (ranking fidelidade)
CREATE INDEX idx_passageiros_milhas
    ON passageiros (milhas_acumuladas DESC NULLS LAST)
    WHERE milhas_acumuladas > 0;


-- ===================================================================
-- FIM DO DDL
-- ===================================================================
-- Próximo passo: executar gerar_dados_reais.py para gerar dml.sql
-- Em seguida: executar dml.sql para carregar os 60.000 registos
-- Por fim:    executar benchmark_queries.sql para análise de performance
-- ===================================================================
