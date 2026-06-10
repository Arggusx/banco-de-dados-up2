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

### Q02: Receita total por categoria de voo e rota
* **Antes:** Uso de subquery correlacionada no `SELECT` atuava como um loop aninhado executado para cada linha retornada (problema N+1).
* **Otimização:** Reescrita para `JOIN` explícito com `GROUP BY` e índice composto em `reservas(voo_id, preco_pago, categoria_id)`.
* **Justificativa:** Transforma o plano de um laço repetitivo em um único `Hash Aggregate` linear, permitindo também uma varredura exclusiva de índice (`Index Only Scan`).

### Q03: Tripulação escalada para continentes específicos
* **Antes:** Filtros baseados em `OR` e uso de `DISTINCT` forçavam varreduras redundantes e uma ordenação pesada em memória para eliminação de duplicatas.
* **Otimização:** Uso de cláusula `WHERE EXISTS` com subquery interna e índice parcial em `paises(continente) WHERE continente IN ('EUROPA', 'ÁSIA')`.
* **Justificativa:** O `EXISTS` implementa um comportamento de curto-circuito (para a busca no primeiro match), eliminando a necessidade do nó de `Sort` gerado pelo `DISTINCT`.

### Q04: Peso total de bagagens por voo acima da média
* **Antes:** Subquery repetitiva dentro do `HAVING` recalculava a média global de bagagens para cada agrupamento de voo processado.
* **Otimização:** Uso de Expressões de Tabela Comuns (CTEs - `WITH`) e índice em `bagagens(passagem_id, peso)`.
* **Justificativa:** A média global é materializada em memória uma única vez. O otimizador substitui varreduras repetidas por um `Hash Join` direto entre a CTE e a tabela de voos.

### Q05: Cartões de embarque emitidos na madrugada
* **Antes:** Filtro `EXTRACT(HOUR FROM data_emissao) BETWEEN 0 AND 5` quebrava a sargabilidade (capacidade de usar índices) da coluna de timestamp.
* **Otimização:** Filtro convertido para ranges explícitos de data (`>=` e `<=`) e índice em `cartoes_embarque(data_emissao)`.
* **Justificativa:** Torna a consulta SARGable. O otimizador deixa de escanear a tabela inteira e executa um `Index Scan` por intervalo de forma direta.

### Q06: Fornecedores ativos de serviços de manutenção
* **Antes:** Filtro em coluna booleana (`status_ativo = true`) com baixa seletividade fazia o banco preferir `Seq Scan`.
* **Otimização:** Índice parcial `ON fornecedores (id) WHERE status_ativo = true`.
* **Justificativa:** Exclui fornecedores inativos da árvore do índice. A estrutura resultante é menor, exigindo menos páginas de disco para concluir a junção com a tabela de serviços.

### Q07: Histórico de reservas em meses de alta temporada
* **Antes:** O uso de `EXTRACT(MONTH FROM data_reserva)` impedia a leitura indexada dos períodos cronológicos.
* **Otimização:** Substituição da função por intervalos de data explícitos e índice em `reservas(data_reserva)`.
* **Justificativa:** Permite que o planejador de consultas utilize varreduras de intervalo indexadas (`Bitmap Index Scan`), mapeando as páginas físicas exatas dos meses desejados.

### Q08: Funcionários ativos sem escalas confirmadas
* **Antes:** Anti-pattern `NOT IN` comparava chaves e degradava a performance se houvesse valores nulos, forçando varreduras completas cruzadas.
* **Otimização:** Substituição por `NOT EXISTS` e índice parcial em `escalas(funcionario_id) WHERE status = 'CONFIRMADO'`.
* **Justificativa:** Permite ao PostgreSQL converter a operação em um `Hash Anti Join`, varrendo o índice compacto de escalas e descartando as linhas indesejadas de forma linear.

### Q09: Passageiros VIP com alta frequência de reservas
* **Antes:** Agrupamentos complexos aplicados sobre dados não filtrados geravam alto custo de CPU e paginação em disco.
* **Otimização:** Índices em `passageiros(programa_fidelidade_milhas)` e `reservas(passageiro_id)`.
* **Justificativa:** O banco reduz drasticamente o volume de dados que entra no agregador filtrando previamente os passageiros elegíveis antes de computar o `HAVING`.

### Q10: Ocupação média de aeronaves por modelo
* **Antes:** Junção direta N:M simultânea (`aeronaves -> voos -> reservas`) seguida de `COUNT(DISTINCT)` multiplicava as linhas na memória e inflava o custo.
* **Otimização:** CTE para isolar a pré-agregação de passageiros por voo suportada por índice em `voos(aeronave_id, id) WHERE status = 'CONCLUÍDO'`.
* **Justificativa:** Evita a explosão do produto cartesiano das tabelas. O cálculo de agregação passa a ocorrer sobre o conjunto reduzido gerado pelo índice parcial da CTE.

### Q11: Busca fonética ou parcial de passageiros pelo sobrenome
* **Antes:** Uso do operador `LIKE '%SILVA%'` com curinga inicial impossibilitava o uso de índices B-Tree tradicionais.
* **Otimização:** Utilização da extensão `pg_trgm` e índice GIN em `passageiros(nome gin_trgm_ops)`.
* **Justificativa:** O índice GIN quebra a string em trigramas (blocos de 3 caracteres). Isso permite que buscas por subsequências textuais ocorram via índice, eliminando o `Seq Scan`.

### Q12: Status de voos e escalas de pilotos específicos
* **Antes:** Junção tripla textual sem chaves de cobertura gerava loops aninhados custosos baseados em dados em texto bruto.
* **Otimização:** Índices compostos em `voos(status, id)` e `escalas(voo_id, funcionario_id)`.
* **Justificativa:** Permite que o otimizador adote estratégias eficientes de `Merge Join` ou `Hash Join`, resolvendo as junções diretamente pelas chaves ordenadas nos índices.

### Q13: Portões de Embarque mais utilizados por terminal
* **Antes:** Cruzamento desnecessário com as tabelas de `cartoes_embarque` e `passagens` para obter metadados que residiam puramente em `voos`.
* **Otimização:** Remoção das tabelas redundantes, uso de `GROUP BY` e índice composto em `voos(terminal_embarque, portao_embarque)`.
* **Justificativa:** Reduz o escopo da consulta a uma única tabela. O índice composto permite extrair os agrupamentos diretamente da estrutura do índice via `Index Only Scan`.

### Q14: Aeronaves que necessitam de revisão por horas de voo
* **Antes:** O filtro e a ordenação decrescente (`ORDER BY horas_voo_acumuladas DESC`) forçavam um nó de ordenação explícita na memória (`Top-N Sort`).
* **Otimização:** Índice composto ordenado `ON aeronaves (horas_voo_acumuladas DESC, matricula)`.
* **Justificativa:** Como o índice já armazena os dados fisicamente ordenados na ordem inversa, o PostgreSQL remove por completo a etapa de ordenação do plano de execução.

### Q15: Rotas mais frequentes partindo de hubs específicos
* **Antes:** Agrupamento e ordenação de rotas baseados em buscas sequenciais completas na tabela de rotas.
* **Otimização:** Índice em `rotas(aeroporto_origem_id, codigo_rota)`.
* **Justificativa:** Filtra imediatamente o escopo da busca para o hub pretendido, acelerando a etapa subsequente de agregação dos dados de voos associados.

### Q16: Cruzamento de passageiros com conexões na mesma data
* **Antes:** Self-join ineficiente que utilizava desigualdade pura (`v1.id <> v2.id`) acoplada a um casting de função `DATE()`. O banco cruzava a mesma combinação de linhas duas vezes (A com B e B com A).
* **Otimização:** Correção da lógica para `v1.id < v2.id`, tipagem via casting estável (`::date`) e índice em `voos(id, data_partida)`.
* **Justificativa:** Corta pela metade as combinações redundantes de linhas geradas no self-join e permite o uso do índice para verificar as datas de partida.

### Q17: Cancelamentos de voos por condições climáticas
* **Antes:** Varredura sequencial em toda a tabela de históricos buscando correspondências de texto com `LIKE` em todos os registros.
* **Otimização:** Índice parcial `ON historico_status (voo_id, justificativa) WHERE status_alterado = 'CANCELADO'`.
* **Justificativa:** Isola o escopo do índice apenas aos registros que de fato importam (cancelados). O banco varre uma estrutura reduzida para aplicar o filtro de texto.

### Q18: Relatório de conformidade de tripulação por jornada
* **Antes:** Filtros `EXTRACT(YEAR...)` e `EXTRACT(WEEK...)` em cima da coluna de data invalidavam qualquer índice de tempo comum.
* **Otimização:** Conversão dos parâmetros para intervalo fixo entre timestamps (`>=` e `<=`) e índice em `escalas(data_escala, funcionario_id)`.
* **Justificativa:** Restaura a sargabilidade da query, fazendo o motor executar um `Index Scan` por intervalo restrito às datas calculadas.

### Q19: Total gasto em passagens por categoria de cliente
* **Antes:** Pipeline de junções forçava o banco a acessar as páginas de dados da tabela de passageiros para buscar o nome e os critérios de milhagem.
* **Otimização:** Índice de cobertura `ON passageiros (programa_fidelidade_milhas) INCLUDE (id, nome)`.
* **Justificativa:** A cláusula `INCLUDE` armazena os dados do nome do passageiro diretamente no nó folha do índice. O PostgreSQL resolve a busca sem realizar acessos à tabela física (`Index Only Scan`).

### Q20: Auditoria de logs de acesso ao sistema de bilhetagem
* **Antes:** Varredura completa em tabelas massivas de logs temporais cruzando critérios de criticidade textual.
* **Otimização:** Índice parcial ordenado `ON logs_sistema (data_acao DESC) WHERE nivel_criticidade = 'CRÍTICO'`.
* **Justificativa:** Filtra os logs pela criticidade direto na estrutura e os mantém ordenados cronologicamente. O banco lê o topo do índice e interrompe a execução assim que atinge o limite do intervalo de 48 horas.
