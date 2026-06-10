DROP TABLE IF EXISTS cartoes_embarque CASCADE;
DROP TABLE IF EXISTS bagagens CASCADE;
DROP TABLE IF EXISTS passagens CASCADE;
DROP TABLE IF EXISTS reservas CASCADE;
DROP TABLE IF EXISTS escalas_tripulacao CASCADE;
DROP TABLE IF EXISTS voos CASCADE;
DROP TABLE IF EXISTS funcionarios CASCADE;
DROP TABLE IF EXISTS passageiros CASCADE;
DROP TABLE IF EXISTS aeronaves CASCADE;
DROP TABLE IF EXISTS terminais CASCADE;
DROP TABLE IF EXISTS aeroportos CASCADE;
DROP TABLE IF EXISTS fornecedores CASCADE;
DROP TABLE IF EXISTS tipos_bagagem CASCADE;
DROP TABLE IF EXISTS categorias_tarifa CASCADE;
DROP TABLE IF EXISTS status_voo CASCADE;
DROP TABLE IF EXISTS cargos_funcionarios CASCADE;
DROP TABLE IF EXISTS modelos_aeronave CASCADE;
DROP TABLE IF EXISTS fabricantes CASCADE;
DROP TABLE IF EXISTS cidades CASCADE;
DROP TABLE IF EXISTS paises CASCADE;

DROP PROCEDURE IF EXISTS sp_criar_indices_otimizados();
DROP PROCEDURE IF EXISTS sp_remover_indices_otimizados();
DROP FUNCTION IF EXISTS fn_validar_capacidade_voo() CASCADE;
DROP FUNCTION IF EXISTS fn_validar_salario_cargo() CASCADE;
DROP FUNCTION IF EXISTS fn_validar_terminal_voo() CASCADE;

CREATE TABLE paises (
    id              SERIAL PRIMARY KEY,
    nome            VARCHAR(100) NOT NULL,
    codigo_iso2     CHAR(2) NOT NULL UNIQUE,
    codigo_iso3     CHAR(3) NOT NULL UNIQUE,
    continente      VARCHAR(30) NOT NULL,
    CONSTRAINT chk_paises_iso2 CHECK (codigo_iso2 ~ '^[A-Z0-9]{2}$'),
    CONSTRAINT chk_paises_iso3 CHECK (codigo_iso3 ~ '^[A-Z0-9]{3}$'),
    CONSTRAINT chk_paises_continente CHECK (
        continente IN (
            'EUROPA', 'ASIA', 'AFRICA', 'AMERICA_DO_NORTE',
            'AMERICA_DO_SUL', 'OCEANIA', 'ANTARTICA'
        )
    )
);

CREATE TABLE cidades (
    id                SERIAL PRIMARY KEY,
    nome              VARCHAR(150) NOT NULL,
    pais_id           INTEGER NOT NULL REFERENCES paises(id),
    estado_provincia  VARCHAR(100),
    populacao         INTEGER,
    latitude          NUMERIC(9,6),
    longitude         NUMERIC(9,6),
    CONSTRAINT chk_cidades_populacao CHECK (populacao IS NULL OR populacao > 0),
    CONSTRAINT chk_cidades_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_cidades_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE fabricantes (
    id              SERIAL PRIMARY KEY,
    nome            VARCHAR(120) NOT NULL,
    pais_origem_id  INTEGER NOT NULL REFERENCES paises(id),
    ano_fundacao    INTEGER,
    website         VARCHAR(255),
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_fabricantes_ano CHECK (
        ano_fundacao IS NULL OR ano_fundacao BETWEEN 1900 AND 2026
    )
);

CREATE TABLE modelos_aeronave (
    id                      SERIAL PRIMARY KEY,
    nome                    VARCHAR(100) NOT NULL,
    fabricante_id           INTEGER NOT NULL REFERENCES fabricantes(id),
    capacidade_passageiros  INTEGER NOT NULL,
    alcance_km              INTEGER NOT NULL,
    peso_max_decolagem_kg   NUMERIC(10,2),
    ano_primeiro_voo        INTEGER,
    envergadura_metros      NUMERIC(5,2),
    CONSTRAINT chk_modelos_capacidade CHECK (
        capacidade_passageiros > 0 AND capacidade_passageiros <= 1000
    ),
    CONSTRAINT chk_modelos_alcance CHECK (alcance_km > 0),
    CONSTRAINT chk_modelos_peso CHECK (
        peso_max_decolagem_kg IS NULL OR peso_max_decolagem_kg > 0
    ),
    CONSTRAINT chk_modelos_primeiro_voo CHECK (
        ano_primeiro_voo IS NULL OR ano_primeiro_voo BETWEEN 1900 AND 2026
    )
);

CREATE TABLE cargos_funcionarios (
    id            SERIAL PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL UNIQUE,
    descricao     TEXT,
    nivel_acesso  INTEGER NOT NULL DEFAULT 1,
    salario_min   NUMERIC(10,2),
    salario_max   NUMERIC(10,2),
    CONSTRAINT chk_cargos_nivel CHECK (nivel_acesso BETWEEN 1 AND 10),
    CONSTRAINT chk_cargos_salario_min CHECK (salario_min IS NULL OR salario_min > 0),
    CONSTRAINT chk_cargos_salario_max CHECK (salario_max IS NULL OR salario_max > 0),
    CONSTRAINT chk_cargos_salario_faixa CHECK (
        salario_min IS NULL OR salario_max IS NULL OR salario_min <= salario_max
    )
);

CREATE TABLE status_voo (
    id              SERIAL PRIMARY KEY,
    codigo          VARCHAR(20) NOT NULL UNIQUE,
    descricao       VARCHAR(200) NOT NULL,
    cor_hex         CHAR(7),
    ordem_exibicao  INTEGER,
    CONSTRAINT chk_status_cor CHECK (cor_hex IS NULL OR cor_hex ~ '^#[0-9A-Fa-f]{6}$')
);

CREATE TABLE categorias_tarifa (
    id                    SERIAL PRIMARY KEY,
    nome                  VARCHAR(50) NOT NULL UNIQUE,
    descricao             TEXT,
    multiplicador_preco   NUMERIC(4,2) NOT NULL DEFAULT 1.00,
    bagagem_inclusa_kg    INTEGER NOT NULL DEFAULT 0,
    prioridade_embarque   INTEGER,
    CONSTRAINT chk_tarifa_multiplicador CHECK (multiplicador_preco > 0),
    CONSTRAINT chk_tarifa_bagagem CHECK (bagagem_inclusa_kg >= 0),
    CONSTRAINT chk_tarifa_prioridade CHECK (
        prioridade_embarque IS NULL OR prioridade_embarque BETWEEN 1 AND 5
    )
);

CREATE TABLE tipos_bagagem (
    id                SERIAL PRIMARY KEY,
    nome              VARCHAR(50) NOT NULL UNIQUE,
    descricao         TEXT,
    peso_max_kg       NUMERIC(5,2) NOT NULL,
    dimensoes_max_cm  VARCHAR(30),
    taxa_extra        NUMERIC(8,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT chk_tipo_bagagem_peso CHECK (peso_max_kg > 0),
    CONSTRAINT chk_tipo_bagagem_taxa CHECK (taxa_extra >= 0)
);

CREATE TABLE terminais (
    id                SERIAL PRIMARY KEY,
    nome              VARCHAR(50) NOT NULL,
    aeroporto_id      INTEGER NOT NULL,
    capacidade_gates  INTEGER,
    tipo              VARCHAR(30) NOT NULL DEFAULT 'DOMESTICO',
    ativo             BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_terminais_gates CHECK (
        capacidade_gates IS NULL OR capacidade_gates > 0
    ),
    CONSTRAINT chk_terminais_tipo CHECK (
        tipo IN ('DOMESTICO', 'INTERNACIONAL', 'MISTO', 'CARGA')
    ),
    CONSTRAINT uq_terminal_aeroporto UNIQUE (nome, aeroporto_id)
);

CREATE TABLE fornecedores (
    id             SERIAL PRIMARY KEY,
    nome           VARCHAR(150) NOT NULL,
    pais_id        INTEGER NOT NULL REFERENCES paises(id),
    tipo_servico   VARCHAR(100) NOT NULL,
    telefone       VARCHAR(30),
    email          VARCHAR(150),
    cnpj_vat       VARCHAR(30),
    ativo          BOOLEAN NOT NULL DEFAULT TRUE,
    data_contrato  DATE,
    CONSTRAINT chk_fornecedores_servico CHECK (
        tipo_servico IN (
            'CATERING', 'COMBUSTIVEL', 'LIMPEZA', 'MANUTENCAO',
            'SEGURANCA', 'HANDLING', 'TRANSPORTE', 'TECNOLOGIA',
            'LOGISTICA', 'CONSULTORIA'
        )
    )
);

CREATE TABLE aeroportos (
    id                SERIAL PRIMARY KEY,
    nome              VARCHAR(200) NOT NULL,
    codigo_iata       CHAR(3) NOT NULL UNIQUE,
    codigo_icao       CHAR(4) NOT NULL UNIQUE,
    cidade_id         INTEGER NOT NULL REFERENCES cidades(id),
    latitude          NUMERIC(9,6) NOT NULL,
    longitude         NUMERIC(9,6) NOT NULL,
    altitude_metros   INTEGER DEFAULT 0,
    fuso_horario      VARCHAR(50),
    ativo             BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_aeroportos_iata CHECK (codigo_iata ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_aeroportos_icao CHECK (codigo_icao ~ '^[A-Z]{4}$'),
    CONSTRAINT chk_aeroportos_latitude CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_aeroportos_longitude CHECK (longitude BETWEEN -180 AND 180)
);

ALTER TABLE terminais
    ADD CONSTRAINT fk_terminais_aeroportos
    FOREIGN KEY (aeroporto_id) REFERENCES aeroportos(id);

CREATE TABLE aeronaves (
    id                  SERIAL PRIMARY KEY,
    matricula           VARCHAR(15) NOT NULL UNIQUE,
    modelo_id           INTEGER NOT NULL REFERENCES modelos_aeronave(id),
    ano_fabricacao      INTEGER NOT NULL,
    data_ultima_revisao DATE,
    total_horas_voo     INTEGER NOT NULL DEFAULT 0,
    ativa               BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_aeronaves_ano CHECK (ano_fabricacao BETWEEN 1950 AND 2026),
    CONSTRAINT chk_aeronaves_horas CHECK (total_horas_voo >= 0)
);

CREATE TABLE passageiros (
    id                    SERIAL PRIMARY KEY,
    nome                  VARCHAR(100) NOT NULL,
    sobrenome             VARCHAR(100) NOT NULL,
    email                 VARCHAR(200) UNIQUE,
    telefone              VARCHAR(30),
    data_nascimento       DATE NOT NULL,
    numero_passaporte     VARCHAR(20),
    nacionalidade_id      INTEGER NOT NULL REFERENCES paises(id),
    programa_fidelidade   VARCHAR(30),
    milhas_acumuladas     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_passageiros_nascimento CHECK (data_nascimento <= CURRENT_DATE),
    CONSTRAINT chk_passageiros_milhas CHECK (milhas_acumuladas >= 0)
);

CREATE TABLE funcionarios (
    id                    SERIAL PRIMARY KEY,
    nome                  VARCHAR(100) NOT NULL,
    sobrenome             VARCHAR(100) NOT NULL,
    email                 VARCHAR(200) NOT NULL UNIQUE,
    cargo_id              INTEGER NOT NULL REFERENCES cargos_funcionarios(id),
    aeroporto_base_id     INTEGER NOT NULL REFERENCES aeroportos(id),
    data_contratacao      DATE NOT NULL,
    salario               NUMERIC(10,2) NOT NULL,
    ativo                 BOOLEAN NOT NULL DEFAULT TRUE,
    numero_identificacao  VARCHAR(30) NOT NULL UNIQUE,
    CONSTRAINT chk_funcionarios_salario CHECK (salario > 0),
    CONSTRAINT chk_funcionarios_contratacao CHECK (data_contratacao <= CURRENT_DATE)
);

CREATE TABLE voos (
    id                    SERIAL PRIMARY KEY,
    numero_voo            VARCHAR(10) NOT NULL,
    aeronave_id           INTEGER NOT NULL REFERENCES aeronaves(id),
    aeroporto_origem_id   INTEGER NOT NULL REFERENCES aeroportos(id),
    aeroporto_destino_id  INTEGER NOT NULL REFERENCES aeroportos(id),
    data_partida          TIMESTAMPTZ NOT NULL,
    data_chegada          TIMESTAMPTZ NOT NULL,
    status_id             INTEGER NOT NULL REFERENCES status_voo(id),
    preco_base            NUMERIC(10,2) NOT NULL,
    CONSTRAINT chk_voos_datas CHECK (data_partida < data_chegada),
    CONSTRAINT chk_voos_rota CHECK (aeroporto_origem_id <> aeroporto_destino_id),
    CONSTRAINT chk_voos_preco CHECK (preco_base > 0)
);

CREATE TABLE escalas_tripulacao (
    id               SERIAL PRIMARY KEY,
    funcionario_id   INTEGER NOT NULL REFERENCES funcionarios(id),
    voo_id           INTEGER NOT NULL REFERENCES voos(id),
    funcao           VARCHAR(50) NOT NULL,
    data_atribuicao  DATE NOT NULL DEFAULT CURRENT_DATE,
    confirmado       BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_escala_tripulacao UNIQUE (funcionario_id, voo_id),
    CONSTRAINT chk_escala_funcao CHECK (
        funcao IN (
            'COMANDANTE', 'COPILOTO', 'COMISSARIO', 'COMISSARIO_CHEFE',
            'MECANICO_BORDO', 'ENGENHEIRO_VOO'
        )
    )
);

CREATE TABLE reservas (
    id                    SERIAL PRIMARY KEY,
    passageiro_id         INTEGER NOT NULL REFERENCES passageiros(id),
    voo_id                INTEGER NOT NULL REFERENCES voos(id),
    categoria_tarifa_id   INTEGER NOT NULL REFERENCES categorias_tarifa(id),
    codigo_reserva        CHAR(6) NOT NULL UNIQUE,
    data_reserva          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    preco_total           NUMERIC(10,2) NOT NULL,
    status                VARCHAR(20) NOT NULL DEFAULT 'CONFIRMADA',
    CONSTRAINT chk_reservas_preco CHECK (preco_total > 0),
    CONSTRAINT chk_reservas_status CHECK (
        status IN ('CONFIRMADA', 'CANCELADA', 'PENDENTE', 'EMBARCADA', 'NO_SHOW')
    )
);

CREATE TABLE passagens (
    id                SERIAL PRIMARY KEY,
    reserva_id        INTEGER NOT NULL UNIQUE REFERENCES reservas(id),
    numero_passagem   VARCHAR(20) NOT NULL UNIQUE,
    assento           VARCHAR(5),
    classe            VARCHAR(20) NOT NULL DEFAULT 'ECONOMICA',
    emitida_em        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_passagens_classe CHECK (
        classe IN ('ECONOMICA', 'EXECUTIVA', 'PRIMEIRA_CLASSE')
    )
);

CREATE TABLE bagagens (
    id                 SERIAL PRIMARY KEY,
    passagem_id        INTEGER NOT NULL REFERENCES passagens(id),
    tipo_bagagem_id    INTEGER NOT NULL REFERENCES tipos_bagagem(id),
    peso_kg            NUMERIC(5,2) NOT NULL,
    codigo_rastreio    VARCHAR(20) NOT NULL UNIQUE,
    status             VARCHAR(30) NOT NULL DEFAULT 'DESPACHADA',
    CONSTRAINT chk_bagagens_peso CHECK (peso_kg > 0),
    CONSTRAINT chk_bagagens_status CHECK (
        status IN ('DESPACHADA', 'EM_TRANSITO', 'ENTREGUE', 'EXTRAVIADA', 'DANIFICADA')
    )
);

CREATE TABLE cartoes_embarque (
    id              SERIAL PRIMARY KEY,
    passagem_id     INTEGER NOT NULL UNIQUE REFERENCES passagens(id),
    terminal_id     INTEGER NOT NULL REFERENCES terminais(id),
    gate            VARCHAR(10) NOT NULL,
    zona_embarque   INTEGER NOT NULL,
    hora_embarque   TIMESTAMPTZ NOT NULL,
    codigo_barras   VARCHAR(30) NOT NULL UNIQUE,
    impresso        BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_cartoes_zona CHECK (zona_embarque BETWEEN 1 AND 6)
);

-- 3. TRIGGERS
CREATE OR REPLACE FUNCTION fn_validar_capacidade_voo()
RETURNS TRIGGER AS $$
DECLARE
    v_capacidade INTEGER;
    v_reservas INTEGER;
BEGIN
    SELECT ma.capacidade_passageiros
      INTO v_capacidade
      FROM voos v
      JOIN aeronaves a ON a.id = v.aeronave_id
      JOIN modelos_aeronave ma ON ma.id = a.modelo_id
     WHERE v.id = NEW.voo_id;

    SELECT COUNT(*)
      INTO v_reservas
      FROM reservas
     WHERE voo_id = NEW.voo_id
       AND status NOT IN ('CANCELADA', 'NO_SHOW');

    IF v_reservas >= v_capacidade THEN
        RAISE EXCEPTION 'Voo % excede a capacidade operacional de % lugares.',
            NEW.voo_id, v_capacidade;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_capacidade_reserva
BEFORE INSERT ON reservas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_capacidade_voo();

CREATE OR REPLACE FUNCTION fn_validar_salario_cargo()
RETURNS TRIGGER AS $$
DECLARE
    v_min NUMERIC(10,2);
    v_max NUMERIC(10,2);
BEGIN
    SELECT salario_min, salario_max
      INTO v_min, v_max
      FROM cargos_funcionarios
     WHERE id = NEW.cargo_id;

    IF v_min IS NOT NULL AND NEW.salario < v_min THEN
        RAISE WARNING 'Salario % abaixo do minimo % do cargo %.',
            NEW.salario, v_min, NEW.cargo_id;
    END IF;

    IF v_max IS NOT NULL AND NEW.salario > v_max THEN
        RAISE WARNING 'Salario % acima do maximo % do cargo %.',
            NEW.salario, v_max, NEW.cargo_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_salario_funcionario
BEFORE INSERT OR UPDATE ON funcionarios
FOR EACH ROW
EXECUTE FUNCTION fn_validar_salario_cargo();

CREATE OR REPLACE FUNCTION fn_validar_terminal_voo()
RETURNS TRIGGER AS $$
DECLARE
    v_aeroporto_terminal INTEGER;
    v_aeroporto_origem INTEGER;
BEGIN
    SELECT t.aeroporto_id
      INTO v_aeroporto_terminal
      FROM terminais t
     WHERE t.id = NEW.terminal_id;

    SELECT v.aeroporto_origem_id
      INTO v_aeroporto_origem
      FROM passagens p
      JOIN reservas r ON r.id = p.reserva_id
      JOIN voos v ON v.id = r.voo_id
     WHERE p.id = NEW.passagem_id;

    IF v_aeroporto_terminal IS DISTINCT FROM v_aeroporto_origem THEN
        RAISE WARNING 'Terminal % nao pertence ao aeroporto de origem do voo.',
            NEW.terminal_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_terminal_cartao
BEFORE INSERT OR UPDATE ON cartoes_embarque
FOR EACH ROW
EXECUTE FUNCTION fn_validar_terminal_voo();

CREATE INDEX idx_cidades_pais_id ON cidades (pais_id);
CREATE INDEX idx_fabricantes_pais_origem_id ON fabricantes (pais_origem_id);
CREATE INDEX idx_modelos_fabricante_id ON modelos_aeronave (fabricante_id);
CREATE INDEX idx_fornecedores_pais_id ON fornecedores (pais_id);
CREATE INDEX idx_terminais_aeroporto_id ON terminais (aeroporto_id);
CREATE INDEX idx_aeroportos_cidade_id ON aeroportos (cidade_id);
CREATE INDEX idx_aeronaves_modelo_id ON aeronaves (modelo_id);
CREATE INDEX idx_passageiros_nacionalidade_id ON passageiros (nacionalidade_id);
CREATE INDEX idx_funcionarios_cargo_id ON funcionarios (cargo_id);
CREATE INDEX idx_funcionarios_aeroporto_base_id ON funcionarios (aeroporto_base_id);
CREATE INDEX idx_voos_aeronave_id ON voos (aeronave_id);
CREATE INDEX idx_voos_aeroporto_origem_id ON voos (aeroporto_origem_id);
CREATE INDEX idx_voos_aeroporto_destino_id ON voos (aeroporto_destino_id);
CREATE INDEX idx_voos_status_id ON voos (status_id);
CREATE INDEX idx_escalas_funcionario_id ON escalas_tripulacao (funcionario_id);
CREATE INDEX idx_escalas_voo_id ON escalas_tripulacao (voo_id);
CREATE INDEX idx_reservas_passageiro_id ON reservas (passageiro_id);
CREATE INDEX idx_reservas_voo_id ON reservas (voo_id);
CREATE INDEX idx_reservas_categoria_tarifa_id ON reservas (categoria_tarifa_id);
CREATE INDEX idx_bagagens_passagem_id ON bagagens (passagem_id);
CREATE INDEX idx_bagagens_tipo_bagagem_id ON bagagens (tipo_bagagem_id);
CREATE INDEX idx_cartoes_terminal_id ON cartoes_embarque (terminal_id);


CREATE OR REPLACE PROCEDURE sp_criar_indices_otimizados()
LANGUAGE plpgsql
AS $$
BEGIN
    CREATE INDEX IF NOT EXISTS idx_voos_rota_data
        ON voos (aeroporto_origem_id, aeroporto_destino_id, data_partida);
    CREATE INDEX IF NOT EXISTS idx_voos_status_partida
        ON voos (status_id, data_partida) INCLUDE (numero_voo, aeroporto_origem_id, aeroporto_destino_id);
    CREATE INDEX IF NOT EXISTS idx_voos_preco_base
        ON voos (preco_base) INCLUDE (numero_voo, aeroporto_origem_id);
    CREATE INDEX IF NOT EXISTS idx_voos_mes_partida
        ON voos ((date_trunc('month', data_partida AT TIME ZONE 'UTC')));

    CREATE INDEX IF NOT EXISTS idx_reservas_voo_status
        ON reservas (voo_id, status) INCLUDE (preco_total, passageiro_id, categoria_tarifa_id);
    CREATE INDEX IF NOT EXISTS idx_reservas_status_data
        ON reservas (status, data_reserva, voo_id) INCLUDE (preco_total, passageiro_id);
    CREATE INDEX IF NOT EXISTS idx_reservas_passageiro_data
        ON reservas (passageiro_id, data_reserva DESC) INCLUDE (voo_id, preco_total, status);
    CREATE INDEX IF NOT EXISTS idx_reservas_confirmadas
        ON reservas (voo_id, passageiro_id) WHERE status = 'CONFIRMADA';

    CREATE INDEX IF NOT EXISTS idx_passageiros_email_lower
        ON passageiros (lower(email)) WHERE email IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_passageiros_nome_lower
        ON passageiros (lower(nome), lower(sobrenome));
    CREATE INDEX IF NOT EXISTS idx_passageiros_milhas
        ON passageiros (milhas_acumuladas DESC) WHERE milhas_acumuladas > 0;
    CREATE INDEX IF NOT EXISTS idx_passageiros_nac_covering
        ON passageiros (nacionalidade_id) INCLUDE (nome, sobrenome, email, milhas_acumuladas);

    CREATE INDEX IF NOT EXISTS idx_escalas_voo_funcao
        ON escalas_tripulacao (voo_id, funcao) INCLUDE (funcionario_id, confirmado);
    CREATE INDEX IF NOT EXISTS idx_escalas_funcionario_confirmado
        ON escalas_tripulacao (funcionario_id, confirmado) INCLUDE (voo_id, funcao);

    CREATE INDEX IF NOT EXISTS idx_funcionarios_ativos_cargo_base
        ON funcionarios (cargo_id, aeroporto_base_id) WHERE ativo = TRUE;
    CREATE INDEX IF NOT EXISTS idx_funcionarios_base_cargo
        ON funcionarios (aeroporto_base_id, cargo_id) INCLUDE (nome, sobrenome, salario, ativo);

    CREATE INDEX IF NOT EXISTS idx_bagagens_status_tipo
        ON bagagens (status, tipo_bagagem_id) INCLUDE (passagem_id, peso_kg);
    CREATE INDEX IF NOT EXISTS idx_bagagens_pendentes
        ON bagagens (passagem_id) WHERE status IN ('DESPACHADA', 'EM_TRANSITO');

    CREATE INDEX IF NOT EXISTS idx_cartoes_hora_terminal
        ON cartoes_embarque (hora_embarque, terminal_id) INCLUDE (passagem_id, gate, zona_embarque);
    CREATE INDEX IF NOT EXISTS idx_cartoes_terminal_gate
        ON cartoes_embarque (terminal_id, gate) INCLUDE (passagem_id, hora_embarque);

    CREATE INDEX IF NOT EXISTS idx_categorias_multiplicador
        ON categorias_tarifa (multiplicador_preco) INCLUDE (nome);
    CREATE INDEX IF NOT EXISTS idx_fornecedores_servico_pais
        ON fornecedores (tipo_servico, pais_id) WHERE ativo = TRUE;
    CREATE INDEX IF NOT EXISTS idx_modelos_capacidade_fabricante
        ON modelos_aeronave (capacidade_passageiros, fabricante_id);
    CREATE INDEX IF NOT EXISTS idx_aeroportos_iata_cidade
        ON aeroportos (codigo_iata, cidade_id) WHERE ativo = TRUE;

    ANALYZE;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_remover_indices_otimizados()
LANGUAGE plpgsql
AS $$
BEGIN
    DROP INDEX IF EXISTS idx_voos_rota_data;
    DROP INDEX IF EXISTS idx_voos_status_partida;
    DROP INDEX IF EXISTS idx_voos_preco_base;
    DROP INDEX IF EXISTS idx_voos_mes_partida;
    DROP INDEX IF EXISTS idx_reservas_voo_status;
    DROP INDEX IF EXISTS idx_reservas_status_data;
    DROP INDEX IF EXISTS idx_reservas_passageiro_data;
    DROP INDEX IF EXISTS idx_reservas_confirmadas;
    DROP INDEX IF EXISTS idx_passageiros_email_lower;
    DROP INDEX IF EXISTS idx_passageiros_nome_lower;
    DROP INDEX IF EXISTS idx_passageiros_milhas;
    DROP INDEX IF EXISTS idx_passageiros_nac_covering;
    DROP INDEX IF EXISTS idx_escalas_voo_funcao;
    DROP INDEX IF EXISTS idx_escalas_funcionario_confirmado;
    DROP INDEX IF EXISTS idx_funcionarios_ativos_cargo_base;
    DROP INDEX IF EXISTS idx_funcionarios_base_cargo;
    DROP INDEX IF EXISTS idx_bagagens_status_tipo;
    DROP INDEX IF EXISTS idx_bagagens_pendentes;
    DROP INDEX IF EXISTS idx_cartoes_hora_terminal;
    DROP INDEX IF EXISTS idx_cartoes_terminal_gate;
    DROP INDEX IF EXISTS idx_categorias_multiplicador;
    DROP INDEX IF EXISTS idx_fornecedores_servico_pais;
    DROP INDEX IF EXISTS idx_modelos_capacidade_fabricante;
    DROP INDEX IF EXISTS idx_aeroportos_iata_cidade;

    ANALYZE;
END;
$$;

COMMENT ON PROCEDURE sp_criar_indices_otimizados() IS
    'Cria indices compostos, parciais, funcionais e covering para os benchmarks.';
COMMENT ON PROCEDURE sp_remover_indices_otimizados() IS
    'Remove os indices otimizados para regressar ao cenario baseline.';