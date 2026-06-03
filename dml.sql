-- =====================================================================
-- AEROPORTO - DML: Consultas de Validacao e Relatorios Pos-Carga
-- Execute no pgAdmin DEPOIS de rodar gerar_dados_reais.py
-- =====================================================================

-- 1) Verificar volumetria de todas as tabelas
SELECT 'paises' AS tabela, COUNT(*) AS registros FROM paises
UNION ALL SELECT 'cidades', COUNT(*) FROM cidades
UNION ALL SELECT 'fabricantes', COUNT(*) FROM fabricantes
UNION ALL SELECT 'modelos_aeronave', COUNT(*) FROM modelos_aeronave
UNION ALL SELECT 'cargos_funcionarios', COUNT(*) FROM cargos_funcionarios
UNION ALL SELECT 'status_voo', COUNT(*) FROM status_voo
UNION ALL SELECT 'categorias_tarifa', COUNT(*) FROM categorias_tarifa
UNION ALL SELECT 'tipos_bagagem', COUNT(*) FROM tipos_bagagem
UNION ALL SELECT 'fornecedores', COUNT(*) FROM fornecedores
UNION ALL SELECT 'terminais', COUNT(*) FROM terminais
UNION ALL SELECT 'aeroportos', COUNT(*) FROM aeroportos
UNION ALL SELECT 'aeronaves', COUNT(*) FROM aeronaves
UNION ALL SELECT 'passageiros', COUNT(*) FROM passageiros
UNION ALL SELECT 'funcionarios', COUNT(*) FROM funcionarios
UNION ALL SELECT 'voos', COUNT(*) FROM voos
UNION ALL SELECT 'escalas_tripulacao', COUNT(*) FROM escalas_tripulacao
UNION ALL SELECT 'reservas', COUNT(*) FROM reservas
UNION ALL SELECT 'passagens', COUNT(*) FROM passagens
UNION ALL SELECT 'bagagens', COUNT(*) FROM bagagens
UNION ALL SELECT 'cartoes_embarque', COUNT(*) FROM cartoes_embarque
ORDER BY tabela;

-- 2) Distribuicao de voos por status
SELECT sv.descricao, COUNT(*) AS total
FROM voos v
JOIN status_voo sv ON sv.id = v.status_id
GROUP BY sv.descricao
ORDER BY total DESC;

-- 3) Top 10 rotas mais frequentes
SELECT ao.codigo_iata AS origem, ad.codigo_iata AS destino, COUNT(*) AS voos
FROM voos v
JOIN aeroportos ao ON ao.id = v.aeroporto_origem_id
JOIN aeroportos ad ON ad.id = v.aeroporto_destino_id
GROUP BY ao.codigo_iata, ad.codigo_iata
ORDER BY voos DESC
LIMIT 10;

-- 4) Receita total por categoria de tarifa
SELECT ct.nome, COUNT(r.id) AS reservas, SUM(r.preco_total) AS receita_total
FROM reservas r
JOIN categorias_tarifa ct ON ct.id = r.categoria_tarifa_id
GROUP BY ct.nome
ORDER BY receita_total DESC
LIMIT 15;

-- 5) Distribuicao de passageiros por programa de fidelidade
SELECT programa_fidelidade, COUNT(*) AS total,
       ROUND(AVG(milhas_acumuladas)) AS milhas_media
FROM passageiros
GROUP BY programa_fidelidade
ORDER BY total DESC;

-- 6) Fornecedores ativos por tipo de servico
SELECT tipo_servico, COUNT(*) AS total
FROM fornecedores
WHERE ativo = TRUE
GROUP BY tipo_servico
ORDER BY total DESC;

-- 7) Distribuicao de bagagens por status
SELECT status, COUNT(*) AS total, ROUND(AVG(peso_kg), 2) AS peso_medio
FROM bagagens
GROUP BY status
ORDER BY total DESC;

-- 8) Funcionarios por cargo e aeroporto (top 10)
SELECT c.nome AS cargo, a.codigo_iata AS aeroporto,
       COUNT(f.id) AS funcionarios, ROUND(AVG(f.salario), 2) AS salario_medio
FROM funcionarios f
JOIN cargos_funcionarios c ON c.id = f.cargo_id
JOIN aeroportos a ON a.id = f.aeroporto_base_id
WHERE f.ativo = TRUE
GROUP BY c.nome, a.codigo_iata
ORDER BY funcionarios DESC
LIMIT 10;
