# Aeroporto DB — Benchmarking e Otimização de Consultas

Este projeto consiste em um laboratório prático de engenharia de dados e tuning de performance no PostgreSQL. O objetivo principal é documentar, mensurar e justificar o impacto de otimizações de consultas (SQL Tuning) e indexação cirúrgica em um banco de dados de um aeroporto com mais de 60.000 registros.

## Recapitulação dos Erros Anteriores
As abordagens iniciais falharam em demonstrar ganho real de performance pelos seguintes motivos:
1. **Índices Globais Iniciais:** Os índices eram criados em bloco no início do script. Com isso, tanto a versão "Antes" quanto a "Depois" rodavam sob a mesma estrutura, gerando resultados idênticos no `EXPLAIN ANALYZE`.
2. **Abuso de `DISTINCT`:** Uso indiscriminado de operadores de distinção em operações de conjunto (`UNION`/`INTERSECT`) onde as chaves primárias ou lógicas já garantiam a unicidade, injetando operações pesadas de ordenação (`Sort`) na memória.
3. **Índices "Cegos" em FKs:** Criação automática de índices em Chaves Estrangeiras sem avaliar a seletividade. O PostgreSQL ignorava esses índices e preferia realizar Varreduras Sequenciais (`Seq Scan`) devido à baixa seletividade dos filtros empregados.

## Protocolo de Correção e Benchmarking
Para isolar as métricas e garantir uma comparação real de desempenho, cada consulta segue um protocolo rígido dentro de um bloco de transação isolado:
* **FASE 1 (Não Otimizada):** Executa o `DROP INDEX` (limpeza de resquícios), roda a query contendo *anti-patterns* e gera o plano via `EXPLAIN ANALYZE`.
* **FASE 2 (Otimizada):** Executa o `CREATE INDEX` específico para aquela busca, roda a query reescrita com alta performance e exibe o novo `EXPLAIN ANALYZE`.

---

## Catálogo e Justificativa das 20 Operações de Consulta

### Q01: Busca de passageiro por e-mail
* **Antes:** Filtro `WHERE lower(email) = '...'` forçava um `Seq Scan` em toda a tabela para aplicar a função em cada linha.
* **Otimização:** Criação de índice funcional `ON passageiros (lower(email))`.
* **Justificativa:** O PostgreSQL pré-calcula os valores em caixa baixa na estrutura do índice. O plano muda para `Index Scan`, reduzindo a complexidade de tempo de O(N) para O(log N).

### Q04: Peso total de bagagens por voo acima da média
* **Antes:** Subquery repetitiva dentro do `HAVING` recalculava a média global de bagagens para cada agrupamento de voo processado.
* **Otimização:** Uso de Expressões de Tabela Comuns (CTEs - `WITH`) e índice em `bagagens(passagem_id, peso)`.
* **Justificativa:** A média global é materializada em memória uma única vez. O otimizador substitui varreduras repetidas por um `Hash Join` direto entre a CTE e a tabela de voos.

### Q05: Cartões de embarque emitidos na madrugada
* **Antes:** Filtro `EXTRACT(HOUR FROM data_emissao) BETWEEN 0 AND 5` quebrava a sargabilidade (capacidade de usar índices) da coluna de timestamp.
* **Otimização:** Filtro convertido para ranges explícitos de data (`>=` e `<=`) e índice em `cartoes_embarque(data_emissao)`.
* **Justificativa:** Torna a consulta SARGable. O otimizador deixa de escanear a tabela inteira e executa um `Index Scan` por intervalo de forma direta.

# Modelo Lógico

<img width="3760" height="4366" alt="modelo-logico-up2" src="https://github.com/user-attachments/assets/ab4ec2af-46f1-4c54-a90d-d92a8e2c75dd" />

# Modelo Conceitual

<img width="1632" height="1509" alt="modelo-conceitual-up2" src="https://github.com/user-attachments/assets/f9e785d7-d405-4c97-9872-b5f86497ff52" />
