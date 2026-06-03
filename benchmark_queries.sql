-- =====================================================================
-- AEROPORTO - 20 operacoes de benchmark com EXPLAIN ANALYZE
-- Execute depois de ddl.sql + dml.sql.
-- Para baseline: CALL sp_remover_indices_otimizados();
-- Para depois:   CALL sp_criar_indices_otimizados();
-- =====================================================================

\timing on

-- ---------------------------------------------------------------------
-- CENARIO ANTES: remove indices especializados e mantem apenas PK/UNIQUE/FK.
-- ---------------------------------------------------------------------
CALL sp_remover_indices_otimizados();

-- =====================================================================
-- QUERY 01 - Passageiro, reserva e destino por email
-- Tabelas: passageiros, reservas, voos, aeroportos, cidades, paises
-- Antipadroes: SELECT *, funcao no WHERE, retorno de colunas excessivo.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT *
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = v.aeroporto_destino_id
JOIN cidades c ON c.id = a.cidade_id
JOIN paises pa ON pa.id = c.pais_id
WHERE lower(p.email) = lower('passageiro00042@example.com');

-- Estrategia: usar indice funcional lower(email) e projetar somente colunas necessarias.

-- =====================================================================
-- QUERY 02 - Receita por rota e categoria de tarifa
-- Tabelas: voos, reservas, categorias_tarifa, aeroportos(origem), aeroportos(destino)
-- Antipadroes: subqueries correlacionadas no SELECT e IN para filtro.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: trocar subqueries por JOINs diretos e usar indice de categoria/multiplicador.

-- =====================================================================
-- QUERY 03 - Tripulacao em voos com origem em continentes especificos
-- Tabelas: funcionarios, escalas_tripulacao, voos, aeroportos, cidades, paises
-- Antipadroes: DISTINCT desnecessario e OR repetitivo.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: remover DISTINCT quando a chave de escala garante unicidade e substituir OR por IN.

-- =====================================================================
-- QUERY 04 - Peso total de bagagens por voo e tipo
-- Tabelas: bagagens, tipos_bagagem, passagens, reservas, voos, aeroportos
-- Antipadroes: subquery correlacionada por voo e SELECT * em derivada.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: agregar bagagens em um unico fluxo de JOINs e usar indices em bagagens/passagens/reservas.

-- =====================================================================
-- QUERY 05 - Cartoes de embarque detalhados por voo
-- Tabelas: cartoes_embarque, passagens, reservas, passageiros, voos, terminais, aeroportos
-- Antipadroes: SELECT *, ordenacao por expressao e filtro pouco seletivo.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: filtro por faixa temporal sargable e indice em hora_embarque/terminal.

-- =====================================================================
-- QUERY 06 - Fornecedores ativos em aeroportos por servico
-- Tabelas: fornecedores, paises, cidades, aeroportos, terminais
-- Antipadroes: UPPER no WHERE e OR em coluna de servico.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT f.*, pa.nome AS pais, a.codigo_iata, t.nome AS terminal
FROM fornecedores f
JOIN paises pa ON pa.id = f.pais_id
JOIN cidades c ON c.pais_id = pa.id
JOIN aeroportos a ON a.cidade_id = c.id
JOIN terminais t ON t.aeroporto_id = a.id
WHERE upper(f.tipo_servico) = 'CATERING'
   OR upper(f.tipo_servico) = 'LIMPEZA';

-- Estrategia: valores normalizados, IN e indice parcial tipo_servico/pais_id para ativos.

-- =====================================================================
-- QUERY 07 - Reservas por mes, rota e tarifa
-- Tabelas: reservas, passageiros, voos, aeroportos, categorias_tarifa
-- Antipadroes: TO_CHAR em data_reserva e SELECT de atributos redundantes.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT p.nome, p.sobrenome, v.numero_voo, ao.codigo_iata, ad.codigo_iata, ct.nome, r.preco_total
FROM reservas r
JOIN passageiros p ON p.id = r.passageiro_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE to_char(r.data_reserva, 'YYYY-MM') = '2026-03';

-- Estrategia: trocar TO_CHAR por intervalo >= e <, usando indice em status/data/voo.

-- =====================================================================
-- QUERY 08 - Funcionarios ativos sem escala confirmada
-- Tabelas: funcionarios, cargos_funcionarios, aeroportos, cidades, escalas_tripulacao
-- Antipadroes: NOT IN com subquery e SELECT *.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: NOT EXISTS anti-join e indice parcial de funcionarios ativos.

-- =====================================================================
-- QUERY 09 - Passageiros de fidelidade com multiplas reservas
-- Tabelas: passageiros, paises, reservas, voos, aeroportos
-- Antipadroes: subquery IN agregada e funcao COALESCE desnecessaria no filtro.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: usar HAVING direto, filtro simples em milhas e indice parcial em milhas.

-- =====================================================================
-- QUERY 10 - Ocupacao media por modelo e fabricante
-- Tabelas: fabricantes, modelos_aeronave, aeronaves, voos, reservas
-- Antipadroes: contagens correlacionadas executadas linha a linha.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: pre-agregar reservas por voo e juntar o resultado ao modelo.

-- =====================================================================
-- QUERY 11 - Historico de passagens de um passageiro
-- Tabelas: passageiros, reservas, passagens, voos, aeroportos, categorias_tarifa
-- Antipadroes: concatenacao e LOWER no predicado.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT p.nome, p.sobrenome, pg.numero_passagem, v.numero_voo, ao.codigo_iata, ad.codigo_iata, ct.nome
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN passagens pg ON pg.reserva_id = r.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE lower(p.nome || ' ' || p.sobrenome) LIKE lower('%silva%');

-- Estrategia: filtrar por lower(nome), lower(sobrenome) e projetar colunas minimas.

-- =====================================================================
-- QUERY 12 - Voos problemáticos e impacto na tripulacao
-- Tabelas: status_voo, voos, escalas_tripulacao, funcionarios, cargos_funcionarios, aeroportos
-- Antipadroes: OR em status textual e DISTINCT amplo.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT DISTINCT v.numero_voo, sv.descricao, f.nome, f.sobrenome, c.nome AS cargo, a.codigo_iata
FROM status_voo sv
JOIN voos v ON v.status_id = sv.id
JOIN escalas_tripulacao et ON et.voo_id = v.id
JOIN funcionarios f ON f.id = et.funcionario_id
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = v.aeroporto_origem_id
WHERE sv.descricao ILIKE '%ATRASADO%'
   OR sv.descricao ILIKE '%CANCELADO%';

-- Estrategia: consultar IDs/codigos conhecidos de status e usar indice status_id/data_partida.

-- =====================================================================
-- QUERY 13 - Receita por terminal e gate
-- Tabelas: terminais, cartoes_embarque, passagens, reservas, voos, aeroportos
-- Antipadroes: SUBSTRING no filtro de gate e agrupamento excessivo.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT t.nome, ce.gate, a.codigo_iata, SUM(r.preco_total) AS receita
FROM terminais t
JOIN cartoes_embarque ce ON ce.terminal_id = t.id
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE substring(ce.gate from 1 for 1) IN ('A', 'B', 'C')
GROUP BY t.id, t.nome, ce.gate, a.codigo_iata;

-- Estrategia: filtro por prefixo sargable quando possivel e indice terminal/gate.

-- =====================================================================
-- QUERY 14 - Utilizacao operacional de aeronaves
-- Tabelas: aeronaves, modelos_aeronave, fabricantes, voos, aeroportos, cidades
-- Antipadroes: subquery de contagem por aeronave no SELECT.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: pre-agregar voos por aeronave e ordenar sobre resultado materializado pequeno.

-- =====================================================================
-- QUERY 15 - Possiveis conexoes entre voos
-- Tabelas: voos(v1), voos(v2), aeroportos, reservas, passagens, cartoes_embarque, terminais
-- Antipadroes: funcao EXTRACT/EPOCH no predicado de intervalo.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT v1.numero_voo AS voo_chegada, v2.numero_voo AS voo_saida, a.codigo_iata, t.nome
FROM voos v1
JOIN voos v2 ON v2.aeroporto_origem_id = v1.aeroporto_destino_id
JOIN aeroportos a ON a.id = v1.aeroporto_destino_id
JOIN reservas r ON r.voo_id = v1.id
JOIN passagens p ON p.reserva_id = r.id
JOIN cartoes_embarque ce ON ce.passagem_id = p.id
JOIN terminais t ON t.id = ce.terminal_id
WHERE EXTRACT(EPOCH FROM (v2.data_partida - v1.data_chegada)) / 60 BETWEEN 45 AND 180;

-- Estrategia: predicado sargable com v2.data_partida entre v1.data_chegada + intervalos.

-- =====================================================================
-- QUERY 16 - Passageiros de voos longos sem bagagem despachada
-- Tabelas: passageiros, reservas, voos, aeronaves, modelos_aeronave, passagens, bagagens
-- Antipadroes: NOT IN e filtro de distancia sem indice.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT p.nome, p.sobrenome, v.numero_voo, ma.alcance_km
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeronaves an ON an.id = v.aeronave_id
JOIN modelos_aeronave ma ON ma.id = an.modelo_id
JOIN passagens pg ON pg.reserva_id = r.id
WHERE ma.alcance_km > 8000
  AND pg.id NOT IN (SELECT b.passagem_id FROM bagagens b);

-- Estrategia: NOT EXISTS anti-join e indice em bagagens(passagem_id).

-- =====================================================================
-- QUERY 17 - Rotas mais lucrativas por pais de destino
-- Tabelas: paises, cidades, aeroportos, voos, reservas, categorias_tarifa
-- Antipadroes: DISTINCT em agregado e ORDER BY de alias calculado sem pre-agrupamento.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT DISTINCT pa.nome AS pais_destino, ad.codigo_iata AS destino, SUM(r.preco_total) AS receita
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

-- Estrategia: remover DISTINCT e pre-agregar por destino antes de juntar dimensoes.

-- =====================================================================
-- QUERY 18 - Escalas por funcionario, cargo e aeroporto base
-- Tabelas: funcionarios, escalas_tripulacao, voos, cargos_funcionarios, aeroportos
-- Antipadroes: JOINs completos antes de reduzir cardinalidade.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT f.id, f.nome, f.sobrenome, c.nome AS cargo, a.codigo_iata, COUNT(et.id) AS escalas
FROM funcionarios f
JOIN escalas_tripulacao et ON et.funcionario_id = f.id
JOIN voos v ON v.id = et.voo_id
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = f.aeroporto_base_id
GROUP BY f.id, f.nome, f.sobrenome, c.nome, a.codigo_iata
ORDER BY COUNT(et.id) DESC;

-- Estrategia: agrupar escalas por funcionario primeiro e so depois juntar dimensoes.

-- =====================================================================
-- QUERY 19 - Embarques por terminal e mes
-- Tabelas: cartoes_embarque, terminais, passagens, reservas, voos, aeroportos
-- Antipadroes: TO_CHAR em hora_embarque no WHERE e GROUP BY.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT t.nome, to_char(ce.hora_embarque, 'YYYY-MM') AS mes, COUNT(*) AS embarques
FROM cartoes_embarque ce
JOIN terminais t ON t.id = ce.terminal_id
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE to_char(ce.hora_embarque, 'YYYY') = '2026'
GROUP BY t.nome, to_char(ce.hora_embarque, 'YYYY-MM');

-- Estrategia: filtro por intervalo de timestamps e date_trunc no agrupamento.

-- =====================================================================
-- QUERY 20 - Dashboard executivo de voos caros
-- Tabelas: voos, aeroportos, reservas, passagens, bagagens
-- Antipadroes: CTEs MATERIALIZED impedindo pushdown/inline.
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- Estrategia: permitir inline das CTEs e filtrar voos caros cedo com indice em preco_base.

-- ---------------------------------------------------------------------
-- CENARIO DEPOIS: cria indices especializados e roda as versoes otimizadas.
-- ---------------------------------------------------------------------
CALL sp_criar_indices_otimizados();

-- QUERY 01 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT p.id, p.nome, p.sobrenome, p.email, v.numero_voo, ad.codigo_iata AS destino, pa.nome AS pais_destino
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN cidades c ON c.id = ad.cidade_id
JOIN paises pa ON pa.id = c.pais_id
WHERE lower(p.email) = 'passageiro00042@example.com';

-- QUERY 02 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT v.numero_voo, ao.codigo_iata AS origem, ad.codigo_iata AS destino, ct.nome AS categoria, SUM(r.preco_total) AS receita
FROM voos v
JOIN reservas r ON r.voo_id = v.id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
WHERE ct.multiplicador_preco > 1.25
GROUP BY v.numero_voo, ao.codigo_iata, ad.codigo_iata, ct.nome;

-- QUERY 03 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT f.nome, f.sobrenome, f.email, et.funcao, v.numero_voo
FROM funcionarios f
JOIN escalas_tripulacao et ON et.funcionario_id = f.id
JOIN voos v ON v.id = et.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN cidades co ON co.id = ao.cidade_id
JOIN paises po ON po.id = co.pais_id
WHERE po.continente IN ('AMERICA_DO_SUL', 'EUROPA', 'AMERICA_DO_NORTE');

-- QUERY 04 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT v.numero_voo, ao.codigo_iata, tb.nome AS tipo_bagagem, SUM(b.peso_kg) AS peso_total
FROM voos v
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN reservas r ON r.voo_id = v.id
JOIN passagens p ON p.reserva_id = r.id
JOIN bagagens b ON b.passagem_id = p.id
JOIN tipos_bagagem tb ON tb.id = b.tipo_bagagem_id
GROUP BY v.numero_voo, ao.codigo_iata, tb.nome;

-- QUERY 05 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT ce.id, ce.gate, ce.zona_embarque, ce.hora_embarque, p.numero_passagem,
       pa.nome, pa.sobrenome, v.numero_voo, t.nome AS terminal, a.codigo_iata
FROM cartoes_embarque ce
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN passageiros pa ON pa.id = r.passageiro_id
JOIN voos v ON v.id = r.voo_id
JOIN terminais t ON t.id = ce.terminal_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE ce.hora_embarque >= TIMESTAMPTZ '2026-01-01 00:00:00+00'
  AND ce.hora_embarque <  TIMESTAMPTZ '2027-01-01 00:00:00+00'
ORDER BY ce.hora_embarque, ce.gate;

-- QUERY 06 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT f.id, f.nome, f.tipo_servico, pa.nome AS pais, a.codigo_iata, t.nome AS terminal
FROM fornecedores f
JOIN paises pa ON pa.id = f.pais_id
JOIN cidades c ON c.pais_id = pa.id
JOIN aeroportos a ON a.cidade_id = c.id
JOIN terminais t ON t.aeroporto_id = a.id
WHERE f.ativo = TRUE
  AND f.tipo_servico IN ('CATERING', 'LIMPEZA');

-- QUERY 07 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT p.nome, p.sobrenome, v.numero_voo, ao.codigo_iata AS origem, ad.codigo_iata AS destino, ct.nome, r.preco_total
FROM reservas r
JOIN passageiros p ON p.id = r.passageiro_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE r.data_reserva >= TIMESTAMPTZ '2026-03-01 00:00:00+00'
  AND r.data_reserva <  TIMESTAMPTZ '2026-04-01 00:00:00+00';

-- QUERY 08 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT f.id, f.nome, f.sobrenome, c.nome AS cargo, a.codigo_iata, ci.nome AS cidade
FROM funcionarios f
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = f.aeroporto_base_id
JOIN cidades ci ON ci.id = a.cidade_id
WHERE f.ativo = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM escalas_tripulacao et
      JOIN voos v ON v.id = et.voo_id
      WHERE et.funcionario_id = f.id
        AND et.confirmado = TRUE
  );

-- QUERY 09 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT p.id, p.nome, p.sobrenome, pa.nome AS nacionalidade, COUNT(r.id) AS reservas
FROM passageiros p
JOIN paises pa ON pa.id = p.nacionalidade_id
JOIN reservas r ON r.passageiro_id = p.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = v.aeroporto_destino_id
WHERE p.milhas_acumuladas > 100000
GROUP BY p.id, p.nome, p.sobrenome, pa.nome
HAVING COUNT(r.id) > 1;

-- QUERY 10 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH reservas_por_voo AS (
    SELECT voo_id, COUNT(*) FILTER (WHERE status <> 'CANCELADA') AS reservas_ativas
    FROM reservas
    GROUP BY voo_id
)
SELECT fab.nome, ma.nome, AVG(rpv.reservas_ativas::numeric / ma.capacidade_passageiros) AS ocupacao_media
FROM fabricantes fab
JOIN modelos_aeronave ma ON ma.fabricante_id = fab.id
JOIN aeronaves an ON an.modelo_id = ma.id
JOIN voos v ON v.aeronave_id = an.id
JOIN reservas_por_voo rpv ON rpv.voo_id = v.id
GROUP BY fab.nome, ma.nome;

-- QUERY 11 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT p.nome, p.sobrenome, pg.numero_passagem, v.numero_voo, ao.codigo_iata, ad.codigo_iata, ct.nome
FROM passageiros p
JOIN reservas r ON r.passageiro_id = p.id
JOIN passagens pg ON pg.reserva_id = r.id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
WHERE lower(p.sobrenome) LIKE 'silva%';

-- QUERY 12 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT v.numero_voo, sv.descricao, f.nome, f.sobrenome, c.nome AS cargo, a.codigo_iata
FROM status_voo sv
JOIN voos v ON v.status_id = sv.id
JOIN escalas_tripulacao et ON et.voo_id = v.id
JOIN funcionarios f ON f.id = et.funcionario_id
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = v.aeroporto_origem_id
WHERE sv.codigo IN ('ST0005', 'ST0006');

-- QUERY 13 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT t.nome, ce.gate, a.codigo_iata, SUM(r.preco_total) AS receita
FROM terminais t
JOIN cartoes_embarque ce ON ce.terminal_id = t.id
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE ce.gate >= 'A' AND ce.gate < 'D'
GROUP BY t.nome, ce.gate, a.codigo_iata;

-- QUERY 14 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH voos_por_aeronave AS (
    SELECT aeronave_id, COUNT(*) AS total_voos
    FROM voos
    GROUP BY aeronave_id
)
SELECT an.matricula, ma.nome, fab.nome, c.nome AS cidade_base, vpa.total_voos, an.total_horas_voo
FROM aeronaves an
JOIN voos_por_aeronave vpa ON vpa.aeronave_id = an.id
JOIN modelos_aeronave ma ON ma.id = an.modelo_id
JOIN fabricantes fab ON fab.id = ma.fabricante_id
JOIN voos v ON v.aeronave_id = an.id
JOIN aeroportos a ON a.id = v.aeroporto_origem_id
JOIN cidades c ON c.id = a.cidade_id
ORDER BY (an.total_horas_voo + vpa.total_voos) DESC
LIMIT 50;

-- QUERY 15 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT v1.numero_voo AS voo_chegada, v2.numero_voo AS voo_saida, a.codigo_iata, t.nome
FROM voos v1
JOIN voos v2 ON v2.aeroporto_origem_id = v1.aeroporto_destino_id
JOIN aeroportos a ON a.id = v1.aeroporto_destino_id
JOIN reservas r ON r.voo_id = v1.id
JOIN passagens p ON p.reserva_id = r.id
JOIN cartoes_embarque ce ON ce.passagem_id = p.id
JOIN terminais t ON t.id = ce.terminal_id
WHERE v2.data_partida >= v1.data_chegada + INTERVAL '45 minutes'
  AND v2.data_partida <  v1.data_chegada + INTERVAL '180 minutes';

-- QUERY 16 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
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

-- QUERY 17 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH receita_destino AS (
    SELECT v.aeroporto_destino_id, SUM(r.preco_total) AS receita
    FROM voos v
    JOIN reservas r ON r.voo_id = v.id
    JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
    WHERE ct.multiplicador_preco > 1.00
    GROUP BY v.aeroporto_destino_id
)
SELECT pa.nome AS pais_destino, ad.codigo_iata AS destino, rd.receita
FROM receita_destino rd
JOIN aeroportos ad ON ad.id = rd.aeroporto_destino_id
JOIN cidades c ON c.id = ad.cidade_id
JOIN paises pa ON pa.id = c.pais_id
ORDER BY rd.receita DESC
LIMIT 25;

-- QUERY 18 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH escalas_por_funcionario AS (
    SELECT funcionario_id, COUNT(*) AS escalas
    FROM escalas_tripulacao
    GROUP BY funcionario_id
)
SELECT f.id, f.nome, f.sobrenome, c.nome AS cargo, a.codigo_iata, epf.escalas
FROM escalas_por_funcionario epf
JOIN funcionarios f ON f.id = epf.funcionario_id
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = f.aeroporto_base_id
ORDER BY epf.escalas DESC;

-- QUERY 19 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT t.nome, date_trunc('month', ce.hora_embarque) AS mes, COUNT(*) AS embarques
FROM cartoes_embarque ce
JOIN terminais t ON t.id = ce.terminal_id
JOIN passagens p ON p.id = ce.passagem_id
JOIN reservas r ON r.id = p.reserva_id
JOIN voos v ON v.id = r.voo_id
JOIN aeroportos a ON a.id = t.aeroporto_id
WHERE ce.hora_embarque >= TIMESTAMPTZ '2026-01-01 00:00:00+00'
  AND ce.hora_embarque <  TIMESTAMPTZ '2027-01-01 00:00:00+00'
GROUP BY t.nome, date_trunc('month', ce.hora_embarque);

-- QUERY 20 - Depois
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH voos_caros AS (
    SELECT id, numero_voo, aeroporto_origem_id
    FROM voos
    WHERE preco_base > 2000
),
v_receita AS (
    SELECT r.voo_id, SUM(r.preco_total) AS receita
    FROM reservas r
    JOIN voos_caros vc ON vc.id = r.voo_id
    GROUP BY r.voo_id
),
v_bagagens AS (
    SELECT r.voo_id, COUNT(b.id) AS total_bagagens
    FROM reservas r
    JOIN voos_caros vc ON vc.id = r.voo_id
    JOIN passagens p ON p.reserva_id = r.id
    JOIN bagagens b ON b.passagem_id = p.id
    GROUP BY r.voo_id
)
SELECT vc.numero_voo, a.codigo_iata AS origem, rec.receita, bag.total_bagagens
FROM voos_caros vc
JOIN aeroportos a ON a.id = vc.aeroporto_origem_id
LEFT JOIN v_receita rec ON rec.voo_id = vc.id
LEFT JOIN v_bagagens bag ON bag.voo_id = vc.id;
