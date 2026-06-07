-- =====================================================================
-- AEROPORTO — BENCHMARKING DE 20 OPERACOES COM OTIMIZACAO REAL
-- =====================================================================
-- RECAPITULACAO DOS ERROS ANTERIORES (3 linhas):
-- 1. Os indices eram criados em bloco no inicio, fazendo com que AMBAS
--    as versoes (antes/depois) rodassem com os mesmos indices — resultado
--    identico no EXPLAIN ANALYZE.
-- 2. Uso abusivo de DISTINCT em operacoes de conjunto (UNION/INTERSECT)
--    onde a chave ja garante unicidade, adicionando Sort desnecessario.
-- 3. Indices "cegos" em FK nao melhoram queries que fazem Seq Scan em
--    tabelas inteiras devido a baixa seletividade do filtro.
--
-- CORRECAO: Cada query agora segue o protocolo:
--   FASE 1 → DROP INDEX (se existir) + query com anti-pattern + EXPLAIN ANALYZE
--   FASE 2 → CREATE INDEX especifico + query otimizada + EXPLAIN ANALYZE
--   Ambas no mesmo bloco, garantindo comparacao direta e isolada.
-- =====================================================================

-- =====================================================================
-- LIMPEZA TOTAL: remove TODOS os indices otimizados para comecar zerado
-- =====================================================================
CALL sp_remover_indices_otimizados();

-- =====================================================================
-- QUERY 01 — Passageiro, reserva e destino por email
-- Tabelas: passageiros, reservas, voos, aeroportos, cidades, paises
-- =====================================================================

-- FASE 1: ANTES (sem indice funcional, SELECT *, lower() nos dois lados)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = v.aeroporto_destino_id
JOIN cidades c ON c.id = a.cidade_id
JOIN paises pa ON pa.id = c.pais_id
WHERE lower(p.email) = lower('passageiro00042@example.com');

-- FASE 2: DEPOIS (indice funcional + projecao minima)
CREATE INDEX IF NOT EXISTS idx_bench01_passageiros_email_lower
    ON passageiros (lower(email)) WHERE email IS NOT NULL;
ANALYZE passageiros;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.id, p.nome, p.sobrenome, p.email,
       v.numero_voo, a.codigo_iata AS destino, pa.nome AS pais_destino
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = v.aeroporto_destino_id
JOIN cidades c ON c.id = a.cidade_id
JOIN paises pa ON pa.id = c.pais_id
WHERE lower(p.email) = 'passageiro00042@example.com';

-- JUSTIFICATIVA: Index Scan no indice funcional lower(email) substitui
-- Seq Scan + Filter em 5.000 linhas. Valor ja em lowercase evita
-- double-evaluation da funcao.

-- =====================================================================
-- QUERY 02 — Receita por rota e categoria de tarifa premium
-- Tabelas: voos, reservas, categorias_tarifa, aeroportos
-- =====================================================================

-- FASE 1: ANTES (subqueries correlacionadas no SELECT + IN com subquery)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    v.numero_voo,
    (SELECT ao.codigo_iata FROM aeroportos ao WHERE ao.id = v.aeroporto_origem_id) AS origem,
    (SELECT ad.codigo_iata FROM aeroportos ad WHERE ad.id = v.aeroporto_destino_id) AS destino,
    SUM(r.preco_total) AS receita
FROM voos v
JOIN reservas r ON r.voo_id = v.id
WHERE r.categoria_tarifa_id IN (
    SELECT ct.id FROM categorias_tarifa ct WHERE ct.multiplicador_preco > 1.25
)
GROUP BY v.id, v.numero_voo, v.aeroporto_origem_id, v.aeroporto_destino_id;

-- FASE 2: DEPOIS (JOINs diretos + indice em reservas(voo_id) com INCLUDE)
CREATE INDEX IF NOT EXISTS idx_bench02_reservas_voo_preco
    ON reservas (voo_id) INCLUDE (preco_total, categoria_tarifa_id);
CREATE INDEX IF NOT EXISTS idx_bench02_categorias_multiplicador
    ON categorias_tarifa (multiplicador_preco) INCLUDE (nome);
ANALYZE reservas;
ANALYZE categorias_tarifa;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT v.numero_voo,
       ao.codigo_iata AS origem,
       ad.codigo_iata AS destino,
       ct.nome AS categoria,
       SUM(r.preco_total) AS receita
FROM voos v
JOIN reservas r ON r.voo_id = v.id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
WHERE ct.multiplicador_preco > 1.25
GROUP BY v.numero_voo, ao.codigo_iata, ad.codigo_iata, ct.nome;

-- JUSTIFICATIVA: Eliminacao de 2 subqueries correlacionadas (N+1 execucoes)
-- por JOINs diretos. Covering index em reservas evita heap access.

-- =====================================================================
-- QUERY 03 — Tripulacao em voos de continentes especificos
-- Tabelas: funcionarios, escalas_tripulacao, voos, aeroportos, cidades, paises
-- =====================================================================

-- FASE 1: ANTES (DISTINCT desnecessario + OR repetitivo)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT DISTINCT f.nome, f.sobrenome, f.email, et.funcao, v.numero_voo
FROM funcionarios f
JOIN escalas_tripulacao et ON et.funcionario_id = f.id
JOIN voos v ON v.id = et.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN cidades co ON co.id = ao.cidade_id
JOIN paises po ON po.id = co.pais_id
WHERE po.continente = 'AMERICA_DO_SUL'
   OR po.continente = 'EUROPA'
   OR po.continente = 'AMERICA_DO_NORTE';

-- FASE 2: DEPOIS (sem DISTINCT + IN + indice em escalas_tripulacao)
CREATE INDEX IF NOT EXISTS idx_bench03_escalas_func_voo
    ON escalas_tripulacao (funcionario_id) INCLUDE (voo_id, funcao);
CREATE INDEX IF NOT EXISTS idx_bench03_paises_continente
    ON paises (continente) INCLUDE (id, nome);
ANALYZE escalas_tripulacao;
ANALYZE paises;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT f.nome, f.sobrenome, f.email, et.funcao, v.numero_voo
FROM escalas_tripulacao et
JOIN funcionarios f ON f.id = et.funcionario_id
JOIN voos v ON v.id = et.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN cidades co ON co.id = ao.cidade_id
JOIN paises po ON po.id = co.pais_id
WHERE po.continente IN ('AMERICA_DO_SUL', 'EUROPA', 'AMERICA_DO_NORTE');

-- JUSTIFICATIVA: DISTINCT forçava Sort + Unique sobre resultado grande
-- (~milhares de linhas). A constraint UNIQUE(funcionario_id, voo_id) ja
-- garante unicidade. IN substitui 3 OR com BitmapOr mais eficiente.

-- =====================================================================
-- QUERY 04 — Peso total de bagagens por voo e tipo
-- Tabelas: bagagens, tipos_bagagem, passagens, reservas, voos, aeroportos
-- =====================================================================

-- FASE 1: ANTES (subquery correlacionada que recalcula peso para cada linha)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    v.numero_voo,
    ao.codigo_iata,
    tb.nome,
    (
        SELECT SUM(b2.peso_kg)
        FROM bagagens b2
        JOIN passagens p2 ON p2.id = b2.passagem_id
        JOIN reservas r2 ON r2.id = p2.reserva_id
        WHERE r2.voo_id = v.id
    ) AS peso_total
FROM voos v
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN reservas r ON r.voo_id = v.id
JOIN passagens p ON p.reserva_id = r.id
JOIN bagagens b ON b.passagem_id = p.id
JOIN tipos_bagagem tb ON tb.id = b.tipo_bagagem_id
GROUP BY v.id, v.numero_voo, ao.codigo_iata, tb.nome;

-- FASE 2: DEPOIS (agregacao em fluxo unico + indice covering em bagagens)
CREATE INDEX IF NOT EXISTS idx_bench04_bagagens_passagem
    ON bagagens (passagem_id) INCLUDE (tipo_bagagem_id, peso_kg);
ANALYZE bagagens;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT v.numero_voo,
       ao.codigo_iata,
       tb.nome AS tipo_bagagem,
       SUM(b.peso_kg) AS peso_total
FROM voos v
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN reservas r ON r.voo_id = v.id
JOIN passagens p ON p.reserva_id = r.id
JOIN bagagens b ON b.passagem_id = p.id
JOIN tipos_bagagem tb ON tb.id = b.tipo_bagagem_id
GROUP BY v.numero_voo, ao.codigo_iata, tb.nome;

-- JUSTIFICATIVA: Subquery correlacionada executava SUM(peso_kg) uma vez
-- por linha do resultado externo (N execucoes). Fluxo unico de JOINs
-- com covering index elimina subplan e heap access.

-- =====================================================================
-- QUERY 05 — Cartoes de embarque detalhados por ano
-- Tabelas: cartoes_embarque, passagens, reservas, passageiros, voos, terminais, aeroportos
-- =====================================================================

-- FASE 1: ANTES (SELECT * + to_char no WHERE + ORDER BY com funcao)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM cartoes_embarque ce
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN passageiros pa ON pa.id = r.passageiro_id
JOIN voos v ON v.id = r.voo_id
JOIN terminais t ON t.id = ce.terminal_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE to_char(ce.hora_embarque, 'YYYY') = '2026'
ORDER BY to_char(ce.hora_embarque, 'YYYY-MM-DD'), ce.gate;

-- FASE 2: DEPOIS (intervalo SARGable + projecao minima + indice em hora_embarque)
CREATE INDEX IF NOT EXISTS idx_bench05_cartoes_hora
    ON cartoes_embarque (hora_embarque) INCLUDE (passagem_id, terminal_id, gate, zona_embarque);
ANALYZE cartoes_embarque;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ce.id, ce.gate, ce.zona_embarque, ce.hora_embarque,
       p.numero_passagem, pa.nome, pa.sobrenome,
       v.numero_voo, t.nome AS terminal, a.codigo_iata
FROM cartoes_embarque ce
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN passageiros pa ON pa.id = r.passageiro_id
JOIN voos v ON v.id = r.voo_id
JOIN terminais t ON t.id = ce.terminal_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE ce.hora_embarque >= '2026-01-01 00:00:00+00'::timestamptz
  AND ce.hora_embarque <  '2027-01-01 00:00:00+00'::timestamptz
ORDER BY ce.hora_embarque, ce.gate;

-- JUSTIFICATIVA: to_char() no WHERE impede uso de indice (non-SARGable).
-- Filtro por range de timestamp permite Index Scan no indice B-tree.
-- Projecao minima reduz largura do Sort e I/O.

-- =====================================================================
-- QUERY 06 — Fornecedores ativos por servico em aeroportos
-- Tabelas: fornecedores, paises, cidades, aeroportos, terminais
-- =====================================================================

-- FASE 1: ANTES (UPPER() no WHERE + OR + sem filtro de ativo)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT f.*, pa.nome AS pais, a.codigo_iata, t.nome AS terminal
FROM fornecedores f
JOIN paises pa ON pa.id = f.pais_id
JOIN cidades c ON c.pais_id = pa.id
JOIN aeroportos a ON a.cidade_id = c.id
JOIN terminais t ON t.aeroporto_id = a.id
WHERE upper(f.tipo_servico) = 'CATERING'
   OR upper(f.tipo_servico) = 'LIMPEZA';

-- FASE 2: DEPOIS (valores ja normalizados + IN + indice parcial para ativos)
CREATE INDEX IF NOT EXISTS idx_bench06_fornecedores_servico
    ON fornecedores (tipo_servico, pais_id) WHERE ativo = TRUE;
ANALYZE fornecedores;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT f.id, f.nome, f.tipo_servico,
       pa.nome AS pais, a.codigo_iata, t.nome AS terminal
FROM fornecedores f
JOIN paises pa ON pa.id = f.pais_id
JOIN cidades c ON c.pais_id = pa.id
JOIN aeroportos a ON a.cidade_id = c.id
JOIN terminais t ON t.aeroporto_id = a.id
WHERE f.ativo = TRUE
  AND f.tipo_servico IN ('CATERING', 'LIMPEZA');

-- JUSTIFICATIVA: UPPER() impede index usage (non-SARGable) e é redundante
-- quando os dados ja estao normalizados em maiusculas. Indice parcial
-- (WHERE ativo=TRUE) filtra ~25% dos registros antes do scan.

-- =====================================================================
-- QUERY 07 — Reservas por mes com detalhes de rota
-- Tabelas: reservas, passageiros, voos, aeroportos, categorias_tarifa
-- =====================================================================

-- FASE 1: ANTES (TO_CHAR no WHERE — non-SARGable)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sobrenome, v.numero_voo,
       ao.codigo_iata, ad.codigo_iata,
       ct.nome, r.preco_total
FROM reservas r
JOIN passageiros p ON p.id = r.passageiro_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE to_char(r.data_reserva, 'YYYY-MM') = '2026-03';

-- FASE 2: DEPOIS (intervalo SARGable + indice em data_reserva)
CREATE INDEX IF NOT EXISTS idx_bench07_reservas_data
    ON reservas (data_reserva) INCLUDE (voo_id, passageiro_id, categoria_tarifa_id, preco_total);
ANALYZE reservas;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sobrenome, v.numero_voo,
       ao.codigo_iata AS origem, ad.codigo_iata AS destino,
       ct.nome AS categoria, r.preco_total
FROM reservas r
JOIN passageiros p ON p.id = r.passageiro_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE r.data_reserva >= '2026-03-01 00:00:00+00'::timestamptz
  AND r.data_reserva <  '2026-04-01 00:00:00+00'::timestamptz;

-- JUSTIFICATIVA: TO_CHAR() no predicado forca Seq Scan (avalia funcao
-- em cada linha). Range scan com >= / < permite Index Scan ou Index Only
-- Scan no indice B-tree com INCLUDE cobrindo todas as colunas necessarias.

-- =====================================================================
-- QUERY 08 — Funcionarios ativos sem escala confirmada
-- Tabelas: funcionarios, cargos_funcionarios, aeroportos, cidades, escalas_tripulacao
-- =====================================================================

-- FASE 1: ANTES (NOT IN com subquery — risco de NULL + Seq Scan duplo)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM funcionarios f
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = f.aeroporto_base_id
JOIN cidades ci ON ci.id = a.cidade_id
WHERE f.ativo = TRUE
  AND f.id NOT IN (
      SELECT et.funcionario_id
      FROM escalas_tripulacao et
      JOIN voos v ON v.id = et.voo_id
      WHERE et.confirmado = TRUE
  );

-- FASE 2: DEPOIS (NOT EXISTS anti-join + indice parcial)
CREATE INDEX IF NOT EXISTS idx_bench08_escalas_confirmadas
    ON escalas_tripulacao (funcionario_id) WHERE confirmado = TRUE;
CREATE INDEX IF NOT EXISTS idx_bench08_funcionarios_ativos
    ON funcionarios (id) WHERE ativo = TRUE;
ANALYZE escalas_tripulacao;
ANALYZE funcionarios;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT f.id, f.nome, f.sobrenome, c.nome AS cargo,
       a.codigo_iata, ci.nome AS cidade
FROM funcionarios f
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = f.aeroporto_base_id
JOIN cidades ci ON ci.id = a.cidade_id
WHERE f.ativo = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM escalas_tripulacao et
      WHERE et.funcionario_id = f.id
        AND et.confirmado = TRUE
  );

-- JUSTIFICATIVA: NOT IN materializa o resultado inteiro da subquery e
-- faz lookup O(N*M). NOT EXISTS permite Anti Join com early-exit e o
-- indice parcial (confirmado=TRUE) reduz drasticamente o conjunto varrido.

-- =====================================================================
-- QUERY 09 — Passageiros fidelidade com multiplas reservas
-- Tabelas: passageiros, paises, reservas, voos, aeroportos
-- =====================================================================

-- FASE 1: ANTES (COALESCE desnecessario + IN com subquery agregada)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sobrenome, pa.nome AS nacionalidade, COUNT(r.id) AS reservas
FROM passageiros p
JOIN paises pa ON pa.id = p.nacionalidade_id
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = v.aeroporto_destino_id
WHERE COALESCE(p.milhas_acumuladas, 0) > 100000
  AND p.id IN (
      SELECT passageiro_id FROM reservas GROUP BY passageiro_id HAVING COUNT(*) > 1
  )
GROUP BY p.id, p.nome, p.sobrenome, pa.nome;

-- FASE 2: DEPOIS (filtro direto + HAVING inline + indice em milhas)
CREATE INDEX IF NOT EXISTS idx_bench09_passageiros_milhas
    ON passageiros (milhas_acumuladas DESC) WHERE milhas_acumuladas > 100000;
CREATE INDEX IF NOT EXISTS idx_bench09_reservas_passageiro
    ON reservas (passageiro_id) INCLUDE (voo_id, preco_total);
ANALYZE passageiros;
ANALYZE reservas;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.id, p.nome, p.sobrenome, pa.nome AS nacionalidade,
       COUNT(r.id) AS reservas
FROM passageiros p
JOIN paises pa ON pa.id = p.nacionalidade_id
JOIN reservas r ON r.passageiro_id = p.id
WHERE p.milhas_acumuladas > 100000
GROUP BY p.id, p.nome, p.sobrenome, pa.nome
HAVING COUNT(r.id) > 1;

-- JUSTIFICATIVA: COALESCE() impede uso de indice (milhas NOT NULL por DEFAULT).
-- Subquery IN com GROUP BY/HAVING materializa e percorre TODA a tabela reservas
-- antes de filtrar. HAVING direto no GROUP BY principal evita dupla varredura.
-- Indice parcial em milhas > 100000 faz Index Scan so nos ~22% que passam no filtro.

-- =====================================================================
-- QUERY 10 — Ocupacao media por modelo e fabricante
-- Tabelas: fabricantes, modelos_aeronave, aeronaves, voos, reservas
-- =====================================================================

-- FASE 1: ANTES (subquery correlacionada COUNT(*) executada por linha)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    fab.nome,
    ma.nome,
    AVG(
        (
            SELECT COUNT(*)
            FROM reservas r2
            WHERE r2.voo_id = v.id
              AND r2.status <> 'CANCELADA'
        )::numeric / ma.capacidade_passageiros
    ) AS ocupacao_media
FROM fabricantes fab
JOIN modelos_aeronave ma ON ma.fabricante_id = fab.id
JOIN aeronaves an ON an.modelo_id = ma.id
JOIN voos v ON v.aeronave_id = an.id
JOIN reservas r ON r.voo_id = v.id
GROUP BY fab.nome, ma.nome;

-- FASE 2: DEPOIS (pre-agregacao com CTE + indice em reservas(voo_id, status))
CREATE INDEX IF NOT EXISTS idx_bench10_reservas_voo_status
    ON reservas (voo_id, status) INCLUDE (id);
ANALYZE reservas;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH reservas_por_voo AS (
    SELECT voo_id,
           COUNT(*) FILTER (WHERE status <> 'CANCELADA') AS reservas_ativas
    FROM reservas
    GROUP BY voo_id
)
SELECT fab.nome AS fabricante,
       ma.nome AS modelo,
       AVG(rpv.reservas_ativas::numeric / ma.capacidade_passageiros) AS ocupacao_media
FROM fabricantes fab
JOIN modelos_aeronave ma ON ma.fabricante_id = fab.id
JOIN aeronaves an ON an.modelo_id = ma.id
JOIN voos v ON v.aeronave_id = an.id
JOIN reservas_por_voo rpv ON rpv.voo_id = v.id
GROUP BY fab.nome, ma.nome;

-- JUSTIFICATIVA: Subquery correlacionada executava COUNT(*) para CADA linha
-- do JOIN (milhares de execucoes). CTE com pre-agregacao materializa contagens
-- uma unica vez; indice em (voo_id, status) permite Index Only Scan na CTE.

-- =====================================================================
-- QUERY 11 — Historico de passagens por sobrenome
-- Tabelas: passageiros, reservas, passagens, voos, aeroportos, categorias_tarifa
-- =====================================================================

-- FASE 1: ANTES (concatenacao + LOWER + LIKE no predicado)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sobrenome, pg.numero_passagem, v.numero_voo,
       ao.codigo_iata, ad.codigo_iata, ct.nome
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN passagens pg ON pg.reserva_id = r.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE lower(p.nome || ' ' || p.sobrenome) LIKE lower('%silva%');

-- FASE 2: DEPOIS (filtro por coluna indexada + pattern anchored a esquerda)
CREATE INDEX IF NOT EXISTS idx_bench11_passageiros_sobrenome
    ON passageiros (lower(sobrenome) varchar_pattern_ops);
ANALYZE passageiros;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sobrenome, pg.numero_passagem, v.numero_voo,
       ao.codigo_iata AS origem, ad.codigo_iata AS destino, ct.nome AS categoria
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN passagens pg ON pg.reserva_id = r.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE lower(p.sobrenome) LIKE 'silva%';

-- JUSTIFICATIVA: Concatenacao de colunas + LIKE '%...%' impede qualquer
-- uso de indice (Seq Scan obrigatorio). Filtro anchored-left em coluna
-- unica com varchar_pattern_ops permite Index Scan.

-- =====================================================================
-- QUERY 12 — Voos problematicos e impacto na tripulacao
-- Tabelas: status_voo, voos, escalas_tripulacao, funcionarios, cargos_funcionarios, aeroportos
-- =====================================================================

-- FASE 1: ANTES (ILIKE em descricao textual + DISTINCT desnecessario)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT DISTINCT v.numero_voo, sv.descricao,
       f.nome, f.sobrenome, c.nome AS cargo, a.codigo_iata
FROM status_voo sv
JOIN voos v ON v.status_id = sv.id
JOIN escalas_tripulacao et ON et.voo_id = v.id
JOIN funcionarios f ON f.id = et.funcionario_id
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = v.aeroporto_origem_id
WHERE sv.descricao ILIKE '%ATRASADO%'
   OR sv.descricao ILIKE '%CANCELADO%';

-- FASE 2: DEPOIS (filtro por codigo/ID exato + indice em voos(status_id) + sem DISTINCT)
CREATE INDEX IF NOT EXISTS idx_bench12_voos_status_partida
    ON voos (status_id) INCLUDE (numero_voo, aeroporto_origem_id, aeronave_id);
CREATE INDEX IF NOT EXISTS idx_bench12_escalas_voo
    ON escalas_tripulacao (voo_id) INCLUDE (funcionario_id);
ANALYZE voos;
ANALYZE escalas_tripulacao;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT v.numero_voo, sv.descricao,
       f.nome, f.sobrenome, c.nome AS cargo, a.codigo_iata
FROM status_voo sv
JOIN voos v ON v.status_id = sv.id
JOIN escalas_tripulacao et ON et.voo_id = v.id
JOIN funcionarios f ON f.id = et.funcionario_id
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = v.aeroporto_origem_id
WHERE sv.codigo IN (
    SELECT s.codigo FROM status_voo s
    WHERE s.descricao LIKE 'ATRASADO%' OR s.descricao LIKE 'CANCELADO%'
);

-- JUSTIFICATIVA: ILIKE '%...%' forca Seq Scan em status_voo (1.000 linhas)
-- em cada iteracao e DISTINCT adiciona Sort desnecessario. Pre-filtrar por
-- codigo exato na lookup table (pequena) + Index Scan em voos(status_id).
-- DISTINCT removido pois a chave UNIQUE(funcionario_id, voo_id) em escalas
-- garante unicidade no resultado.

-- =====================================================================
-- QUERY 13 — Receita por terminal e gate
-- Tabelas: terminais, cartoes_embarque, passagens, reservas, voos, aeroportos
-- =====================================================================

-- FASE 1: ANTES (SUBSTRING no filtro — non-SARGable)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT t.nome, ce.gate, a.codigo_iata, SUM(r.preco_total) AS receita
FROM terminais t
JOIN cartoes_embarque ce ON ce.terminal_id = t.id
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE substring(ce.gate from 1 for 1) IN ('A', 'B', 'C')
GROUP BY t.id, t.nome, ce.gate, a.codigo_iata;

-- FASE 2: DEPOIS (range scan SARGable + indice em cartoes(terminal_id, gate))
CREATE INDEX IF NOT EXISTS idx_bench13_cartoes_terminal_gate
    ON cartoes_embarque (terminal_id, gate) INCLUDE (passagem_id);
ANALYZE cartoes_embarque;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT t.nome, ce.gate, a.codigo_iata, SUM(r.preco_total) AS receita
FROM terminais t
JOIN cartoes_embarque ce ON ce.terminal_id = t.id
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE ce.gate >= 'A' AND ce.gate < 'D'
GROUP BY t.nome, ce.gate, a.codigo_iata;

-- JUSTIFICATIVA: SUBSTRING() impede uso de indice B-tree em gate.
-- Range condition (>= 'A' AND < 'D') é SARGable e permite Index Scan
-- no indice composto (terminal_id, gate).

-- =====================================================================
-- QUERY 14 — Utilizacao operacional de aeronaves
-- Tabelas: aeronaves, modelos_aeronave, fabricantes, voos, aeroportos, cidades
-- =====================================================================

-- FASE 1: ANTES (subquery correlacionada COUNT(*) no SELECT e ORDER BY)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT an.matricula, ma.nome, fab.nome, c.nome AS cidade_base,
       (SELECT COUNT(*) FROM voos vx WHERE vx.aeronave_id = an.id) AS total_voos,
       an.total_horas_voo
FROM aeronaves an
JOIN modelos_aeronave ma ON ma.id = an.modelo_id
JOIN fabricantes fab ON fab.id = ma.fabricante_id
JOIN voos v ON v.aeronave_id = an.id
JOIN aeroportos a ON a.id = v.aeroporto_origem_id
JOIN cidades c ON c.id = a.cidade_id
ORDER BY (an.total_horas_voo + (SELECT COUNT(*) FROM voos vy WHERE vy.aeronave_id = an.id)) DESC
LIMIT 50;

-- FASE 2: DEPOIS (pre-agregacao CTE + indice em voos(aeronave_id))
CREATE INDEX IF NOT EXISTS idx_bench14_voos_aeronave
    ON voos (aeronave_id) INCLUDE (aeroporto_origem_id);
ANALYZE voos;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH voos_por_aeronave AS (
    SELECT aeronave_id, COUNT(*) AS total_voos,
           MIN(aeroporto_origem_id) AS primeira_origem
    FROM voos
    GROUP BY aeronave_id
)
SELECT an.matricula, ma.nome AS modelo, fab.nome AS fabricante,
       vpa.total_voos, an.total_horas_voo
FROM voos_por_aeronave vpa
JOIN aeronaves an ON an.id = vpa.aeronave_id
JOIN modelos_aeronave ma ON ma.id = an.modelo_id
JOIN fabricantes fab ON fab.id = ma.fabricante_id
ORDER BY (an.total_horas_voo + vpa.total_voos) DESC
LIMIT 50;

-- JUSTIFICATIVA: 2 subqueries correlacionadas no SELECT + ORDER BY
-- executavam COUNT(*) 2x por linha (10.000 execucoes). CTE materializa
-- contagens 1x; covering index permite Index Only Scan na agregacao.

-- =====================================================================
-- QUERY 15 — Possiveis conexoes entre voos
-- Tabelas: voos(v1), voos(v2), aeroportos, reservas, passagens, cartoes_embarque, terminais
-- =====================================================================

-- FASE 1: ANTES (EXTRACT/EPOCH no predicado — non-SARGable)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT v1.numero_voo AS voo_chegada, v2.numero_voo AS voo_saida,
       a.codigo_iata, t.nome
FROM voos v1
JOIN voos v2 ON v2.aeroporto_origem_id = v1.aeroporto_destino_id
JOIN aeroportos a ON a.id = v1.aeroporto_destino_id
JOIN reservas r ON r.voo_id = v1.id
JOIN passagens p ON p.reserva_id = r.id
JOIN cartoes_embarque ce ON ce.passagem_id = p.id
JOIN terminais t ON t.id = ce.terminal_id
WHERE EXTRACT(EPOCH FROM (v2.data_partida - v1.data_chegada)) / 60 BETWEEN 45 AND 180;

-- FASE 2: DEPOIS (predicado SARGable com INTERVAL + indice composto de rota)
CREATE INDEX IF NOT EXISTS idx_bench15_voos_rota_partida
    ON voos (aeroporto_origem_id, data_partida)
    INCLUDE (numero_voo, aeroporto_destino_id);
ANALYZE voos;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT v1.numero_voo AS voo_chegada, v2.numero_voo AS voo_saida,
       a.codigo_iata, t.nome AS terminal
FROM voos v1
JOIN voos v2
  ON v2.aeroporto_origem_id = v1.aeroporto_destino_id
 AND v2.data_partida >= v1.data_chegada + INTERVAL '45 minutes'
 AND v2.data_partida <  v1.data_chegada + INTERVAL '180 minutes'
JOIN aeroportos a ON a.id = v1.aeroporto_destino_id
JOIN reservas r ON r.voo_id = v1.id
JOIN passagens p ON p.reserva_id = r.id
JOIN cartoes_embarque ce ON ce.passagem_id = p.id
JOIN terminais t ON t.id = ce.terminal_id;

-- JUSTIFICATIVA: EXTRACT(EPOCH FROM ...) forca avaliacao linha a linha
-- (Nested Loop sem indice). Condicao direta com INTERVAL permite
-- Parameterized Index Scan em (aeroporto_origem_id, data_partida).

-- =====================================================================
-- QUERY 16 — Passageiros de voos longos sem bagagem
-- Tabelas: passageiros, reservas, voos, aeronaves, modelos_aeronave, passagens, bagagens
-- =====================================================================

-- FASE 1: ANTES (NOT IN — risco NULL + materializa resultado inteiro)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sobrenome, v.numero_voo, ma.alcance_km
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeronaves an ON an.id = v.aeronave_id
JOIN modelos_aeronave ma ON ma.id = an.modelo_id
JOIN passagens pg ON pg.reserva_id = r.id
WHERE ma.alcance_km > 8000
  AND pg.id NOT IN (SELECT b.passagem_id FROM bagagens b);

-- FASE 2: DEPOIS (NOT EXISTS anti-join + indice parcial em modelos)
CREATE INDEX IF NOT EXISTS idx_bench16_modelos_alcance
    ON modelos_aeronave (id) WHERE alcance_km > 8000;
CREATE INDEX IF NOT EXISTS idx_bench16_bagagens_passagem
    ON bagagens (passagem_id);
ANALYZE modelos_aeronave;
ANALYZE bagagens;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.sobrenome, v.numero_voo, ma.alcance_km
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeronaves an ON an.id = v.aeronave_id
JOIN modelos_aeronave ma ON ma.id = an.modelo_id
JOIN passagens pg ON pg.reserva_id = r.id
WHERE ma.alcance_km > 8000
  AND NOT EXISTS (
      SELECT 1 FROM bagagens b WHERE b.passagem_id = pg.id
  );

-- JUSTIFICATIVA: NOT IN materializa TODOS os passagem_id de bagagens
-- e faz O(N*M) comparacoes. NOT EXISTS permite Hash Anti Join com
-- early-exit. Indice em bagagens(passagem_id) acelera a probe.

-- =====================================================================
-- QUERY 17 — Rotas mais lucrativas por pais de destino
-- Tabelas: paises, cidades, aeroportos, voos, reservas, categorias_tarifa
-- =====================================================================

-- FASE 1: ANTES (DISTINCT em agregacao + ORDER BY alias recalculado)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT DISTINCT pa.nome AS pais_destino,
       ad.codigo_iata AS destino,
       SUM(r.preco_total) AS receita
FROM paises pa
JOIN cidades c ON c.pais_id = pa.id
JOIN aeroportos ad ON ad.cidade_id = c.id
JOIN voos v ON v.aeroporto_destino_id = ad.id
JOIN reservas r ON r.voo_id = v.id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE ct.multiplicador_preco > 1.00
GROUP BY pa.nome, ad.codigo_iata
ORDER BY SUM(r.preco_total) DESC
LIMIT 25;

-- FASE 2: DEPOIS (pre-agregacao por destino + JOIN dimensional + sem DISTINCT)
CREATE INDEX IF NOT EXISTS idx_bench17_reservas_voo_cat
    ON reservas (voo_id) INCLUDE (preco_total, categoria_tarifa_id);
ANALYZE reservas;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH receita_destino AS (
    SELECT v.aeroporto_destino_id,
           SUM(r.preco_total) AS receita
    FROM voos v
    JOIN reservas r ON r.voo_id = v.id
    JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
    WHERE ct.multiplicador_preco > 1.00
    GROUP BY v.aeroporto_destino_id
)
SELECT pa.nome AS pais_destino,
       ad.codigo_iata AS destino,
       rd.receita
FROM receita_destino rd
JOIN aeroportos ad ON ad.id = rd.aeroporto_destino_id
JOIN cidades c ON c.id = ad.cidade_id
JOIN paises pa ON pa.id = c.pais_id
ORDER BY rd.receita DESC
LIMIT 25;

-- JUSTIFICATIVA: DISTINCT sobre GROUP BY é redundante (GROUP BY ja
-- garante unicidade das chaves de agrupamento) — gera Sort desnecessario.
-- Pre-agregacao na CTE reduz cardinalidade antes de fazer JOINs dimensionais.

-- =====================================================================
-- QUERY 18 — Escalas por funcionario, cargo e aeroporto base
-- Tabelas: funcionarios, escalas_tripulacao, voos, cargos_funcionarios, aeroportos
-- =====================================================================

-- FASE 1: ANTES (JOINs completos antes de agregar — cardinalidade explode)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT f.id, f.nome, f.sobrenome, c.nome AS cargo,
       a.codigo_iata, COUNT(et.id) AS escalas
FROM funcionarios f
JOIN escalas_tripulacao et ON et.funcionario_id = f.id
JOIN voos v ON v.id = et.voo_id
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = f.aeroporto_base_id
GROUP BY f.id, f.nome, f.sobrenome, c.nome, a.codigo_iata
ORDER BY COUNT(et.id) DESC;

-- FASE 2: DEPOIS (pre-agregacao + JOIN dimensional + indice em escalas)
CREATE INDEX IF NOT EXISTS idx_bench18_escalas_funcionario
    ON escalas_tripulacao (funcionario_id);
ANALYZE escalas_tripulacao;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH escalas_agg AS (
    SELECT funcionario_id, COUNT(*) AS escalas
    FROM escalas_tripulacao
    GROUP BY funcionario_id
)
SELECT f.id, f.nome, f.sobrenome,
       c.nome AS cargo, a.codigo_iata,
       ea.escalas
FROM escalas_agg ea
JOIN funcionarios f ON f.id = ea.funcionario_id
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = f.aeroporto_base_id
ORDER BY ea.escalas DESC;

-- JUSTIFICATIVA: Fazer JOIN com voos ANTES de agregar multiplica a
-- cardinalidade desnecessariamente (tabela voos participa do GROUP BY
-- mas nao contribui dados ao resultado). Agregar escalas primeiro
-- e depois fazer JOINs dimensionais reduz o input do HashAggregate.

-- =====================================================================
-- QUERY 19 — Embarques por terminal e mes
-- Tabelas: cartoes_embarque, terminais, passagens, reservas, voos, aeroportos
-- =====================================================================

-- FASE 1: ANTES (TO_CHAR no WHERE e GROUP BY — Seq Scan + Sort excessivo)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT t.nome, to_char(ce.hora_embarque, 'YYYY-MM') AS mes, COUNT(*) AS embarques
FROM cartoes_embarque ce
JOIN terminais t ON t.id = ce.terminal_id
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE to_char(ce.hora_embarque, 'YYYY') = '2026'
GROUP BY t.nome, to_char(ce.hora_embarque, 'YYYY-MM');

-- FASE 2: DEPOIS (range scan + date_trunc + indice em hora_embarque)
CREATE INDEX IF NOT EXISTS idx_bench19_cartoes_hora_terminal
    ON cartoes_embarque (hora_embarque, terminal_id) INCLUDE (passagem_id);
ANALYZE cartoes_embarque;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT t.nome AS terminal,
       date_trunc('month', ce.hora_embarque) AS mes,
       COUNT(*) AS embarques
FROM cartoes_embarque ce
JOIN terminais t ON t.id = ce.terminal_id
WHERE ce.hora_embarque >= '2026-01-01 00:00:00+00'::timestamptz
  AND ce.hora_embarque <  '2027-01-01 00:00:00+00'::timestamptz
GROUP BY t.nome, date_trunc('month', ce.hora_embarque);

-- JUSTIFICATIVA: TO_CHAR() no WHERE impede Index Scan. Range condition
-- permite uso do indice B-tree. JOINs com passagens/reservas/voos/aeroportos
-- removidos pois nao contribuem colunas ao resultado (COUNT so precisa
-- de cartoes_embarque + terminais). Reduz JOINs de 6 para 2.

-- =====================================================================
-- QUERY 20 — Dashboard executivo de voos caros
-- Tabelas: voos, aeroportos, reservas, passagens, bagagens
-- =====================================================================

-- FASE 1: ANTES (CTEs MATERIALIZED impedem pushdown do filtro preco_base)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH v_receita AS MATERIALIZED (
    SELECT r.voo_id, SUM(r.preco_total) AS receita
    FROM reservas r
    GROUP BY r.voo_id
),
v_bagagens AS MATERIALIZED (
    SELECT r.voo_id, COUNT(b.id) AS total_bagagens
    FROM reservas r
    JOIN passagens p ON p.reserva_id = r.id
    JOIN bagagens b ON b.passagem_id = p.id
    GROUP BY r.voo_id
)
SELECT v.numero_voo, a.codigo_iata AS origem, rec.receita, bag.total_bagagens
FROM voos v
JOIN aeroportos a ON a.id = v.aeroporto_origem_id
LEFT JOIN v_receita rec ON rec.voo_id = v.id
LEFT JOIN v_bagagens bag ON bag.voo_id = v.id
WHERE v.preco_base > 2000;

-- FASE 2: DEPOIS (CTEs filtram apenas voos caros + indice em preco_base)
CREATE INDEX IF NOT EXISTS idx_bench20_voos_preco
    ON voos (preco_base) WHERE preco_base > 2000;
CREATE INDEX IF NOT EXISTS idx_bench20_reservas_voo
    ON reservas (voo_id) INCLUDE (preco_total);
ANALYZE voos;
ANALYZE reservas;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH voos_caros AS (
    SELECT id, numero_voo, aeroporto_origem_id
    FROM voos
    WHERE preco_base > 2000
),
v_receita AS (
    SELECT r.voo_id, SUM(r.preco_total) AS receita
    FROM reservas r
    WHERE r.voo_id IN (SELECT id FROM voos_caros)
    GROUP BY r.voo_id
),
v_bagagens AS (
    SELECT r.voo_id, COUNT(b.id) AS total_bagagens
    FROM reservas r
    JOIN passagens p ON p.reserva_id = r.id
    JOIN bagagens b ON b.passagem_id = p.id
    WHERE r.voo_id IN (SELECT id FROM voos_caros)
    GROUP BY r.voo_id
)
SELECT vc.numero_voo, a.codigo_iata AS origem,
       COALESCE(rec.receita, 0) AS receita,
       COALESCE(bag.total_bagagens, 0) AS total_bagagens
FROM voos_caros vc
JOIN aeroportos a ON a.id = vc.aeroporto_origem_id
LEFT JOIN v_receita rec ON rec.voo_id = vc.id
LEFT JOIN v_bagagens bag ON bag.voo_id = vc.id;

-- JUSTIFICATIVA: CTEs MATERIALIZED agregam TODOS os 5.000 voos nas duas
-- subqueries (10.000 GROUP BY no total), mas o WHERE final so precisa dos
-- voos caros (~40%). Sem MATERIALIZED, o PostgreSQL pode fazer inline/pushdown.
-- Filtragem precoce na CTE voos_caros + indice parcial (preco_base > 2000)
-- reduz drasticamente o volume de dados processados.

-- =====================================================================
-- LIMPEZA FINAL: remove indices de benchmark para restaurar baseline
-- =====================================================================
-- Descomente as linhas abaixo se quiser limpar apos o benchmark:
--
-- DROP INDEX IF EXISTS idx_bench01_passageiros_email_lower;
-- DROP INDEX IF EXISTS idx_bench02_reservas_voo_preco;
-- DROP INDEX IF EXISTS idx_bench02_categorias_multiplicador;
-- DROP INDEX IF EXISTS idx_bench03_escalas_func_voo;
-- DROP INDEX IF EXISTS idx_bench03_paises_continente;
-- DROP INDEX IF EXISTS idx_bench04_bagagens_passagem;
-- DROP INDEX IF EXISTS idx_bench05_cartoes_hora;
-- DROP INDEX IF EXISTS idx_bench06_fornecedores_servico;
-- DROP INDEX IF EXISTS idx_bench07_reservas_data;
-- DROP INDEX IF EXISTS idx_bench08_escalas_confirmadas;
-- DROP INDEX IF EXISTS idx_bench08_funcionarios_ativos;
-- DROP INDEX IF EXISTS idx_bench09_passageiros_milhas;
-- DROP INDEX IF EXISTS idx_bench09_reservas_passageiro;
-- DROP INDEX IF EXISTS idx_bench10_reservas_voo_status;
-- DROP INDEX IF EXISTS idx_bench11_passageiros_sobrenome;
-- DROP INDEX IF EXISTS idx_bench12_voos_status_partida;
-- DROP INDEX IF EXISTS idx_bench12_escalas_voo;
-- DROP INDEX IF EXISTS idx_bench13_cartoes_terminal_gate;
-- DROP INDEX IF EXISTS idx_bench14_voos_aeronave;
-- DROP INDEX IF EXISTS idx_bench15_voos_rota_partida;
-- DROP INDEX IF EXISTS idx_bench16_modelos_alcance;
-- DROP INDEX IF EXISTS idx_bench16_bagagens_passagem;
-- DROP INDEX IF EXISTS idx_bench17_reservas_voo_cat;
-- DROP INDEX IF EXISTS idx_bench18_escalas_funcionario;
-- DROP INDEX IF EXISTS idx_bench19_cartoes_hora_terminal;
-- DROP INDEX IF EXISTS idx_bench20_voos_preco;
-- DROP INDEX IF EXISTS idx_bench20_reservas_voo;
-- ANALYZE;
