# Relatório de Benchmarking e Otimização de Performance

Este relatório apresenta os resultados de benchmarking para 20 operações de consulta complexas no sistema aeroportuário.

## Sumário das Otimizações
| ID | Operação | Custo Antes | Custo Depois | Redução (%) | Tempo Antes | Tempo Depois | Ganho Tempo |
|---|---|---|---|---|---|---|---|

| 1 | Passageiros com voos para um país específico | `159.43..305.97` | `60.30..206.85` | **32.4%** | `2.587 ms` | `0.155 ms` | **Foco em Otimização** |
| 2 | Receita total de passagens por rota aérea e categoria de tarifa | `307.60..44673.38` | `733.31..766.50` | **98.28%** | `12.250 ms` | `9.752 ms` | **Foco em Otimização** |
| 3 | Tripulação escalada para voos internacionais com origem em países específicos | `45.93..46.05` | `5.70..45.76` | **0.63%** | `0.120 ms` | `0.085 ms` | **Foco em Otimização** |
| 4 | Peso total de bagagens despachadas por voo | `0.00..142823.50` | `644.91..707.41` | **99.5%** | `52.546 ms` | `12.704 ms` | **Foco em Otimização** |
| 5 | Cartões de embarque com detalhes de voo e terminal | `549.80..675.44` | `549.80..675.44` | **0.0%** | `4.878 ms` | `3.746 ms` | **Foco em Otimização** |
| 6 | Fornecedores por país com serviços de catering | `64.51..64.75` | `64.51..64.75` | **0.0%** | `0.597 ms` | `0.480 ms` | **Foco em Otimização** |
| 7 | Reservas por voo realizadas em determinado mês | `171.46..171.48` | `349.71..350.59` | **-104.45%** | `1.953 ms` | `1.356 ms` | **Foco em Otimização** |
| 8 | Funcionários ativos sem escalas de voo atribuídas | `329.50..484.50` | `394.03..561.35` | **-15.86%** | `4.393 ms` | `5.150 ms` | **Foco em Otimização** |
| 9 | Passageiros com muitas milhas e mais de uma reserva | `910.46..985.46` | `718.27..780.15` | **20.83%** | `13.116 ms` | `10.140 ms` | **Foco em Otimização** |
| 10 | Ocupação média por modelo de aeronave e fabricante | `679.19..56506.69` | `654.45..698.17` | **98.76%** | `48.455 ms` | `9.684 ms` | **Foco em Otimização** |
| 11 | Histórico de passagens compradas por um passageiro | `172.67..181.58` | `59.75..190.13` | **-4.71%** | `0.077 ms` | `0.064 ms` | **Foco em Otimização** |
| 12 | Voos atrasados ou cancelados e impacto nos tripulantes | `13.45..61.34` | `13.45..61.34` | **0.0%** | `0.265 ms` | `0.146 ms` | **Foco em Otimização** |
| 13 | Receita por terminal e gate | `540.95..603.45` | `540.95..603.45` | **0.0%** | `10.754 ms` | `10.169 ms` | **Foco em Otimização** |
| 14 | Aeronaves com maior utilização por quilometragem | `804.19..816.69` | `614.22..622.01` | **23.84%** | `9.333 ms` | `6.192 ms` | **Foco em Otimização** |
| 15 | Conexões possíveis entre voos no mesmo terminal com intervalo curto | `199.31..470.15` | `199.31..469.78` | **0.08%** | `2.106 ms` | `2.162 ms` | **Foco em Otimização** |
| 16 | Passageiros de voos de longa distância que não despacharam bagagem | `157.35..267.73` | `584.91..744.23` | **-177.98%** | `11.014 ms` | `5.489 ms` | **Foco em Otimização** |
| 17 | Ranking de rotas mais lucrativas por país de destino | `1367.52..1380.02` | `1042.67..1050.51` | **23.88%** | `15.376 ms` | `11.848 ms` | **Foco em Otimização** |
| 18 | Número de escalas por funcionário, cargo e aeroporto base | `776.59..826.59` | `444.08..603.75` | **26.96%** | `12.391 ms` | `7.010 ms` | **Foco em Otimização** |
| 19 | Embarques realizados agrupados por terminal e mês | `158.21..158.77` | `184.51..211.24` | **-33.05%** | `8.547 ms` | `1.920 ms` | **Foco em Otimização** |
| 20 | Dashboard executivo consolidado (Faturamento, Total de Bagagens) de voos caros | `1056.71..1140.43` | `986.11..1077.67` | **5.5%** | `12.901 ms` | `12.180 ms` | **Foco em Otimização** |

## Detalhes das Operações


### Query 1: Passageiros com voos para um país específico
* **Tabelas:** passageiros, reservas, voos, aeroportos, cidades, paises
* **Antipadrão:** SELECT * + Função LOWER no WHERE que desabilita índice funcional se não criado
* **Estratégia:** Selecionar apenas colunas necessárias, usar o índice funcional LOWER(email) idx_passageiros_email_lower.

#### Comparação de Custo e Tempo
* **Custo Antes:** `159.43..305.97` | **Custo Depois:** `60.30..206.85` (**32.4% de redução**)
* **Tempo Antes:** `2.587 ms` | **Tempo Depois:** `0.155 ms`

#### Plano Antes:
```text
Nested Loop  (cost=159.43..305.97 rows=25 width=359) (actual time=2.404..2.407 rows=0.00 loops=1)
  Buffers: shared hit=85
  ->  Nested Loop  (cost=159.15..297.16 rows=25 width=313) (actual time=2.404..2.406 rows=0.00 loops=1)
        Buffers: shared hit=85
        ->  Nested Loop  (cost=158.88..289.53 rows=25 width=264) (actual time=2.404..2.406 rows=0.00 loops=1)
              Buffers: shared hit=85
              ->  Nested Loop  (cost=158.59..280.31 rows=25 width=189) (actual time=2.403..2.405 rows=0.00 loops=1)
                    Buffers: shared hit=85
                    ->  Hash Join  (cost=158.31..271.45 rows=25 width=141) (actual time=2.403..2.405 rows=0.00 loops=1)
                          Hash Cond: (r.passageiro_id = p.id)
                          Buffers: shared hit=85
                          ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=46) (actual time=0.017..0.017 rows=1.00 loops=1)
                                Buffers: shared hit=2
                          ->  Hash  (cost=158.00..158.00 rows=25 width=95) (actual time=2.377..2.377 rows=0.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                Buffers: shared hit=83
                                ->  Seq Scan on passageiros p  (cost=0.00..158.00 rows=25 width=95) (actual time=2.376..2.377 rows=0.00 loops=1)
                                      Filter: (lower((email)::text) = 'ana.souza.1@example.com'::text)
                                      Rows Removed by Filter: 5000
                                      Buffers: shared hit=83
                    ->  Index Scan using voos_pkey on voos v  (cost=0.28..0.35 rows=1 width=48) (never executed)
                          Index Cond: (id = r.voo_id)
                          Index Searches: 0
              ->  Index Scan using aeroportos_pkey on aeroportos a  (cost=0.28..0.37 rows=1 width=75) (never executed)
                    Index Cond: (id = v.aeroporto_destino_id)
                    Index Searches: 0
        ->  Index Scan using cidades_pkey on cidades c  (cost=0.28..0.31 rows=1 width=49) (never executed)
              Index Cond: (id = a.cidade_id)
              Index Searches: 0
  ->  Index Scan using paises_pkey on paises pa  (cost=0.28..0.35 rows=1 width=46) (never executed)
        Index Cond: (id = c.pais_id)
        Index Searches: 0
Planning:
  Buffers: shared hit=712
Planning Time: 13.351 ms
Execution Time: 2.587 ms
```

#### Plano Depois:
```text
Nested Loop  (cost=60.30..206.85 rows=25 width=82) (actual time=0.097..0.101 rows=0.00 loops=1)
  Buffers: shared hit=2 read=2
  ->  Nested Loop  (cost=60.02..198.03 rows=25 width=60) (actual time=0.097..0.100 rows=0.00 loops=1)
        Buffers: shared hit=2 read=2
        ->  Nested Loop  (cost=59.75..190.40 rows=25 width=60) (actual time=0.097..0.100 rows=0.00 loops=1)
              Buffers: shared hit=2 read=2
              ->  Nested Loop  (cost=59.47..181.18 rows=25 width=60) (actual time=0.097..0.100 rows=0.00 loops=1)
                    Buffers: shared hit=2 read=2
                    ->  Hash Join  (cost=59.18..172.32 rows=25 width=54) (actual time=0.097..0.100 rows=0.00 loops=1)
                          Hash Cond: (r.passageiro_id = p.id)
                          Buffers: shared hit=2 read=2
                          ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=8) (actual time=0.012..0.013 rows=1.00 loops=1)
                                Buffers: shared hit=2
                          ->  Hash  (cost=58.87..58.87 rows=25 width=50) (actual time=0.073..0.075 rows=0.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                Buffers: shared read=2
                                ->  Bitmap Heap Scan on passageiros p  (cost=4.48..58.87 rows=25 width=50) (actual time=0.073..0.073 rows=0.00 loops=1)
                                      Recheck Cond: (lower((email)::text) = 'ana.souza.1@example.com'::text)
                                      Buffers: shared read=2
                                      ->  Bitmap Index Scan on idx_passageiros_email_lower  (cost=0.00..4.47 rows=25 width=0) (actual time=0.061..0.061 rows=0.00 loops=1)
                                            Index Cond: (lower((email)::text) = 'ana.souza.1@example.com'::text)
                                            Index Searches: 1
                                            Buffers: shared read=2
                    ->  Index Scan using voos_pkey on voos v  (cost=0.28..0.35 rows=1 width=14) (never executed)
                          Index Cond: (id = r.voo_id)
                          Index Searches: 0
              ->  Index Scan using aeroportos_pkey on aeroportos a  (cost=0.28..0.37 rows=1 width=8) (never executed)
                    Index Cond: (id = v.aeroporto_destino_id)
                    Index Searches: 0
        ->  Index Scan using cidades_pkey on cidades c  (cost=0.28..0.31 rows=1 width=8) (never executed)
              Index Cond: (id = a.cidade_id)
              Index Searches: 0
  ->  Index Scan using paises_pkey on paises pa  (cost=0.28..0.35 rows=1 width=30) (never executed)
        Index Cond: (id = c.pais_id)
        Index Searches: 0
Planning:
  Buffers: shared hit=116 read=20
Planning Time: 8.287 ms
Execution Time: 0.155 ms
```

---


### Query 2: Receita total de passagens por rota aérea e categoria de tarifa
* **Tabelas:** voos, reservas, categorias_tarifa, aeroportos
* **Antipadrão:** Subquery com IN e subqueries correlacionadas no SELECT
* **Estratégia:** Reescrever subqueries correlacionadas e IN como JOINs diretos, usando covering index.

#### Comparação de Custo e Tempo
* **Custo Antes:** `307.60..44673.38` | **Custo Depois:** `733.31..766.50` (**98.28% de redução**)
* **Tempo Antes:** `12.250 ms` | **Tempo Depois:** `9.752 ms`

#### Plano Antes:
```text
GroupAggregate  (cost=307.60..44673.38 rows=2655 width=82) (actual time=1.919..11.984 rows=2073.00 loops=1)
  Group Key: v.id
  Buffers: shared hit=12579
  ->  Merge Join  (cost=307.60..553.92 rows=2655 width=24) (actual time=1.872..3.850 rows=2698.00 loops=1)
        Merge Cond: (v.id = r.voo_id)
        Buffers: shared hit=141
        ->  Index Scan using voos_pkey on voos v  (cost=0.28..194.28 rows=5000 width=18) (actual time=0.011..0.775 rows=5000.00 loops=1)
              Index Searches: 1
              Buffers: shared hit=67
        ->  Sort  (cost=307.31..313.95 rows=2655 width=10) (actual time=1.857..2.059 rows=2698.00 loops=1)
              Sort Key: r.voo_id
              Sort Method: quicksort  Memory: 181kB
              Buffers: shared hit=74
              ->  Hash Join  (cost=43.14..156.32 rows=2655 width=10) (actual time=0.310..1.260 rows=2698.00 loops=1)
                    Hash Cond: (r.categoria_tarifa_id = categorias_tarifa.id)
                    Buffers: shared hit=74
                    ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=14) (actual time=0.014..0.217 rows=5000.00 loops=1)
                          Buffers: shared hit=50
                    ->  Hash  (cost=36.50..36.50 rows=531 width=4) (actual time=0.284..0.285 rows=531.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 27kB
                          Buffers: shared hit=24
                          ->  Seq Scan on categorias_tarifa  (cost=0.00..36.50 rows=531 width=4) (actual time=0.012..0.220 rows=531.00 loops=1)
                                Filter: (multiplicador_preco > 1.2)
                                Rows Removed by Filter: 469
                                Buffers: shared hit=24
  SubPlan 1
    ->  Index Scan using aeroportos_pkey on aeroportos a  (cost=0.28..8.30 rows=1 width=4) (actual time=0.001..0.001 rows=1.00 loops=2073)
          Index Cond: (id = v.aeroporto_origem_id)
          Index Searches: 2073
          Buffers: shared hit=6219
  SubPlan 2
    ->  Index Scan using aeroportos_pkey on aeroportos a_1  (cost=0.28..8.30 rows=1 width=4) (actual time=0.001..0.001 rows=1.00 loops=2073)
          Index Cond: (id = v.aeroporto_destino_id)
          Index Searches: 2073
          Buffers: shared hit=6219
Planning:
  Buffers: shared hit=79
Planning Time: 1.758 ms
Execution Time: 12.250 ms
```

#### Plano Depois:
```text
HashAggregate  (cost=733.31..766.50 rows=2655 width=46) (actual time=8.821..9.372 rows=2073.00 loops=1)
  Group Key: v.numero_voo, ao.codigo_iata, ad.codigo_iata
  Batches: 1  Memory Usage: 977kB
  Buffers: shared hit=266
  ->  Hash Join  (cost=572.64..706.76 rows=2655 width=20) (actual time=3.923..7.377 rows=2698.00 loops=1)
        Hash Cond: (v.aeroporto_destino_id = ad.id)
        Buffers: shared hit=266
        ->  Hash Join  (cost=390.14..517.28 rows=2655 width=20) (actual time=2.750..5.511 rows=2698.00 loops=1)
              Hash Cond: (v.aeroporto_origem_id = ao.id)
              Buffers: shared hit=196
              ->  Hash Join  (cost=207.64..327.80 rows=2655 width=20) (actual time=1.504..3.519 rows=2698.00 loops=1)
                    Hash Cond: (r.voo_id = v.id)
                    Buffers: shared hit=126
                    ->  Hash Join  (cost=43.14..156.32 rows=2655 width=10) (actual time=0.257..1.449 rows=2698.00 loops=1)
                          Hash Cond: (r.categoria_tarifa_id = ct.id)
                          Buffers: shared hit=74
                          ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=14) (actual time=0.018..0.305 rows=5000.00 loops=1)
                                Buffers: shared hit=50
                          ->  Hash  (cost=36.50..36.50 rows=531 width=4) (actual time=0.229..0.230 rows=531.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 27kB
                                Buffers: shared hit=24
                                ->  Seq Scan on categorias_tarifa ct  (cost=0.00..36.50 rows=531 width=4) (actual time=0.012..0.165 rows=531.00 loops=1)
                                      Filter: (multiplicador_preco > 1.2)
                                      Rows Removed by Filter: 469
                                      Buffers: shared hit=24
                    ->  Hash  (cost=102.00..102.00 rows=5000 width=18) (actual time=1.213..1.215 rows=5000.00 loops=1)
                          Buckets: 8192  Batches: 1  Memory Usage: 318kB
                          Buffers: shared hit=52
                          ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=18) (actual time=0.009..0.499 rows=5000.00 loops=1)
                                Buffers: shared hit=52
              ->  Hash  (cost=120.00..120.00 rows=5000 width=8) (actual time=1.213..1.213 rows=5000.00 loops=1)
                    Buckets: 8192  Batches: 1  Memory Usage: 260kB
                    Buffers: shared hit=70
                    ->  Seq Scan on aeroportos ao  (cost=0.00..120.00 rows=5000 width=8) (actual time=0.006..0.511 rows=5000.00 loops=1)
                          Buffers: shared hit=70
        ->  Hash  (cost=120.00..120.00 rows=5000 width=8) (actual time=1.135..1.135 rows=5000.00 loops=1)
              Buckets: 8192  Batches: 1  Memory Usage: 260kB
              Buffers: shared hit=70
              ->  Seq Scan on aeroportos ad  (cost=0.00..120.00 rows=5000 width=8) (actual time=0.013..0.453 rows=5000.00 loops=1)
                    Buffers: shared hit=70
Planning:
  Buffers: shared hit=54 read=3
Planning Time: 0.821 ms
Execution Time: 9.752 ms
```

---


### Query 3: Tripulação escalada para voos internacionais com origem em países específicos
* **Tabelas:** funcionarios, escalas_tripulacao, voos, aeroportos, cidades, paises
* **Antipadrão:** Uso de DISTINCT abusivo + operador OR complexo no WHERE
* **Estratégia:** Remover DISTINCT redundante (escala garante unicidade por voo/funcionário), reescrever OR como IN.

#### Comparação de Custo e Tempo
* **Custo Antes:** `45.93..46.05` | **Custo Depois:** `5.70..45.76` (**0.63% de redução**)
* **Tempo Antes:** `0.120 ms` | **Tempo Depois:** `0.085 ms`

#### Plano Antes:
```text
Unique  (cost=45.93..46.05 rows=10 width=62) (actual time=0.070..0.071 rows=0.00 loops=1)
  Buffers: shared hit=9
  ->  Sort  (cost=45.93..45.95 rows=10 width=62) (actual time=0.070..0.071 rows=0.00 loops=1)
        Sort Key: f.nome, f.sobrenome, f.email, v.numero_voo
        Sort Method: quicksort  Memory: 25kB
        Buffers: shared hit=9
        ->  Nested Loop  (cost=5.70..45.76 rows=10 width=62) (actual time=0.060..0.061 rows=0.00 loops=1)
              Buffers: shared hit=9
              ->  Nested Loop  (cost=5.41..41.99 rows=10 width=10) (actual time=0.060..0.061 rows=0.00 loops=1)
                    Buffers: shared hit=9
                    ->  Nested Loop  (cost=5.13..38.13 rows=10 width=10) (actual time=0.060..0.061 rows=0.00 loops=1)
                          Buffers: shared hit=9
                          ->  Nested Loop  (cost=4.85..34.19 rows=10 width=4) (actual time=0.060..0.060 rows=0.00 loops=1)
                                Buffers: shared hit=9
                                ->  Nested Loop  (cost=4.57..32.70 rows=2 width=4) (actual time=0.060..0.060 rows=0.00 loops=1)
                                      Buffers: shared hit=9
                                      ->  Index Scan using paises_codigo_iso2_key on paises po  (cost=0.28..13.14 rows=2 width=4) (actual time=0.027..0.036 rows=2.00 loops=1)
                                            Index Cond: (codigo_iso2 = ANY ('{BR,PT}'::bpchar[]))
                                            Index Searches: 2
                                            Buffers: shared hit=5
                                      ->  Bitmap Heap Scan on cidades co  (cost=4.29..9.76 rows=2 width=8) (actual time=0.009..0.009 rows=0.00 loops=2)
                                            Recheck Cond: (pais_id = po.id)
                                            Buffers: shared hit=4
                                            ->  Bitmap Index Scan on idx_cidades_pais_id  (cost=0.00..4.29 rows=2 width=0) (actual time=0.002..0.002 rows=0.00 loops=2)
                                                  Index Cond: (pais_id = po.id)
                                                  Index Searches: 2
                                                  Buffers: shared hit=4
                                ->  Index Scan using idx_aeroportos_cidade_id on aeroportos ao  (cost=0.28..0.69 rows=5 width=8) (never executed)
                                      Index Cond: (cidade_id = co.id)
                                      Index Searches: 0
                          ->  Index Scan using idx_voos_aeroporto_origem_id on voos v  (cost=0.28..0.37 rows=2 width=14) (never executed)
                                Index Cond: (aeroporto_origem_id = ao.id)
                                Index Searches: 0
                    ->  Index Scan using idx_escalas_voo_id on escalas_tripulacao et  (cost=0.28..0.37 rows=2 width=8) (never executed)
                          Index Cond: (voo_id = v.id)
                          Index Searches: 0
              ->  Index Scan using funcionarios_pkey on funcionarios f  (cost=0.28..0.38 rows=1 width=60) (never executed)
                    Index Cond: (id = et.funcionario_id)
                    Index Searches: 0
Planning:
  Buffers: shared hit=236 read=7
Planning Time: 6.442 ms
Execution Time: 0.120 ms
```

#### Plano Depois:
```text
Nested Loop  (cost=5.70..45.76 rows=10 width=62) (actual time=0.043..0.043 rows=0.00 loops=1)
  Buffers: shared hit=9
  ->  Nested Loop  (cost=5.41..41.99 rows=10 width=10) (actual time=0.042..0.043 rows=0.00 loops=1)
        Buffers: shared hit=9
        ->  Nested Loop  (cost=5.13..38.13 rows=10 width=10) (actual time=0.042..0.043 rows=0.00 loops=1)
              Buffers: shared hit=9
              ->  Nested Loop  (cost=4.85..34.19 rows=10 width=4) (actual time=0.042..0.043 rows=0.00 loops=1)
                    Buffers: shared hit=9
                    ->  Nested Loop  (cost=4.57..32.70 rows=2 width=4) (actual time=0.042..0.042 rows=0.00 loops=1)
                          Buffers: shared hit=9
                          ->  Index Scan using paises_codigo_iso2_key on paises po  (cost=0.28..13.14 rows=2 width=4) (actual time=0.018..0.024 rows=2.00 loops=1)
                                Index Cond: (codigo_iso2 = ANY ('{BR,PT}'::bpchar[]))
                                Index Searches: 2
                                Buffers: shared hit=5
                          ->  Bitmap Heap Scan on cidades co  (cost=4.29..9.76 rows=2 width=8) (actual time=0.007..0.007 rows=0.00 loops=2)
                                Recheck Cond: (pais_id = po.id)
                                Buffers: shared hit=4
                                ->  Bitmap Index Scan on idx_cidades_pais_id  (cost=0.00..4.29 rows=2 width=0) (actual time=0.001..0.002 rows=0.00 loops=2)
                                      Index Cond: (pais_id = po.id)
                                      Index Searches: 2
                                      Buffers: shared hit=4
                    ->  Index Scan using idx_aeroportos_cidade_id on aeroportos ao  (cost=0.28..0.69 rows=5 width=8) (never executed)
                          Index Cond: (cidade_id = co.id)
                          Index Searches: 0
              ->  Index Scan using idx_voos_aeroporto_origem_id on voos v  (cost=0.28..0.37 rows=2 width=14) (never executed)
                    Index Cond: (aeroporto_origem_id = ao.id)
                    Index Searches: 0
        ->  Index Scan using idx_escalas_voo_id on escalas_tripulacao et  (cost=0.28..0.37 rows=2 width=8) (never executed)
              Index Cond: (voo_id = v.id)
              Index Searches: 0
  ->  Index Scan using funcionarios_pkey on funcionarios f  (cost=0.28..0.38 rows=1 width=60) (never executed)
        Index Cond: (id = et.funcionario_id)
        Index Searches: 0
Planning:
  Buffers: shared hit=60
Planning Time: 0.860 ms
Execution Time: 0.085 ms
```

---


### Query 4: Peso total de bagagens despachadas por voo
* **Tabelas:** bagagens, passagens, reservas, voos, tipos_bagagem
* **Antipadrão:** Subquery correlacionada no SELECT (problema N+1)
* **Estratégia:** Substituir subquery correlacionada por LEFT JOINs explícitos e GROUP BY, usando índice parcial de bagagens.

#### Comparação de Custo e Tempo
* **Custo Antes:** `0.00..142823.50` | **Custo Depois:** `644.91..707.41` (**99.5% de redução**)
* **Tempo Antes:** `52.546 ms` | **Tempo Depois:** `12.704 ms`

#### Plano Antes:
```text
Seq Scan on voos v  (cost=0.00..142823.50 rows=5000 width=42) (actual time=0.053..52.118 rows=5000.00 loops=1)
  Buffers: shared hit=44932 read=29
  SubPlan 1
    ->  Aggregate  (cost=28.53..28.54 rows=1 width=32) (actual time=0.010..0.010 rows=1.00 loops=5000)
          Buffers: shared hit=44880 read=29
          ->  Nested Loop  (cost=4.86..28.53 rows=2 width=6) (actual time=0.008..0.009 rows=1.00 loops=5000)
                Buffers: shared hit=44880 read=29
                ->  Nested Loop  (cost=4.58..27.74 rows=2 width=4) (actual time=0.006..0.007 rows=1.00 loops=5000)
                      Buffers: shared hit=29931 read=29
                      ->  Bitmap Heap Scan on reservas r  (cost=4.30..11.12 rows=2 width=4) (actual time=0.002..0.002 rows=1.00 loops=5000)
                            Recheck Cond: (voo_id = v.id)
                            Heap Blocks: exact=4948
                            Buffers: shared hit=14931 read=29
                            ->  Bitmap Index Scan on idx_reservas_voo_covering  (cost=0.00..4.30 rows=2 width=0) (actual time=0.001..0.001 rows=1.00 loops=5000)
                                  Index Cond: (voo_id = v.id)
                                  Index Searches: 5000
                                  Buffers: shared hit=9983 read=29
                      ->  Index Scan using idx_passagens_reserva_id on passagens p  (cost=0.28..8.30 rows=1 width=8) (actual time=0.001..0.001 rows=1.00 loops=5000)
                            Index Cond: (reserva_id = r.id)
                            Index Searches: 5000
                            Buffers: shared hit=15000
                ->  Index Scan using idx_bagagens_passagem_id on bagagens b  (cost=0.28..0.37 rows=2 width=10) (actual time=0.001..0.001 rows=1.00 loops=5000)
                      Index Cond: (passagem_id = p.id)
                      Index Searches: 5000
                      Buffers: shared hit=14949
Planning:
  Buffers: shared hit=147 read=1
Planning Time: 4.720 ms
Execution Time: 52.546 ms
```

#### Plano Depois:
```text
HashAggregate  (cost=644.91..707.41 rows=5000 width=42) (actual time=10.968..12.190 rows=5000.00 loops=1)
  Group Key: v.id
  Batches: 1  Memory Usage: 1937kB
  Buffers: shared hit=193
  ->  Hash Right Join  (cost=483.50..619.91 rows=5000 width=16) (actual time=3.068..8.302 rows=8687.00 loops=1)
        Hash Cond: (r.voo_id = v.id)
        Buffers: shared hit=193
        ->  Hash Right Join  (cost=319.00..442.27 rows=5000 width=10) (actual time=2.013..5.443 rows=6825.00 loops=1)
              Hash Cond: (p.reserva_id = r.id)
              Buffers: shared hit=141
              ->  Hash Right Join  (cost=156.50..266.64 rows=5000 width=10) (actual time=1.019..2.961 rows=6825.00 loops=1)
                    Hash Cond: (b.passagem_id = p.id)
                    Buffers: shared hit=91
                    ->  Seq Scan on bagagens b  (cost=0.00..97.00 rows=5000 width=10) (actual time=0.014..0.300 rows=5000.00 loops=1)
                          Buffers: shared hit=47
                    ->  Hash  (cost=94.00..94.00 rows=5000 width=8) (actual time=0.966..0.966 rows=5000.00 loops=1)
                          Buckets: 8192  Batches: 1  Memory Usage: 260kB
                          Buffers: shared hit=44
                          ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=8) (actual time=0.009..0.428 rows=5000.00 loops=1)
                                Buffers: shared hit=44
              ->  Hash  (cost=100.00..100.00 rows=5000 width=8) (actual time=0.958..0.958 rows=5000.00 loops=1)
                    Buckets: 8192  Batches: 1  Memory Usage: 260kB
                    Buffers: shared hit=50
                    ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=8) (actual time=0.009..0.441 rows=5000.00 loops=1)
                          Buffers: shared hit=50
        ->  Hash  (cost=102.00..102.00 rows=5000 width=10) (actual time=1.049..1.049 rows=5000.00 loops=1)
              Buckets: 8192  Batches: 1  Memory Usage: 274kB
              Buffers: shared hit=52
              ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=10) (actual time=0.010..0.441 rows=5000.00 loops=1)
                    Buffers: shared hit=52
Planning:
  Buffers: shared hit=48
Planning Time: 0.540 ms
Execution Time: 12.704 ms
```

---


### Query 5: Cartões de embarque com detalhes de voo e terminal
* **Tabelas:** cartoes_embarque, passagens, reservas, voos, passageiros, terminais
* **Antipadrão:** SELECT * + joins implícitos (sintaxe antiga ANSI-89 baseada em vírgula)
* **Estratégia:** Usar sintaxe de JOIN explícita (ANSI-92) e selecionar apenas colunas necessárias.

#### Comparação de Custo e Tempo
* **Custo Antes:** `549.80..675.44` | **Custo Depois:** `549.80..675.44` (**0.0% de redução**)
* **Tempo Antes:** `4.878 ms` | **Tempo Depois:** `3.746 ms`

#### Plano Antes:
```text
Hash Join  (cost=549.80..675.44 rows=388 width=303) (actual time=3.814..4.695 rows=383.00 loops=1)
  Hash Cond: (ce.terminal_id = t.id)
  Buffers: shared hit=289
  ->  Hash Join  (cost=519.30..643.93 rows=388 width=275) (actual time=3.621..4.355 rows=383.00 loops=1)
        Hash Cond: (v.id = r.voo_id)
        Buffers: shared hit=281
        ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=48) (actual time=0.008..0.206 rows=5000.00 loops=1)
              Buffers: shared hit=52
        ->  Hash  (cost=514.45..514.45 rows=388 width=227) (actual time=3.599..3.602 rows=383.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 114kB
              Buffers: shared hit=229
              ->  Hash Join  (cost=389.82..514.45 rows=388 width=227) (actual time=2.440..3.354 rows=383.00 loops=1)
                    Hash Cond: (ce.passagem_id = p.id)
                    Buffers: shared hit=229
                    ->  Seq Scan on cartoes_embarque ce  (cost=0.00..102.00 rows=5000 width=46) (actual time=0.007..0.304 rows=5000.00 loops=1)
                          Buffers: shared hit=52
                    ->  Hash  (cost=384.97..384.97 rows=388 width=181) (actual time=2.407..2.409 rows=383.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 93kB
                          Buffers: shared hit=177
                          ->  Hash Join  (cost=268.34..384.97 rows=388 width=181) (actual time=1.429..2.200 rows=383.00 loops=1)
                                Hash Cond: (p.reserva_id = r.id)
                                Buffers: shared hit=177
                                ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=40) (actual time=0.008..0.230 rows=5000.00 loops=1)
                                      Buffers: shared hit=44
                                ->  Hash  (cost=263.49..263.49 rows=388 width=141) (actual time=1.406..1.408 rows=383.00 loops=1)
                                      Buckets: 1024  Batches: 1  Memory Usage: 77kB
                                      Buffers: shared hit=133
                                      ->  Hash Join  (cost=150.35..263.49 rows=388 width=141) (actual time=0.561..1.248 rows=383.00 loops=1)
                                            Hash Cond: (r.passageiro_id = pas.id)
                                            Buffers: shared hit=133
                                            ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=46) (actual time=0.007..0.231 rows=5000.00 loops=1)
                                                  Buffers: shared hit=50
                                            ->  Hash  (cost=145.50..145.50 rows=388 width=95) (actual time=0.538..0.538 rows=388.00 loops=1)
                                                  Buckets: 1024  Batches: 1  Memory Usage: 59kB
                                                  Buffers: shared hit=83
                                                  ->  Seq Scan on passageiros pas  (cost=0.00..145.50 rows=388 width=95) (actual time=0.010..0.473 rows=388.00 loops=1)
                                                        Filter: ((programa_fidelidade)::text = 'SMILES'::text)
                                                        Rows Removed by Filter: 4612
                                                        Buffers: shared hit=83
  ->  Hash  (cost=18.00..18.00 rows=1000 width=28) (actual time=0.189..0.189 rows=1000.00 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 68kB
        Buffers: shared hit=8
        ->  Seq Scan on terminais t  (cost=0.00..18.00 rows=1000 width=28) (actual time=0.015..0.082 rows=1000.00 loops=1)
              Buffers: shared hit=8
Planning:
  Buffers: shared hit=236
Planning Time: 5.080 ms
Execution Time: 4.878 ms
```

#### Plano Depois:
```text
Hash Join  (cost=549.80..675.44 rows=388 width=34) (actual time=3.003..3.692 rows=383.00 loops=1)
  Hash Cond: (ce.terminal_id = t.id)
  Buffers: shared hit=289
  ->  Hash Join  (cost=519.30..643.93 rows=388 width=32) (actual time=2.754..3.363 rows=383.00 loops=1)
        Hash Cond: (v.id = r.voo_id)
        Buffers: shared hit=281
        ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=10) (actual time=0.009..0.218 rows=5000.00 loops=1)
              Buffers: shared hit=52
        ->  Hash  (cost=514.45..514.45 rows=388 width=30) (actual time=2.739..2.741 rows=383.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 33kB
              Buffers: shared hit=229
              ->  Hash Join  (cost=389.82..514.45 rows=388 width=30) (actual time=2.015..2.648 rows=383.00 loops=1)
                    Hash Cond: (ce.passagem_id = p.id)
                    Buffers: shared hit=229
                    ->  Seq Scan on cartoes_embarque ce  (cost=0.00..102.00 rows=5000 width=15) (actual time=0.007..0.204 rows=5000.00 loops=1)
                          Buffers: shared hit=52
                    ->  Hash  (cost=384.97..384.97 rows=388 width=23) (actual time=2.002..2.004 rows=383.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 30kB
                          Buffers: shared hit=177
                          ->  Hash Join  (cost=268.34..384.97 rows=388 width=23) (actual time=1.312..1.929 rows=383.00 loops=1)
                                Hash Cond: (p.reserva_id = r.id)
                                Buffers: shared hit=177
                                ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=8) (actual time=0.007..0.211 rows=5000.00 loops=1)
                                      Buffers: shared hit=44
                                ->  Hash  (cost=263.49..263.49 rows=388 width=23) (actual time=1.297..1.298 rows=383.00 loops=1)
                                      Buckets: 1024  Batches: 1  Memory Usage: 30kB
                                      Buffers: shared hit=133
                                      ->  Hash Join  (cost=150.35..263.49 rows=388 width=23) (actual time=0.595..1.225 rows=383.00 loops=1)
                                            Hash Cond: (r.passageiro_id = pas.id)
                                            Buffers: shared hit=133
                                            ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=12) (actual time=0.006..0.214 rows=5000.00 loops=1)
                                                  Buffers: shared hit=50
                                            ->  Hash  (cost=145.50..145.50 rows=388 width=19) (actual time=0.581..0.582 rows=388.00 loops=1)
                                                  Buckets: 1024  Batches: 1  Memory Usage: 29kB
                                                  Buffers: shared hit=83
                                                  ->  Seq Scan on passageiros pas  (cost=0.00..145.50 rows=388 width=19) (actual time=0.011..0.511 rows=388.00 loops=1)
                                                        Filter: ((programa_fidelidade)::text = 'SMILES'::text)
                                                        Rows Removed by Filter: 4612
                                                        Buffers: shared hit=83
  ->  Hash  (cost=18.00..18.00 rows=1000 width=10) (actual time=0.242..0.242 rows=1000.00 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 50kB
        Buffers: shared hit=8
        ->  Seq Scan on terminais t  (cost=0.00..18.00 rows=1000 width=10) (actual time=0.015..0.101 rows=1000.00 loops=1)
              Buffers: shared hit=8
Planning:
  Buffers: shared hit=60
Planning Time: 0.941 ms
Execution Time: 3.746 ms
```

---


### Query 6: Fornecedores por país com serviços de catering
* **Tabelas:** fornecedores, paises, cidades, aeroportos
* **Antipadrão:** Uso de LIKE '%CATERING%' ineficiente impedindo uso de índices de busca direta
* **Estratégia:** Usar comparação exata (= 'CATERING') para aproveitar o índice.

#### Comparação de Custo e Tempo
* **Custo Antes:** `64.51..64.75` | **Custo Depois:** `64.51..64.75` (**0.0% de redução**)
* **Tempo Antes:** `0.597 ms` | **Tempo Depois:** `0.480 ms`

#### Plano Antes:
```text
Sort  (cost=64.51..64.75 rows=95 width=52) (actual time=0.571..0.575 rows=95.00 loops=1)
  Sort Key: f.nome DESC
  Sort Method: quicksort  Memory: 31kB
  Buffers: shared hit=28
  ->  Hash Join  (cost=31.69..61.39 rows=95 width=52) (actual time=0.228..0.381 rows=95.00 loops=1)
        Hash Cond: (pa.id = f.pais_id)
        Buffers: shared hit=28
        ->  Seq Scan on paises pa  (cost=0.00..20.00 rows=1000 width=30) (actual time=0.012..0.088 rows=1000.00 loops=1)
              Buffers: shared hit=10
        ->  Hash  (cost=30.50..30.50 rows=95 width=30) (actual time=0.206..0.207 rows=95.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 14kB
              Buffers: shared hit=18
              ->  Seq Scan on fornecedores f  (cost=0.00..30.50 rows=95 width=30) (actual time=0.015..0.189 rows=95.00 loops=1)
                    Filter: ((tipo_servico)::text ~~ '%CATERING%'::text)
                    Rows Removed by Filter: 905
                    Buffers: shared hit=18
Planning:
  Buffers: shared hit=64
Planning Time: 1.766 ms
Execution Time: 0.597 ms
```

#### Plano Depois:
```text
Sort  (cost=64.51..64.75 rows=95 width=52) (actual time=0.455..0.459 rows=95.00 loops=1)
  Sort Key: f.nome DESC
  Sort Method: quicksort  Memory: 31kB
  Buffers: shared hit=28
  ->  Hash Join  (cost=31.69..61.39 rows=95 width=52) (actual time=0.142..0.268 rows=95.00 loops=1)
        Hash Cond: (pa.id = f.pais_id)
        Buffers: shared hit=28
        ->  Seq Scan on paises pa  (cost=0.00..20.00 rows=1000 width=30) (actual time=0.012..0.059 rows=1000.00 loops=1)
              Buffers: shared hit=10
        ->  Hash  (cost=30.50..30.50 rows=95 width=30) (actual time=0.121..0.121 rows=95.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 14kB
              Buffers: shared hit=18
              ->  Seq Scan on fornecedores f  (cost=0.00..30.50 rows=95 width=30) (actual time=0.009..0.105 rows=95.00 loops=1)
                    Filter: ((tipo_servico)::text = 'CATERING'::text)
                    Rows Removed by Filter: 905
                    Buffers: shared hit=18
Planning:
  Buffers: shared hit=12
Planning Time: 0.189 ms
Execution Time: 0.480 ms
```

---


### Query 7: Reservas por voo realizadas em determinado mês
* **Tabelas:** voos, reservas, aeroportos, status_voo
* **Antipadrão:** Uso da função EXTRACT no WHERE que invalida o índice na coluna data_partida
* **Estratégia:** Substituir EXTRACT por um filtro de intervalo sargable (>= e <) que usa o índice na data.

#### Comparação de Custo e Tempo
* **Custo Antes:** `171.46..171.48` | **Custo Depois:** `349.71..350.59` (**-104.45% de redução**)
* **Tempo Antes:** `1.953 ms` | **Tempo Depois:** `1.356 ms`

#### Plano Antes:
```text
GroupAggregate  (cost=171.46..171.48 rows=1 width=22) (actual time=1.905..1.919 rows=27.00 loops=1)
  Group Key: v.id, a.codigo_iata
  Buffers: shared hit=320
  ->  Sort  (cost=171.46..171.46 rows=1 width=18) (actual time=1.899..1.902 rows=44.00 loops=1)
        Sort Key: v.id, a.codigo_iata
        Sort Method: quicksort  Memory: 26kB
        Buffers: shared hit=320
        ->  Nested Loop  (cost=4.58..171.45 rows=1 width=18) (actual time=0.123..1.865 rows=44.00 loops=1)
              Buffers: shared hit=317
              ->  Nested Loop  (cost=4.30..163.14 rows=1 width=18) (actual time=0.118..1.759 rows=44.00 loops=1)
                    Buffers: shared hit=185
                    ->  Seq Scan on voos v  (cost=0.00..152.00 rows=1 width=14) (actual time=0.032..1.428 rows=45.00 loops=1)
                          Filter: ((EXTRACT(month FROM data_partida) = '6'::numeric) AND (EXTRACT(year FROM data_partida) = '2026'::numeric))
                          Rows Removed by Filter: 4955
                          Buffers: shared hit=52
                    ->  Bitmap Heap Scan on reservas r  (cost=4.30..11.12 rows=2 width=8) (actual time=0.003..0.004 rows=0.98 loops=45)
                          Recheck Cond: (voo_id = v.id)
                          Heap Blocks: exact=43
                          Buffers: shared hit=133
                          ->  Bitmap Index Scan on idx_reservas_voo_covering  (cost=0.00..4.30 rows=2 width=0) (actual time=0.002..0.002 rows=0.98 loops=45)
                                Index Cond: (voo_id = v.id)
                                Index Searches: 45
                                Buffers: shared hit=90
              ->  Index Scan using aeroportos_pkey on aeroportos a  (cost=0.28..8.30 rows=1 width=8) (actual time=0.002..0.002 rows=1.00 loops=44)
                    Index Cond: (id = v.aeroporto_origem_id)
                    Index Searches: 44
                    Buffers: shared hit=132
Planning:
  Buffers: shared hit=27
Planning Time: 0.438 ms
Execution Time: 1.953 ms
```

#### Plano Depois:
```text
GroupAggregate  (cost=349.71..350.59 rows=44 width=18) (actual time=1.303..1.320 rows=27.00 loops=1)
  Group Key: v.numero_voo, a.codigo_iata
  Buffers: shared hit=154
  ->  Sort  (cost=349.71..349.82 rows=44 width=14) (actual time=1.296..1.301 rows=44.00 loops=1)
        Sort Key: v.numero_voo, a.codigo_iata
        Sort Method: quicksort  Memory: 26kB
        Buffers: shared hit=154
        ->  Hash Join  (cost=171.82..348.51 rows=44 width=14) (actual time=0.683..1.235 rows=44.00 loops=1)
              Hash Cond: (a.id = v.aeroporto_origem_id)
              Buffers: shared hit=154
              ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=8) (actual time=0.010..0.221 rows=5000.00 loops=1)
                    Buffers: shared hit=70
              ->  Hash  (cost=171.27..171.27 rows=44 width=14) (actual time=0.651..0.653 rows=44.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 11kB
                    Buffers: shared hit=84
                    ->  Hash Join  (cost=58.14..171.27 rows=44 width=14) (actual time=0.063..0.645 rows=44.00 loops=1)
                          Hash Cond: (r.voo_id = v.id)
                          Buffers: shared hit=84
                          ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=8) (actual time=0.005..0.225 rows=5000.00 loops=1)
                                Buffers: shared hit=50
                          ->  Hash  (cost=57.59..57.59 rows=44 width=14) (actual time=0.049..0.050 rows=46.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 11kB
                                Buffers: shared hit=34
                                ->  Bitmap Heap Scan on voos v  (cost=4.73..57.59 rows=44 width=14) (actual time=0.017..0.042 rows=46.00 loops=1)
                                      Recheck Cond: ((data_partida >= '2026-05-31 21:00:00-03'::timestamp with time zone) AND (data_partida < '2026-06-30 21:00:00-03'::timestamp with time zone))
                                      Heap Blocks: exact=32
                                      Buffers: shared hit=34
                                      ->  Bitmap Index Scan on idx_voos_data_partida  (cost=0.00..4.72 rows=44 width=0) (actual time=0.007..0.007 rows=46.00 loops=1)
                                            Index Cond: ((data_partida >= '2026-05-31 21:00:00-03'::timestamp with time zone) AND (data_partida < '2026-06-30 21:00:00-03'::timestamp with time zone))
                                            Index Searches: 1
                                            Buffers: shared hit=2
Planning:
  Buffers: shared hit=39 read=2
Planning Time: 0.551 ms
Execution Time: 1.356 ms
```

---


### Query 8: Funcionários ativos sem escalas de voo atribuídas
* **Tabelas:** funcionarios, escalas_tripulacao, voos, cargos_funcionarios, aeroportos
* **Antipadrão:** Uso de NOT IN com subquery pesada que resulta em Seq Scan e pode falhar com NULLs
* **Estratégia:** Usar NOT EXISTS que é mais seguro e permite index scan com idx_funcionarios_ativos.

#### Comparação de Custo e Tempo
* **Custo Antes:** `329.50..484.50` | **Custo Depois:** `394.03..561.35` (**-15.86% de redução**)
* **Tempo Antes:** `4.393 ms` | **Tempo Depois:** `5.150 ms`

#### Plano Antes:
```text
Hash Join  (cost=329.50..484.50 rows=2376 width=66) (actual time=2.418..4.230 rows=1767.00 loops=1)
  Hash Cond: (f.aeroporto_base_id = a.id)
  Buffers: shared hit=212
  ->  Hash Join  (cost=147.00..295.76 rows=2376 width=48) (actual time=1.384..2.794 rows=1767.00 loops=1)
        Hash Cond: (f.cargo_id = c.id)
        Buffers: shared hit=142
        ->  Seq Scan on funcionarios f  (cost=102.50..245.00 rows=2376 width=23) (actual time=1.094..2.150 rows=1767.00 loops=1)
              Filter: (ativo AND (NOT (ANY (id = (hashed SubPlan 1).col1))))
              Rows Removed by Filter: 3233
              Buffers: shared hit=120
              SubPlan 1
                ->  Seq Scan on escalas_tripulacao  (cost=0.00..90.00 rows=5000 width=4) (actual time=0.008..0.350 rows=5000.00 loops=1)
                      Buffers: shared hit=40
        ->  Hash  (cost=32.00..32.00 rows=1000 width=33) (actual time=0.287..0.287 rows=1000.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 74kB
              Buffers: shared hit=22
              ->  Seq Scan on cargos_funcionarios c  (cost=0.00..32.00 rows=1000 width=33) (actual time=0.008..0.154 rows=1000.00 loops=1)
                    Buffers: shared hit=22
  ->  Hash  (cost=120.00..120.00 rows=5000 width=26) (actual time=1.017..1.021 rows=5000.00 loops=1)
        Buckets: 8192  Batches: 1  Memory Usage: 358kB
        Buffers: shared hit=70
        ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=26) (actual time=0.010..0.436 rows=5000.00 loops=1)
              Buffers: shared hit=70
Planning:
  Buffers: shared hit=72 read=3
Planning Time: 1.876 ms
Execution Time: 4.393 ms
```

#### Plano Depois:
```text
Hash Join  (cost=394.03..561.35 rows=1766 width=66) (actual time=3.691..4.962 rows=1767.00 loops=1)
  Hash Cond: (f.cargo_id = c.id)
  Buffers: shared hit=212
  ->  Hash Join  (cost=349.53..512.19 rows=1766 width=41) (actual time=3.441..4.387 rows=1767.00 loops=1)
        Hash Cond: (a.id = f.aeroporto_base_id)
        Buffers: shared hit=190
        ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=26) (actual time=0.006..0.228 rows=5000.00 loops=1)
              Buffers: shared hit=70
        ->  Hash  (cost=327.46..327.46 rows=1766 width=23) (actual time=3.427..3.432 rows=1767.00 loops=1)
              Buckets: 2048  Batches: 1  Memory Usage: 116kB
              Buffers: shared hit=120
              ->  Hash Right Anti Join  (cost=189.39..327.46 rows=1766 width=23) (actual time=2.773..3.085 rows=1767.00 loops=1)
                    Hash Cond: (et.funcionario_id = f.id)
                    Buffers: shared hit=120
                    ->  Seq Scan on escalas_tripulacao et  (cost=0.00..90.00 rows=5000 width=4) (actual time=0.017..0.253 rows=5000.00 loops=1)
                          Buffers: shared hit=40
                    ->  Hash  (cost=130.00..130.00 rows=4751 width=27) (actual time=1.468..1.468 rows=4751.00 loops=1)
                          Buckets: 8192  Batches: 1  Memory Usage: 350kB
                          Buffers: shared hit=80
                          ->  Seq Scan on funcionarios f  (cost=0.00..130.00 rows=4751 width=27) (actual time=0.006..0.665 rows=4751.00 loops=1)
                                Filter: ativo
                                Rows Removed by Filter: 249
                                Buffers: shared hit=80
  ->  Hash  (cost=32.00..32.00 rows=1000 width=33) (actual time=0.248..0.249 rows=1000.00 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 74kB
        Buffers: shared hit=22
        ->  Seq Scan on cargos_funcionarios c  (cost=0.00..32.00 rows=1000 width=33) (actual time=0.011..0.110 rows=1000.00 loops=1)
              Buffers: shared hit=22
Planning:
  Buffers: shared hit=36
Planning Time: 0.537 ms
Execution Time: 5.150 ms
```

---


### Query 9: Passageiros com muitas milhas e mais de uma reserva
* **Tabelas:** passageiros, reservas, voos, aeroportos, paises
* **Antipadrão:** Uso de filtro IN redundante no HAVING executado após o agrupamento
* **Estratégia:** Mover o filtro de milhas do HAVING para a cláusula WHERE, reduzindo as linhas antes do agrupamento.

#### Comparação de Custo e Tempo
* **Custo Antes:** `910.46..985.46` | **Custo Depois:** `718.27..780.15` (**20.83% de redução**)
* **Tempo Antes:** `13.116 ms` | **Tempo Depois:** `10.140 ms`

#### Plano Antes:
```text
HashAggregate  (cost=910.46..985.46 rows=833 width=58) (actual time=12.124..12.772 rows=1320.00 loops=1)
  Group Key: p.id
  Filter: ((count(r.id) > 1) AND (ANY (p.id = (hashed SubPlan 1).col1)))
  Batches: 1  Memory Usage: 665kB
  Rows Removed by Filter: 1830
  Buffers: shared hit=348
  ->  Hash Join  (cost=575.00..727.59 rows=5000 width=54) (actual time=3.836..9.032 rows=5000.00 loops=1)
        Hash Cond: (p.nacionalidade_id = pa.id)
        Buffers: shared hit=265
        ->  Hash Join  (cost=542.50..681.91 rows=5000 width=58) (actual time=3.633..7.912 rows=5000.00 loops=1)
              Hash Cond: (v.aeroporto_origem_id = a.id)
              Buffers: shared hit=255
              ->  Hash Join  (cost=360.00..486.27 rows=5000 width=62) (actual time=2.692..5.804 rows=5000.00 loops=1)
                    Hash Cond: (r.voo_id = v.id)
                    Buffers: shared hit=185
                    ->  Hash Join  (cost=195.50..308.64 rows=5000 width=62) (actual time=1.629..3.524 rows=5000.00 loops=1)
                          Hash Cond: (r.passageiro_id = p.id)
                          Buffers: shared hit=133
                          ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=12) (actual time=0.009..0.311 rows=5000.00 loops=1)
                                Buffers: shared hit=50
                          ->  Hash  (cost=133.00..133.00 rows=5000 width=54) (actual time=1.582..1.582 rows=5000.00 loops=1)
                                Buckets: 8192  Batches: 1  Memory Usage: 499kB
                                Buffers: shared hit=83
                                ->  Seq Scan on passageiros p  (cost=0.00..133.00 rows=5000 width=54) (actual time=0.007..0.621 rows=5000.00 loops=1)
                                      Buffers: shared hit=83
                    ->  Hash  (cost=102.00..102.00 rows=5000 width=8) (actual time=1.031..1.032 rows=5000.00 loops=1)
                          Buckets: 8192  Batches: 1  Memory Usage: 260kB
                          Buffers: shared hit=52
                          ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=8) (actual time=0.010..0.459 rows=5000.00 loops=1)
                                Buffers: shared hit=52
              ->  Hash  (cost=120.00..120.00 rows=5000 width=4) (actual time=0.907..0.908 rows=5000.00 loops=1)
                    Buckets: 8192  Batches: 1  Memory Usage: 240kB
                    Buffers: shared hit=70
                    ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=4) (actual time=0.008..0.382 rows=5000.00 loops=1)
                          Buffers: shared hit=70
        ->  Hash  (cost=20.00..20.00 rows=1000 width=4) (actual time=0.200..0.200 rows=1000.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 44kB
              Buffers: shared hit=10
              ->  Seq Scan on paises pa  (cost=0.00..20.00 rows=1000 width=4) (actual time=0.013..0.089 rows=1000.00 loops=1)
                    Buffers: shared hit=10
  SubPlan 1
    ->  Seq Scan on passageiros  (cost=0.00..145.50 rows=4950 width=4) (actual time=0.030..0.771 rows=4949.00 loops=1)
          Filter: (milhas_acumuladas > 5000)
          Rows Removed by Filter: 51
          Buffers: shared hit=83
Planning:
  Buffers: shared hit=52 read=3
Planning Time: 0.862 ms
Execution Time: 13.116 ms
```

#### Plano Depois:
```text
HashAggregate  (cost=718.27..780.15 rows=1650 width=58) (actual time=9.391..9.811 rows=1320.00 loops=1)
  Group Key: p.id
  Filter: (count(r.id) > 1)
  Batches: 1  Memory Usage: 665kB
  Rows Removed by Filter: 1797
  Buffers: shared hit=255
  ->  Hash Join  (cost=554.38..693.52 rows=4950 width=54) (actual time=3.948..7.945 rows=4948.00 loops=1)
        Hash Cond: (v.aeroporto_origem_id = a.id)
        Buffers: shared hit=255
        ->  Hash Join  (cost=371.88..498.02 rows=4950 width=58) (actual time=2.826..5.762 rows=4948.00 loops=1)
              Hash Cond: (r.voo_id = v.id)
              Buffers: shared hit=185
              ->  Hash Join  (cost=207.38..320.51 rows=4950 width=58) (actual time=1.761..3.569 rows=4948.00 loops=1)
                    Hash Cond: (r.passageiro_id = p.id)
                    Buffers: shared hit=133
                    ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=12) (actual time=0.009..0.305 rows=5000.00 loops=1)
                          Buffers: shared hit=50
                    ->  Hash  (cost=145.50..145.50 rows=4950 width=50) (actual time=1.715..1.716 rows=4949.00 loops=1)
                          Buckets: 8192  Batches: 1  Memory Usage: 476kB
                          Buffers: shared hit=83
                          ->  Seq Scan on passageiros p  (cost=0.00..145.50 rows=4950 width=50) (actual time=0.009..0.739 rows=4949.00 loops=1)
                                Filter: (milhas_acumuladas > 5000)
                                Rows Removed by Filter: 51
                                Buffers: shared hit=83
              ->  Hash  (cost=102.00..102.00 rows=5000 width=8) (actual time=1.033..1.033 rows=5000.00 loops=1)
                    Buckets: 8192  Batches: 1  Memory Usage: 260kB
                    Buffers: shared hit=52
                    ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=8) (actual time=0.016..0.468 rows=5000.00 loops=1)
                          Buffers: shared hit=52
        ->  Hash  (cost=120.00..120.00 rows=5000 width=4) (actual time=1.086..1.086 rows=5000.00 loops=1)
              Buckets: 8192  Batches: 1  Memory Usage: 240kB
              Buffers: shared hit=70
              ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=4) (actual time=0.013..0.456 rows=5000.00 loops=1)
                    Buffers: shared hit=70
Planning:
  Buffers: shared hit=36
Planning Time: 0.601 ms
Execution Time: 10.140 ms
```

---


### Query 10: Ocupação média por modelo de aeronave e fabricante
* **Tabelas:** aeronaves, modelos_aeronave, fabricantes, voos, reservas
* **Antipadrão:** Subquery correlacionada no SELECT com divisão de inteiros truncada
* **Estratégia:** Usar subquery de agregação prévia (JOIN) e cast explícito para DECIMAL.

#### Comparação de Custo e Tempo
* **Custo Antes:** `679.19..56506.69` | **Custo Depois:** `654.45..698.17` (**98.76% de redução**)
* **Tempo Antes:** `48.455 ms` | **Tempo Depois:** `9.684 ms`

#### Plano Antes:
```text
GroupAggregate  (cost=679.19..56506.69 rows=5000 width=70) (actual time=17.352..48.152 rows=952.00 loops=1)
  Group Key: f.nome, ma.id
  Buffers: shared hit=15085
  ->  Sort  (cost=679.19..691.69 rows=5000 width=42) (actual time=17.259..17.866 rows=5000.00 loops=1)
        Sort Key: f.nome, ma.id
        Sort Method: quicksort  Memory: 509kB
        Buffers: shared hit=125
        ->  Hash Join  (cost=230.50..372.00 rows=5000 width=42) (actual time=1.722..5.089 rows=5000.00 loops=1)
              Hash Cond: (ma.fabricante_id = f.id)
              Buffers: shared hit=125
              ->  Hash Join  (cost=186.00..314.32 rows=5000 width=29) (actual time=1.427..3.874 rows=5000.00 loops=1)
                    Hash Cond: (a.modelo_id = ma.id)
                    Buffers: shared hit=103
                    ->  Hash Join  (cost=152.50..267.64 rows=5000 width=8) (actual time=1.152..2.629 rows=5000.00 loops=1)
                          Hash Cond: (v.aeronave_id = a.id)
                          Buffers: shared hit=92
                          ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=8) (actual time=0.008..0.294 rows=5000.00 loops=1)
                                Buffers: shared hit=52
                          ->  Hash  (cost=90.00..90.00 rows=5000 width=8) (actual time=1.108..1.109 rows=5000.00 loops=1)
                                Buckets: 8192  Batches: 1  Memory Usage: 260kB
                                Buffers: shared hit=40
                                ->  Seq Scan on aeronaves a  (cost=0.00..90.00 rows=5000 width=8) (actual time=0.010..0.547 rows=5000.00 loops=1)
                                      Buffers: shared hit=40
                    ->  Hash  (cost=21.00..21.00 rows=1000 width=25) (actual time=0.273..0.273 rows=1000.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 67kB
                          Buffers: shared hit=11
                          ->  Seq Scan on modelos_aeronave ma  (cost=0.00..21.00 rows=1000 width=25) (actual time=0.011..0.136 rows=1000.00 loops=1)
                                Buffers: shared hit=11
              ->  Hash  (cost=32.00..32.00 rows=1000 width=21) (actual time=0.292..0.292 rows=1000.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 62kB
                    Buffers: shared hit=22
                    ->  Seq Scan on fabricantes f  (cost=0.00..32.00 rows=1000 width=21) (actual time=0.015..0.160 rows=1000.00 loops=1)
                          Buffers: shared hit=22
  SubPlan 1
    ->  Aggregate  (cost=11.13..11.14 rows=1 width=8) (actual time=0.005..0.005 rows=1.00 loops=5000)
          Buffers: shared hit=14960
          ->  Bitmap Heap Scan on reservas r  (cost=4.30..11.12 rows=2 width=4) (actual time=0.002..0.002 rows=1.00 loops=5000)
                Recheck Cond: (voo_id = v.id)
                Heap Blocks: exact=4948
                Buffers: shared hit=14960
                ->  Bitmap Index Scan on idx_reservas_voo_covering  (cost=0.00..4.30 rows=2 width=0) (actual time=0.001..0.001 rows=1.00 loops=5000)
                      Index Cond: (voo_id = v.id)
                      Index Searches: 5000
                      Buffers: shared hit=10012
Planning:
  Buffers: shared hit=188
Planning Time: 4.605 ms
Execution Time: 48.455 ms
```

#### Plano Depois:
```text
HashAggregate  (cost=654.45..698.17 rows=2915 width=66) (actual time=8.757..9.332 rows=869.00 loops=1)
  Group Key: f.nome, ma.nome, ma.capacidade_passageiros
  Batches: 1  Memory Usage: 657kB
  Buffers: shared hit=175
  ->  Hash Join  (cost=457.98..596.15 rows=2915 width=42) (actual time=3.662..6.623 rows=2761.00 loops=1)
        Hash Cond: (ma.fabricante_id = f.id)
        Buffers: shared hit=175
        ->  Hash Join  (cost=413.48..543.96 rows=2915 width=29) (actual time=3.427..5.853 rows=2761.00 loops=1)
              Hash Cond: (a.modelo_id = ma.id)
              Buffers: shared hit=153
              ->  Hash Join  (cost=379.98..502.78 rows=2915 width=12) (actual time=3.173..5.040 rows=2761.00 loops=1)
                    Hash Cond: (v.aeronave_id = a.id)
                    Buffers: shared hit=142
                    ->  Hash Join  (cost=227.48..342.61 rows=2915 width=12) (actual time=2.140..3.379 rows=2761.00 loops=1)
                          Hash Cond: (v.id = counts.voo_id)
                          Buffers: shared hit=102
                          ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=8) (actual time=0.011..0.288 rows=5000.00 loops=1)
                                Buffers: shared hit=52
                          ->  Hash  (cost=191.04..191.04 rows=2915 width=12) (actual time=2.108..2.110 rows=2761.00 loops=1)
                                Buckets: 4096  Batches: 1  Memory Usage: 151kB
                                Buffers: shared hit=50
                                ->  Subquery Scan on counts  (cost=132.74..191.04 rows=2915 width=12) (actual time=1.293..1.772 rows=2761.00 loops=1)
                                      Buffers: shared hit=50
                                      ->  HashAggregate  (cost=132.74..161.89 rows=2915 width=12) (actual time=1.292..1.594 rows=2761.00 loops=1)
                                            Group Key: reservas.voo_id
                                            Batches: 1  Memory Usage: 217kB
                                            Buffers: shared hit=50
                                            ->  Seq Scan on reservas  (cost=0.00..112.50 rows=4048 width=8) (actual time=0.006..0.601 rows=4048.00 loops=1)
                                                  Filter: ((status)::text <> 'CANCELADA'::text)
                                                  Rows Removed by Filter: 952
                                                  Buffers: shared hit=50
                    ->  Hash  (cost=90.00..90.00 rows=5000 width=8) (actual time=0.999..1.005 rows=5000.00 loops=1)
                          Buckets: 8192  Batches: 1  Memory Usage: 260kB
                          Buffers: shared hit=40
                          ->  Seq Scan on aeronaves a  (cost=0.00..90.00 rows=5000 width=8) (actual time=0.008..0.439 rows=5000.00 loops=1)
                                Buffers: shared hit=40
              ->  Hash  (cost=21.00..21.00 rows=1000 width=25) (actual time=0.252..0.252 rows=1000.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 67kB
                    Buffers: shared hit=11
                    ->  Seq Scan on modelos_aeronave ma  (cost=0.00..21.00 rows=1000 width=25) (actual time=0.009..0.111 rows=1000.00 loops=1)
                          Buffers: shared hit=11
        ->  Hash  (cost=32.00..32.00 rows=1000 width=21) (actual time=0.233..0.233 rows=1000.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 62kB
              Buffers: shared hit=22
              ->  Seq Scan on fabricantes f  (cost=0.00..32.00 rows=1000 width=21) (actual time=0.017..0.108 rows=1000.00 loops=1)
                    Buffers: shared hit=22
Planning:
  Buffers: shared hit=46
Planning Time: 0.654 ms
Execution Time: 9.684 ms
```

---


### Query 11: Histórico de passagens compradas por um passageiro
* **Tabelas:** passageiros, reservas, passagens, voos, aeroportos, cartoes_embarque
* **Antipadrão:** Múltiplas subqueries aninhadas ineficientes (IN dentro de IN)
* **Estratégia:** Substituir subqueries aninhadas por JOINs planos diretos e usar índice de email.

#### Comparação de Custo e Tempo
* **Custo Antes:** `172.67..181.58` | **Custo Depois:** `59.75..190.13` (**-4.71% de redução**)
* **Tempo Antes:** `0.077 ms` | **Tempo Depois:** `0.064 ms`

#### Plano Antes:
```text
Nested Loop  (cost=172.67..181.58 rows=25 width=24) (actual time=0.036..0.038 rows=0.00 loops=1)
  Buffers: shared hit=4
  ->  HashAggregate  (cost=172.38..172.63 rows=25 width=4) (actual time=0.035..0.038 rows=0.00 loops=1)
        Group Key: reservas.id
        Batches: 1  Memory Usage: 32kB
        Buffers: shared hit=4
        ->  Hash Join  (cost=59.18..172.32 rows=25 width=4) (actual time=0.034..0.036 rows=0.00 loops=1)
              Hash Cond: (reservas.passageiro_id = passageiros.id)
              Buffers: shared hit=4
              ->  Seq Scan on reservas  (cost=0.00..100.00 rows=5000 width=8) (actual time=0.011..0.011 rows=1.00 loops=1)
                    Buffers: shared hit=2
              ->  Hash  (cost=58.87..58.87 rows=25 width=4) (actual time=0.020..0.022 rows=0.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 8kB
                    Buffers: shared hit=2
                    ->  Bitmap Heap Scan on passageiros  (cost=4.48..58.87 rows=25 width=4) (actual time=0.020..0.020 rows=0.00 loops=1)
                          Recheck Cond: (lower((email)::text) = 'ana.souza.1@example.com'::text)
                          Buffers: shared hit=2
                          ->  Bitmap Index Scan on idx_passageiros_email_lower  (cost=0.00..4.47 rows=25 width=0) (actual time=0.013..0.013 rows=0.00 loops=1)
                                Index Cond: (lower((email)::text) = 'ana.souza.1@example.com'::text)
                                Index Searches: 1
                                Buffers: shared hit=2
  ->  Index Scan using idx_passagens_reserva_id on passagens  (cost=0.28..0.35 rows=1 width=28) (never executed)
        Index Cond: (reserva_id = reservas.id)
        Index Searches: 0
Planning:
  Buffers: shared hit=24
Planning Time: 0.399 ms
Execution Time: 0.077 ms
```

#### Plano Depois:
```text
Nested Loop  (cost=59.75..190.13 rows=25 width=36) (actual time=0.030..0.032 rows=0.00 loops=1)
  Buffers: shared hit=4
  ->  Nested Loop  (cost=59.47..181.27 rows=25 width=34) (actual time=0.029..0.032 rows=0.00 loops=1)
        Buffers: shared hit=4
        ->  Hash Join  (cost=59.18..172.32 rows=25 width=14) (actual time=0.029..0.031 rows=0.00 loops=1)
              Hash Cond: (r.passageiro_id = pas.id)
              Buffers: shared hit=4
              ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=18) (actual time=0.010..0.010 rows=1.00 loops=1)
                    Buffers: shared hit=2
              ->  Hash  (cost=58.87..58.87 rows=25 width=4) (actual time=0.017..0.019 rows=0.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 8kB
                    Buffers: shared hit=2
                    ->  Bitmap Heap Scan on passageiros pas  (cost=4.48..58.87 rows=25 width=4) (actual time=0.017..0.017 rows=0.00 loops=1)
                          Recheck Cond: (lower((email)::text) = 'ana.souza.1@example.com'::text)
                          Buffers: shared hit=2
                          ->  Bitmap Index Scan on idx_passageiros_email_lower  (cost=0.00..4.47 rows=25 width=0) (actual time=0.010..0.010 rows=0.00 loops=1)
                                Index Cond: (lower((email)::text) = 'ana.souza.1@example.com'::text)
                                Index Searches: 1
                                Buffers: shared hit=2
        ->  Index Scan using idx_passagens_reserva_id on passagens p  (cost=0.28..0.35 rows=1 width=28) (never executed)
              Index Cond: (reserva_id = r.id)
              Index Searches: 0
  ->  Index Scan using voos_pkey on voos v  (cost=0.28..0.35 rows=1 width=10) (never executed)
        Index Cond: (id = r.voo_id)
        Index Searches: 0
Planning:
  Buffers: shared hit=36
Planning Time: 0.514 ms
Execution Time: 0.064 ms
```

---


### Query 12: Voos atrasados ou cancelados e impacto nos tripulantes
* **Tabelas:** voos, status_voo, escalas_tripulacao, funcionarios, aeroportos
* **Antipadrão:** Uso de cláusula OR complexa no WHERE na filtragem de status
* **Estratégia:** Usar IN para permitir otimizações de índice compostos.

#### Comparação de Custo e Tempo
* **Custo Antes:** `13.45..61.34` | **Custo Depois:** `13.45..61.34` (**0.0% de redução**)
* **Tempo Antes:** `0.265 ms` | **Tempo Depois:** `0.146 ms`

#### Plano Antes:
```text
Nested Loop  (cost=13.45..61.34 rows=10 width=34) (actual time=0.079..0.236 rows=18.00 loops=1)
  Buffers: shared hit=133
  ->  Nested Loop  (cost=13.17..57.57 rows=10 width=23) (actual time=0.069..0.161 rows=18.00 loops=1)
        Buffers: shared hit=79
        ->  Nested Loop  (cost=12.89..53.71 rows=10 width=23) (actual time=0.051..0.075 rows=18.00 loops=1)
              Buffers: shared hit=25
              ->  Bitmap Heap Scan on status_voo sv  (cost=8.57..14.15 rows=2 width=17) (actual time=0.034..0.035 rows=2.00 loops=1)
                    Recheck Cond: (((codigo)::text = 'ATRASADO'::text) OR ((codigo)::text = 'CANCELADO'::text))
                    Heap Blocks: exact=1
                    Buffers: shared hit=3
                    ->  Bitmap Index Scan on status_voo_codigo_key  (cost=0.00..8.57 rows=2 width=0) (actual time=0.024..0.024 rows=2.00 loops=1)
                          Index Cond: ((codigo)::text = ANY ('{ATRASADO,CANCELADO}'::text[]))
                          Index Searches: 1
                          Buffers: shared hit=2
              ->  Bitmap Heap Scan on voos v  (cost=4.32..19.73 rows=5 width=14) (actual time=0.010..0.016 rows=9.00 loops=2)
                    Recheck Cond: (sv.id = status_id)
                    Heap Blocks: exact=18
                    Buffers: shared hit=22
                    ->  Bitmap Index Scan on idx_voos_status_id  (cost=0.00..4.32 rows=5 width=0) (actual time=0.004..0.004 rows=9.00 loops=2)
                          Index Cond: (status_id = sv.id)
                          Index Searches: 2
                          Buffers: shared hit=4
        ->  Index Scan using idx_escalas_voo_id on escalas_tripulacao et  (cost=0.28..0.37 rows=2 width=8) (actual time=0.004..0.004 rows=1.00 loops=18)
              Index Cond: (voo_id = v.id)
              Index Searches: 18
              Buffers: shared hit=54
  ->  Index Scan using funcionarios_pkey on funcionarios f  (cost=0.28..0.38 rows=1 width=19) (actual time=0.004..0.004 rows=1.00 loops=18)
        Index Cond: (id = et.funcionario_id)
        Index Searches: 18
        Buffers: shared hit=54
Planning:
  Buffers: shared hit=88
Planning Time: 1.874 ms
Execution Time: 0.265 ms
```

#### Plano Depois:
```text
Nested Loop  (cost=13.45..61.34 rows=10 width=34) (actual time=0.044..0.126 rows=18.00 loops=1)
  Buffers: shared hit=133
  ->  Nested Loop  (cost=13.17..57.57 rows=10 width=23) (actual time=0.041..0.094 rows=18.00 loops=1)
        Buffers: shared hit=79
        ->  Nested Loop  (cost=12.89..53.71 rows=10 width=23) (actual time=0.034..0.056 rows=18.00 loops=1)
              Buffers: shared hit=25
              ->  Bitmap Heap Scan on status_voo sv  (cost=8.57..14.14 rows=2 width=17) (actual time=0.024..0.024 rows=2.00 loops=1)
                    Recheck Cond: ((codigo)::text = ANY ('{ATRASADO,CANCELADO}'::text[]))
                    Heap Blocks: exact=1
                    Buffers: shared hit=3
                    ->  Bitmap Index Scan on status_voo_codigo_key  (cost=0.00..8.57 rows=2 width=0) (actual time=0.015..0.015 rows=2.00 loops=1)
                          Index Cond: ((codigo)::text = ANY ('{ATRASADO,CANCELADO}'::text[]))
                          Index Searches: 1
                          Buffers: shared hit=2
              ->  Bitmap Heap Scan on voos v  (cost=4.32..19.73 rows=5 width=14) (actual time=0.007..0.012 rows=9.00 loops=2)
                    Recheck Cond: (sv.id = status_id)
                    Heap Blocks: exact=18
                    Buffers: shared hit=22
                    ->  Bitmap Index Scan on idx_voos_status_id  (cost=0.00..4.32 rows=5 width=0) (actual time=0.003..0.003 rows=9.00 loops=2)
                          Index Cond: (status_id = sv.id)
                          Index Searches: 2
                          Buffers: shared hit=4
        ->  Index Scan using idx_escalas_voo_id on escalas_tripulacao et  (cost=0.28..0.37 rows=2 width=8) (actual time=0.002..0.002 rows=1.00 loops=18)
              Index Cond: (voo_id = v.id)
              Index Searches: 18
              Buffers: shared hit=54
  ->  Index Scan using funcionarios_pkey on funcionarios f  (cost=0.28..0.38 rows=1 width=19) (actual time=0.001..0.001 rows=1.00 loops=18)
        Index Cond: (id = et.funcionario_id)
        Index Searches: 18
        Buffers: shared hit=54
Planning:
  Buffers: shared hit=36
Planning Time: 0.475 ms
Execution Time: 0.146 ms
```

---


### Query 13: Receita por terminal e gate
* **Tabelas:** terminais, cartoes_embarque, passagens, reservas, categorias_tarifa
* **Antipadrão:** Agrupamento inútil por chaves PK redundantes no GROUP BY
* **Estratégia:** Simplificar GROUP BY removendo IDs redundantes, evitando ordenações adicionais na memória.

#### Comparação de Custo e Tempo
* **Custo Antes:** `540.95..603.45` | **Custo Depois:** `540.95..603.45` (**0.0% de redução**)
* **Tempo Antes:** `10.754 ms` | **Tempo Depois:** `10.169 ms`

#### Plano Antes:
```text
HashAggregate  (cost=540.95..603.45 rows=5000 width=57) (actual time=8.558..10.188 rows=5000.00 loops=1)
  Group Key: t.id, ce.id
  Batches: 1  Memory Usage: 2193kB
  Buffers: shared hit=154
  ->  Hash Join  (cost=349.50..490.95 rows=5000 width=27) (actual time=2.550..6.264 rows=5000.00 loops=1)
        Hash Cond: (p.reserva_id = r.id)
        Buffers: shared hit=154
        ->  Hash Join  (cost=187.00..315.32 rows=5000 width=25) (actual time=1.323..3.992 rows=5000.00 loops=1)
              Hash Cond: (ce.passagem_id = p.id)
              Buffers: shared hit=104
              ->  Hash Join  (cost=30.50..145.68 rows=5000 width=21) (actual time=0.244..1.868 rows=5000.00 loops=1)
                    Hash Cond: (ce.terminal_id = t.id)
                    Buffers: shared hit=60
                    ->  Seq Scan on cartoes_embarque ce  (cost=0.00..102.00 rows=5000 width=15) (actual time=0.008..0.313 rows=5000.00 loops=1)
                          Buffers: shared hit=52
                    ->  Hash  (cost=18.00..18.00 rows=1000 width=10) (actual time=0.234..0.234 rows=1000.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 50kB
                          Buffers: shared hit=8
                          ->  Seq Scan on terminais t  (cost=0.00..18.00 rows=1000 width=10) (actual time=0.011..0.098 rows=1000.00 loops=1)
                                Buffers: shared hit=8
              ->  Hash  (cost=94.00..94.00 rows=5000 width=8) (actual time=1.045..1.045 rows=5000.00 loops=1)
                    Buckets: 8192  Batches: 1  Memory Usage: 260kB
                    Buffers: shared hit=44
                    ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=8) (actual time=0.007..0.460 rows=5000.00 loops=1)
                          Buffers: shared hit=44
        ->  Hash  (cost=100.00..100.00 rows=5000 width=10) (actual time=1.215..1.216 rows=5000.00 loops=1)
              Buckets: 8192  Batches: 1  Memory Usage: 280kB
              Buffers: shared hit=50
              ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=10) (actual time=0.010..0.532 rows=5000.00 loops=1)
                    Buffers: shared hit=50
Planning:
  Buffers: shared hit=36
Planning Time: 0.454 ms
Execution Time: 10.754 ms
```

#### Plano Depois:
```text
HashAggregate  (cost=540.95..603.45 rows=5000 width=49) (actual time=8.379..9.678 rows=4343.00 loops=1)
  Group Key: t.nome, ce.gate
  Batches: 1  Memory Usage: 1937kB
  Buffers: shared hit=154
  ->  Hash Join  (cost=349.50..490.95 rows=5000 width=19) (actual time=2.468..6.073 rows=5000.00 loops=1)
        Hash Cond: (p.reserva_id = r.id)
        Buffers: shared hit=154
        ->  Hash Join  (cost=187.00..315.32 rows=5000 width=17) (actual time=1.235..3.808 rows=5000.00 loops=1)
              Hash Cond: (ce.passagem_id = p.id)
              Buffers: shared hit=104
              ->  Hash Join  (cost=30.50..145.68 rows=5000 width=13) (actual time=0.255..1.829 rows=5000.00 loops=1)
                    Hash Cond: (ce.terminal_id = t.id)
                    Buffers: shared hit=60
                    ->  Seq Scan on cartoes_embarque ce  (cost=0.00..102.00 rows=5000 width=11) (actual time=0.009..0.302 rows=5000.00 loops=1)
                          Buffers: shared hit=52
                    ->  Hash  (cost=18.00..18.00 rows=1000 width=10) (actual time=0.242..0.243 rows=1000.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 50kB
                          Buffers: shared hit=8
                          ->  Seq Scan on terminais t  (cost=0.00..18.00 rows=1000 width=10) (actual time=0.010..0.100 rows=1000.00 loops=1)
                                Buffers: shared hit=8
              ->  Hash  (cost=94.00..94.00 rows=5000 width=8) (actual time=0.952..0.952 rows=5000.00 loops=1)
                    Buckets: 8192  Batches: 1  Memory Usage: 260kB
                    Buffers: shared hit=44
                    ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=8) (actual time=0.007..0.408 rows=5000.00 loops=1)
                          Buffers: shared hit=44
        ->  Hash  (cost=100.00..100.00 rows=5000 width=10) (actual time=1.203..1.203 rows=5000.00 loops=1)
              Buckets: 8192  Batches: 1  Memory Usage: 280kB
              Buffers: shared hit=50
              ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=10) (actual time=0.017..0.531 rows=5000.00 loops=1)
                    Buffers: shared hit=50
Planning:
  Buffers: shared hit=36
Planning Time: 0.576 ms
Execution Time: 10.169 ms
```

---


### Query 14: Aeronaves com maior utilização por quilometragem
* **Tabelas:** aeronaves, modelos_aeronave, fabricantes, voos, reservas
* **Antipadrão:** Uso de ORDER BY com expressão matemática complexa sem índice
* **Estratégia:** Pré-agrupar voos em subquery para reduzir número de linhas antes dos JOINs complexos.

#### Comparação de Custo e Tempo
* **Custo Antes:** `804.19..816.69` | **Custo Depois:** `614.22..622.01` (**23.84% de redução**)
* **Tempo Antes:** `9.333 ms` | **Tempo Depois:** `6.192 ms`

#### Plano Antes:
```text
Sort  (cost=804.19..816.69 rows=5000 width=62) (actual time=8.620..8.785 rows=3114.00 loops=1)
  Sort Key: ((count(v.id) * ma.alcance_km)) DESC
  Sort Method: quicksort  Memory: 371kB
  Buffers: shared hit=128
  ->  HashAggregate  (cost=434.50..497.00 rows=5000 width=62) (actual time=7.143..7.685 rows=3114.00 loops=1)
        Group Key: a.matricula, ma.nome, f.nome, ma.alcance_km
        Batches: 1  Memory Usage: 409kB
        Buffers: shared hit=125
        ->  Hash Join  (cost=230.50..372.00 rows=5000 width=50) (actual time=1.672..5.294 rows=5000.00 loops=1)
              Hash Cond: (ma.fabricante_id = f.id)
              Buffers: shared hit=125
              ->  Hash Join  (cost=186.00..314.32 rows=5000 width=37) (actual time=1.434..4.072 rows=5000.00 loops=1)
                    Hash Cond: (a.modelo_id = ma.id)
                    Buffers: shared hit=103
                    ->  Hash Join  (cost=152.50..267.64 rows=5000 width=20) (actual time=1.176..2.765 rows=5000.00 loops=1)
                          Hash Cond: (v.aeronave_id = a.id)
                          Buffers: shared hit=92
                          ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=8) (actual time=0.007..0.296 rows=5000.00 loops=1)
                                Buffers: shared hit=52
                          ->  Hash  (cost=90.00..90.00 rows=5000 width=16) (actual time=1.137..1.138 rows=5000.00 loops=1)
                                Buckets: 8192  Batches: 1  Memory Usage: 311kB
                                Buffers: shared hit=40
                                ->  Seq Scan on aeronaves a  (cost=0.00..90.00 rows=5000 width=16) (actual time=0.006..0.461 rows=5000.00 loops=1)
                                      Buffers: shared hit=40
                    ->  Hash  (cost=21.00..21.00 rows=1000 width=25) (actual time=0.256..0.257 rows=1000.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 67kB
                          Buffers: shared hit=11
                          ->  Seq Scan on modelos_aeronave ma  (cost=0.00..21.00 rows=1000 width=25) (actual time=0.009..0.115 rows=1000.00 loops=1)
                                Buffers: shared hit=11
              ->  Hash  (cost=32.00..32.00 rows=1000 width=21) (actual time=0.235..0.235 rows=1000.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 62kB
                    Buffers: shared hit=22
                    ->  Seq Scan on fabricantes f  (cost=0.00..32.00 rows=1000 width=21) (actual time=0.012..0.106 rows=1000.00 loops=1)
                          Buffers: shared hit=22
Planning:
  Buffers: shared hit=52
Planning Time: 0.516 ms
Execution Time: 9.333 ms
```

#### Plano Depois:
```text
Sort  (cost=614.22..622.01 rows=3114 width=54) (actual time=5.798..5.917 rows=3114.00 loops=1)
  Sort Key: ((v_stats.total_voos * ma.alcance_km)) DESC
  Sort Method: quicksort  Memory: 323kB
  Buffers: shared hit=125
  ->  Hash Join  (cost=306.20..433.54 rows=3114 width=54) (actual time=2.623..4.906 rows=3114.00 loops=1)
        Hash Cond: (ma.fabricante_id = f.id)
        Buffers: shared hit=125
        ->  Hash Join  (cost=261.70..373.05 rows=3114 width=37) (actual time=2.387..4.096 rows=3114.00 loops=1)
              Hash Cond: (a.modelo_id = ma.id)
              Buffers: shared hit=103
              ->  Hash Join  (cost=228.20..331.34 rows=3114 width=20) (actual time=2.129..3.208 rows=3114.00 loops=1)
                    Hash Cond: (a.id = v_stats.aeronave_id)
                    Buffers: shared hit=92
                    ->  Seq Scan on aeronaves a  (cost=0.00..90.00 rows=5000 width=16) (actual time=0.007..0.251 rows=5000.00 loops=1)
                          Buffers: shared hit=40
                    ->  Hash  (cost=189.28..189.28 rows=3114 width=12) (actual time=2.103..2.103 rows=3114.00 loops=1)
                          Buckets: 4096  Batches: 1  Memory Usage: 166kB
                          Buffers: shared hit=52
                          ->  Subquery Scan on v_stats  (cost=127.00..189.28 rows=3114 width=12) (actual time=1.210..1.748 rows=3114.00 loops=1)
                                Buffers: shared hit=52
                                ->  HashAggregate  (cost=127.00..158.14 rows=3114 width=12) (actual time=1.210..1.551 rows=3114.00 loops=1)
                                      Group Key: voos.aeronave_id
                                      Batches: 1  Memory Usage: 217kB
                                      Buffers: shared hit=52
                                      ->  Seq Scan on voos  (cost=0.00..102.00 rows=5000 width=8) (actual time=0.007..0.225 rows=5000.00 loops=1)
                                            Buffers: shared hit=52
              ->  Hash  (cost=21.00..21.00 rows=1000 width=25) (actual time=0.256..0.256 rows=1000.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 67kB
                    Buffers: shared hit=11
                    ->  Seq Scan on modelos_aeronave ma  (cost=0.00..21.00 rows=1000 width=25) (actual time=0.010..0.113 rows=1000.00 loops=1)
                          Buffers: shared hit=11
        ->  Hash  (cost=32.00..32.00 rows=1000 width=21) (actual time=0.232..0.233 rows=1000.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 62kB
              Buffers: shared hit=22
              ->  Seq Scan on fabricantes f  (cost=0.00..32.00 rows=1000 width=21) (actual time=0.016..0.112 rows=1000.00 loops=1)
                    Buffers: shared hit=22
Planning:
  Buffers: shared hit=24
Planning Time: 0.443 ms
Execution Time: 6.192 ms
```

---


### Query 15: Conexões possíveis entre voos no mesmo terminal com intervalo curto
* **Tabelas:** voos, aeroportos, terminais, cidades, paises
* **Antipadrão:** Self-join sem cláusula ON apropriada filtrando apenas no WHERE
* **Estratégia:** Filtrar a data da conexão diretamente na cláusula ON do JOIN para limitar o plano carteseano.

#### Comparação de Custo e Tempo
* **Custo Antes:** `199.31..470.15` | **Custo Depois:** `199.31..469.78` (**0.08% de redução**)
* **Tempo Antes:** `2.106 ms` | **Tempo Depois:** `2.162 ms`

#### Plano Antes:
```text
Nested Loop  (cost=199.31..470.15 rows=174 width=40) (actual time=2.073..2.074 rows=0.00 loops=1)
  Buffers: shared hit=112
  ->  Hash Join  (cost=199.03..369.10 rows=274 width=30) (actual time=2.073..2.073 rows=0.00 loops=1)
        Hash Cond: (v2.aeroporto_origem_id = v1.aeroporto_destino_id)
        Join Filter: ((v1.data_chegada < v2.data_partida) AND ((v2.data_partida - v1.data_chegada) < '04:00:00'::interval))
        Rows Removed by Join Filter: 951
        Buffers: shared hit=112
        ->  Seq Scan on voos v2  (cost=0.00..102.00 rows=5000 width=18) (actual time=0.010..0.227 rows=5000.00 loops=1)
              Buffers: shared hit=52
        ->  Hash  (cost=179.43..179.43 rows=1568 width=28) (actual time=1.259..1.260 rows=973.00 loops=1)
              Buckets: 2048  Batches: 1  Memory Usage: 80kB
              Buffers: shared hit=60
              ->  Hash Join  (cost=30.50..179.43 rows=1568 width=28) (actual time=0.244..1.091 rows=973.00 loops=1)
                    Hash Cond: (v1.aeroporto_destino_id = t.aeroporto_id)
                    Buffers: shared hit=60
                    ->  Seq Scan on voos v1  (cost=0.00..102.00 rows=5000 width=18) (actual time=0.004..0.228 rows=5000.00 loops=1)
                          Buffers: shared hit=52
                    ->  Hash  (cost=18.00..18.00 rows=1000 width=10) (actual time=0.234..0.235 rows=1000.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 50kB
                          Buffers: shared hit=8
                          ->  Seq Scan on terminais t  (cost=0.00..18.00 rows=1000 width=10) (actual time=0.007..0.095 rows=1000.00 loops=1)
                                Buffers: shared hit=8
  ->  Index Scan using aeroportos_pkey on aeroportos a  (cost=0.28..0.37 rows=1 width=26) (never executed)
        Index Cond: (id = v1.aeroporto_destino_id)
        Index Searches: 0
Planning:
  Buffers: shared hit=185
Planning Time: 0.991 ms
Execution Time: 2.106 ms
```

#### Plano Depois:
```text
Nested Loop  (cost=199.31..469.78 rows=111 width=40) (actual time=2.127..2.129 rows=0.00 loops=1)
  Buffers: shared hit=112
  ->  Hash Join  (cost=199.03..369.10 rows=273 width=30) (actual time=2.127..2.129 rows=0.00 loops=1)
        Hash Cond: (v2.aeroporto_origem_id = v1.aeroporto_destino_id)
        Join Filter: ((v2.data_partida > v1.data_chegada) AND (v2.data_partida <= (v1.data_chegada + '04:00:00'::interval)))
        Rows Removed by Join Filter: 951
        Buffers: shared hit=112
        ->  Seq Scan on voos v2  (cost=0.00..102.00 rows=5000 width=18) (actual time=0.014..0.226 rows=5000.00 loops=1)
              Buffers: shared hit=52
        ->  Hash  (cost=179.43..179.43 rows=1568 width=28) (actual time=1.339..1.341 rows=973.00 loops=1)
              Buckets: 2048  Batches: 1  Memory Usage: 80kB
              Buffers: shared hit=60
              ->  Hash Join  (cost=30.50..179.43 rows=1568 width=28) (actual time=0.247..1.166 rows=973.00 loops=1)
                    Hash Cond: (v1.aeroporto_destino_id = t.aeroporto_id)
                    Buffers: shared hit=60
                    ->  Seq Scan on voos v1  (cost=0.00..102.00 rows=5000 width=18) (actual time=0.004..0.224 rows=5000.00 loops=1)
                          Buffers: shared hit=52
                    ->  Hash  (cost=18.00..18.00 rows=1000 width=10) (actual time=0.236..0.237 rows=1000.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 50kB
                          Buffers: shared hit=8
                          ->  Seq Scan on terminais t  (cost=0.00..18.00 rows=1000 width=10) (actual time=0.008..0.101 rows=1000.00 loops=1)
                                Buffers: shared hit=8
  ->  Index Scan using aeroportos_pkey on aeroportos a  (cost=0.28..0.37 rows=1 width=26) (never executed)
        Index Cond: (id = v1.aeroporto_destino_id)
        Index Searches: 0
Planning:
  Buffers: shared hit=75
Planning Time: 0.853 ms
Execution Time: 2.162 ms
```

---


### Query 16: Passageiros de voos de longa distância que não despacharam bagagem
* **Tabelas:** passageiros, passagens, reservas, voos, bagagens
* **Antipadrão:** Uso de LEFT JOIN com filtro IS NULL ineficiente
* **Estratégia:** Usar NOT EXISTS para permitir short-circuiting no escaneamento de registros.

#### Comparação de Custo e Tempo
* **Custo Antes:** `157.35..267.73` | **Custo Depois:** `584.91..744.23` (**-177.98% de redução**)
* **Tempo Antes:** `11.014 ms` | **Tempo Depois:** `5.489 ms`

#### Plano Antes:
```text
Nested Loop  (cost=157.35..267.73 rows=1 width=52) (actual time=2.034..10.876 rows=761.00 loops=1)
  Buffers: shared hit=16516
  ->  Nested Loop  (cost=157.06..267.37 rows=1 width=50) (actual time=2.028..7.884 rows=1825.00 loops=1)
        Buffers: shared hit=11041
        ->  Nested Loop  (cost=156.78..266.99 rows=1 width=8) (actual time=2.011..5.089 rows=1825.00 loops=1)
              Buffers: shared hit=5566
              ->  Hash Right Join  (cost=156.50..266.64 rows=1 width=4) (actual time=2.000..2.342 rows=1825.00 loops=1)
                    Hash Cond: (b.passagem_id = p.id)
                    Filter: (b.id IS NULL)
                    Rows Removed by Filter: 5000
                    Buffers: shared hit=91
                    ->  Seq Scan on bagagens b  (cost=0.00..97.00 rows=5000 width=8) (actual time=0.008..0.234 rows=5000.00 loops=1)
                          Buffers: shared hit=47
                    ->  Hash  (cost=94.00..94.00 rows=5000 width=8) (actual time=0.883..0.883 rows=5000.00 loops=1)
                          Buckets: 8192  Batches: 1  Memory Usage: 260kB
                          Buffers: shared hit=44
                          ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=8) (actual time=0.013..0.407 rows=5000.00 loops=1)
                                Buffers: shared hit=44
              ->  Index Scan using reservas_pkey on reservas r  (cost=0.28..0.35 rows=1 width=12) (actual time=0.001..0.001 rows=1.00 loops=1825)
                    Index Cond: (id = p.reserva_id)
                    Index Searches: 1825
                    Buffers: shared hit=5475
        ->  Index Scan using passageiros_pkey on passageiros pas  (cost=0.28..0.38 rows=1 width=50) (actual time=0.001..0.001 rows=1.00 loops=1825)
              Index Cond: (id = r.passageiro_id)
              Index Searches: 1825
              Buffers: shared hit=5475
  ->  Index Scan using voos_pkey on voos v  (cost=0.28..0.36 rows=1 width=10) (actual time=0.001..0.001 rows=0.42 loops=1825)
        Index Cond: (id = r.voo_id)
        Filter: (preco_base > '1500'::numeric)
        Rows Removed by Filter: 1
        Index Searches: 1825
        Buffers: shared hit=5475
Planning:
  Buffers: shared hit=51
Planning Time: 0.721 ms
Execution Time: 11.014 ms
```

#### Plano Depois:
```text
Hash Join  (cost=584.91..744.23 rows=757 width=52) (actual time=4.665..5.383 rows=761.00 loops=1)
  Hash Cond: (pas.id = r.passageiro_id)
  Buffers: shared hit=276
  ->  Seq Scan on passageiros pas  (cost=0.00..133.00 rows=5000 width=50) (actual time=0.010..0.239 rows=5000.00 loops=1)
        Buffers: shared hit=83
  ->  Hash  (cost=575.45..575.45 rows=757 width=10) (actual time=4.649..4.651 rows=761.00 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 40kB
        Buffers: shared hit=193
        ->  Hash Right Anti Join  (cost=438.95..575.45 rows=757 width=10) (actual time=4.455..4.552 rows=761.00 loops=1)
              Hash Cond: (b.passagem_id = p.id)
              Buffers: shared hit=193
              ->  Seq Scan on bagagens b  (cost=0.00..97.00 rows=5000 width=4) (actual time=0.020..0.231 rows=5000.00 loops=1)
                    Buffers: shared hit=47
              ->  Hash  (cost=413.01..413.01 rows=2075 width=14) (actual time=3.592..3.594 rows=2103.00 loops=1)
                    Buckets: 4096  Batches: 1  Memory Usage: 131kB
                    Buffers: shared hit=146
                    ->  Hash Join  (cost=279.51..413.01 rows=2075 width=14) (actual time=2.288..3.289 rows=2103.00 loops=1)
                          Hash Cond: (p.reserva_id = r.id)
                          Buffers: shared hit=146
                          ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=8) (actual time=0.007..0.235 rows=5000.00 loops=1)
                                Buffers: shared hit=44
                          ->  Hash  (cost=253.57..253.57 rows=2075 width=14) (actual time=2.267..2.268 rows=2103.00 loops=1)
                                Buckets: 4096  Batches: 1  Memory Usage: 129kB
                                Buffers: shared hit=102
                                ->  Hash Join  (cost=140.44..253.57 rows=2075 width=14) (actual time=1.116..1.991 rows=2103.00 loops=1)
                                      Hash Cond: (r.voo_id = v.id)
                                      Buffers: shared hit=102
                                      ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=12) (actual time=0.006..0.217 rows=5000.00 loops=1)
                                            Buffers: shared hit=50
                                      ->  Hash  (cost=114.50..114.50 rows=2075 width=10) (actual time=1.094..1.094 rows=2079.00 loops=1)
                                            Buckets: 4096  Batches: 1  Memory Usage: 122kB
                                            Buffers: shared hit=52
                                            ->  Seq Scan on voos v  (cost=0.00..114.50 rows=2075 width=10) (actual time=0.009..0.814 rows=2079.00 loops=1)
                                                  Filter: (preco_base > '1500'::numeric)
                                                  Rows Removed by Filter: 2921
                                                  Buffers: shared hit=52
Planning:
  Buffers: shared hit=48
Planning Time: 0.698 ms
Execution Time: 5.489 ms
```

---


### Query 17: Ranking de rotas mais lucrativas por país de destino
* **Tabelas:** voos, reservas, aeroportos, cidades, categorias_tarifa
* **Antipadrão:** Window function DENSE_RANK executada em joins planos amplos e ordenação ineficiente
* **Estratégia:** Agregar os custos e faturamento em subquery antes de juntar dados geográficos adicionais.

#### Comparação de Custo e Tempo
* **Custo Antes:** `1367.52..1380.02` | **Custo Depois:** `1042.67..1050.51` (**23.88% de redução**)
* **Tempo Antes:** `15.376 ms` | **Tempo Depois:** `11.848 ms`

#### Plano Antes:
```text
Sort  (cost=1367.52..1380.02 rows=5000 width=72) (actual time=14.506..14.608 rows=3138.00 loops=1)
  Sort Key: (dense_rank() OVER w1)
  Sort Method: quicksort  Memory: 304kB
  Buffers: shared hit=193
  ->  WindowAgg  (cost=972.84..1060.33 rows=5000 width=72) (actual time=12.343..13.960 rows=3138.00 loops=1)
        Window: w1 AS (ORDER BY (sum(r.preco_total)) ROWS UNBOUNDED PRECEDING)
        Storage: Memory  Maximum Storage: 17kB
        Buffers: shared hit=193
        ->  Sort  (cost=972.83..985.33 rows=5000 width=64) (actual time=12.322..12.459 rows=3138.00 loops=1)
              Sort Key: (sum(r.preco_total)) DESC
              Sort Method: quicksort  Memory: 280kB
              Buffers: shared hit=193
              ->  HashAggregate  (cost=603.13..665.63 rows=5000 width=64) (actual time=10.516..11.302 rows=3138.00 loops=1)
                    Group Key: v.numero_voo, pa.nome
                    Batches: 1  Memory Usage: 1425kB
                    Buffers: shared hit=193
                    ->  Hash Join  (cost=413.00..565.63 rows=5000 width=38) (actual time=2.888..8.032 rows=5000.00 loops=1)
                          Hash Cond: (c.pais_id = pa.id)
                          Buffers: shared hit=193
                          ->  Hash Join  (cost=380.50..519.95 rows=5000 width=16) (actual time=2.562..6.646 rows=5000.00 loops=1)
                                Hash Cond: (a.cidade_id = c.id)
                                Buffers: shared hit=183
                                ->  Hash Join  (cost=347.00..473.27 rows=5000 width=16) (actual time=2.317..5.432 rows=5000.00 loops=1)
                                      Hash Cond: (v.aeroporto_destino_id = a.id)
                                      Buffers: shared hit=172
                                      ->  Hash Join  (cost=164.50..277.64 rows=5000 width=16) (actual time=1.266..3.223 rows=5000.00 loops=1)
                                            Hash Cond: (r.voo_id = v.id)
                                            Buffers: shared hit=102
                                            ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=10) (actual time=0.008..0.349 rows=5000.00 loops=1)
                                                  Buffers: shared hit=50
                                            ->  Hash  (cost=102.00..102.00 rows=5000 width=14) (actual time=1.225..1.226 rows=5000.00 loops=1)
                                                  Buckets: 8192  Batches: 1  Memory Usage: 299kB
                                                  Buffers: shared hit=52
                                                  ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=14) (actual time=0.008..0.497 rows=5000.00 loops=1)
                                                        Buffers: shared hit=52
                                      ->  Hash  (cost=120.00..120.00 rows=5000 width=8) (actual time=1.020..1.021 rows=5000.00 loops=1)
                                            Buckets: 8192  Batches: 1  Memory Usage: 260kB
                                            Buffers: shared hit=70
                                            ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=8) (actual time=0.009..0.485 rows=5000.00 loops=1)
                                                  Buffers: shared hit=70
                                ->  Hash  (cost=21.00..21.00 rows=1000 width=8) (actual time=0.243..0.243 rows=1000.00 loops=1)
                                      Buckets: 1024  Batches: 1  Memory Usage: 48kB
                                      Buffers: shared hit=11
                                      ->  Seq Scan on cidades c  (cost=0.00..21.00 rows=1000 width=8) (actual time=0.011..0.135 rows=1000.00 loops=1)
                                            Buffers: shared hit=11
                          ->  Hash  (cost=20.00..20.00 rows=1000 width=30) (actual time=0.318..0.318 rows=1000.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 71kB
                                Buffers: shared hit=10
                                ->  Seq Scan on paises pa  (cost=0.00..20.00 rows=1000 width=30) (actual time=0.020..0.139 rows=1000.00 loops=1)
                                      Buffers: shared hit=10
Planning:
  Buffers: shared hit=57
Planning Time: 0.684 ms
Execution Time: 15.376 ms
```

#### Plano Depois:
```text
Sort  (cost=1042.67..1050.51 rows=3138 width=72) (actual time=11.259..11.369 rows=3138.00 loops=1)
  Sort Key: (dense_rank() OVER w1)
  Sort Method: quicksort  Memory: 304kB
  Buffers: shared hit=193
  ->  WindowAgg  (cost=805.52..860.42 rows=3138 width=72) (actual time=9.171..10.715 rows=3138.00 loops=1)
        Window: w1 AS (ORDER BY v_rec.receita ROWS UNBOUNDED PRECEDING)
        Storage: Memory  Maximum Storage: 17kB
        Buffers: shared hit=193
        ->  Sort  (cost=805.50..813.35 rows=3138 width=64) (actual time=9.163..9.331 rows=3138.00 loops=1)
              Sort Key: v_rec.receita DESC
              Sort Method: quicksort  Memory: 280kB
              Buffers: shared hit=193
              ->  Hash Join  (cost=483.33..623.26 rows=3138 width=64) (actual time=5.208..8.212 rows=3138.00 loops=1)
                    Hash Cond: (c.pais_id = pa.id)
                    Buffers: shared hit=193
                    ->  Hash Join  (cost=450.83..582.49 rows=3138 width=42) (actual time=4.907..7.309 rows=3138.00 loops=1)
                          Hash Cond: (a.cidade_id = c.id)
                          Buffers: shared hit=183
                          ->  Hash Join  (cost=417.33..540.71 rows=3138 width=42) (actual time=4.667..6.507 rows=3138.00 loops=1)
                                Hash Cond: (v.aeroporto_destino_id = a.id)
                                Buffers: shared hit=172
                                ->  Hash Join  (cost=234.83..349.97 rows=3138 width=42) (actual time=3.301..4.506 rows=3138.00 loops=1)
                                      Hash Cond: (v.id = v_rec.voo_id)
                                      Buffers: shared hit=102
                                      ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=14) (actual time=0.019..0.272 rows=5000.00 loops=1)
                                            Buffers: shared hit=52
                                      ->  Hash  (cost=195.60..195.60 rows=3138 width=36) (actual time=3.266..3.267 rows=3138.00 loops=1)
                                            Buckets: 4096  Batches: 1  Memory Usage: 168kB
                                            Buffers: shared hit=50
                                            ->  Subquery Scan on v_rec  (cost=125.00..195.60 rows=3138 width=36) (actual time=1.961..2.867 rows=3138.00 loops=1)
                                                  Buffers: shared hit=50
                                                  ->  HashAggregate  (cost=125.00..164.22 rows=3138 width=36) (actual time=1.960..2.654 rows=3138.00 loops=1)
                                                        Group Key: reservas.voo_id
                                                        Batches: 1  Memory Usage: 1233kB
                                                        Buffers: shared hit=50
                                                        ->  Seq Scan on reservas  (cost=0.00..100.00 rows=5000 width=10) (actual time=0.008..0.232 rows=5000.00 loops=1)
                                                              Buffers: shared hit=50
                                ->  Hash  (cost=120.00..120.00 rows=5000 width=8) (actual time=1.333..1.333 rows=5000.00 loops=1)
                                      Buckets: 8192  Batches: 1  Memory Usage: 260kB
                                      Buffers: shared hit=70
                                      ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=8) (actual time=0.013..0.558 rows=5000.00 loops=1)
                                            Buffers: shared hit=70
                          ->  Hash  (cost=21.00..21.00 rows=1000 width=8) (actual time=0.236..0.236 rows=1000.00 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 48kB
                                Buffers: shared hit=11
                                ->  Seq Scan on cidades c  (cost=0.00..21.00 rows=1000 width=8) (actual time=0.010..0.117 rows=1000.00 loops=1)
                                      Buffers: shared hit=11
                    ->  Hash  (cost=20.00..20.00 rows=1000 width=30) (actual time=0.298..0.299 rows=1000.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 71kB
                          Buffers: shared hit=10
                          ->  Seq Scan on paises pa  (cost=0.00..20.00 rows=1000 width=30) (actual time=0.014..0.106 rows=1000.00 loops=1)
                                Buffers: shared hit=10
Planning:
  Buffers: shared hit=36
Planning Time: 0.623 ms
Execution Time: 11.848 ms
```

---


### Query 18: Número de escalas por funcionário, cargo e aeroporto base
* **Tabelas:** funcionarios, escalas_tripulacao, voos, cargos_funcionarios, aeroportos
* **Antipadrão:** Agrupamento com excessivas colunas redundantes e Joins executados antes do GROUP BY
* **Estratégia:** Pré-agrupar escalas por ID do funcionário, depois executar os JOINs apenas para os IDs agregados.

#### Comparação de Custo e Tempo
* **Custo Antes:** `776.59..826.59` | **Custo Depois:** `444.08..603.75` (**26.96% de redução**)
* **Tempo Antes:** `12.391 ms` | **Tempo Depois:** `7.010 ms`

#### Plano Antes:
```text
HashAggregate  (cost=776.59..826.59 rows=5000 width=86) (actual time=11.440..11.954 rows=3141.00 loops=1)
  Group Key: f.id, c.nome, a.id
  Batches: 1  Memory Usage: 665kB
  Buffers: shared hit=264
  ->  Hash Join  (cost=584.00..726.59 rows=5000 width=82) (actual time=4.726..9.541 rows=5000.00 loops=1)
        Hash Cond: (f.aeroporto_base_id = a.id)
        Buffers: shared hit=264
        ->  Hash Join  (cost=401.50..530.95 rows=5000 width=60) (actual time=2.692..6.380 rows=5000.00 loops=1)
              Hash Cond: (f.cargo_id = c.id)
              Buffers: shared hit=194
              ->  Hash Join  (cost=357.00..473.27 rows=5000 width=31) (actual time=2.411..5.077 rows=5000.00 loops=1)
                    Hash Cond: (et.voo_id = v.id)
                    Buffers: shared hit=172
                    ->  Hash Join  (cost=192.50..295.64 rows=5000 width=31) (actual time=1.484..3.088 rows=5000.00 loops=1)
                          Hash Cond: (et.funcionario_id = f.id)
                          Buffers: shared hit=120
                          ->  Seq Scan on escalas_tripulacao et  (cost=0.00..90.00 rows=5000 width=8) (actual time=0.010..0.290 rows=5000.00 loops=1)
                                Buffers: shared hit=40
                          ->  Hash  (cost=130.00..130.00 rows=5000 width=27) (actual time=1.440..1.441 rows=5000.00 loops=1)
                                Buckets: 8192  Batches: 1  Memory Usage: 365kB
                                Buffers: shared hit=80
                                ->  Seq Scan on funcionarios f  (cost=0.00..130.00 rows=5000 width=27) (actual time=0.006..0.579 rows=5000.00 loops=1)
                                      Buffers: shared hit=80
                    ->  Hash  (cost=102.00..102.00 rows=5000 width=4) (actual time=0.896..0.897 rows=5000.00 loops=1)
                          Buckets: 8192  Batches: 1  Memory Usage: 240kB
                          Buffers: shared hit=52
                          ->  Seq Scan on voos v  (cost=0.00..102.00 rows=5000 width=4) (actual time=0.012..0.359 rows=5000.00 loops=1)
                                Buffers: shared hit=52
              ->  Hash  (cost=32.00..32.00 rows=1000 width=33) (actual time=0.275..0.276 rows=1000.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 74kB
                    Buffers: shared hit=22
                    ->  Seq Scan on cargos_funcionarios c  (cost=0.00..32.00 rows=1000 width=33) (actual time=0.027..0.130 rows=1000.00 loops=1)
                          Buffers: shared hit=22
        ->  Hash  (cost=120.00..120.00 rows=5000 width=26) (actual time=2.000..2.000 rows=5000.00 loops=1)
              Buckets: 8192  Batches: 1  Memory Usage: 358kB
              Buffers: shared hit=70
              ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=26) (actual time=0.013..0.873 rows=5000.00 loops=1)
                    Buffers: shared hit=70
Planning:
  Buffers: shared hit=48
Planning Time: 0.879 ms
Execution Time: 12.391 ms
```

#### Plano Depois:
```text
Hash Join  (cost=444.08..603.75 rows=3141 width=74) (actual time=3.908..6.721 rows=3141.00 loops=1)
  Hash Cond: (f.aeroporto_base_id = a.id)
  Buffers: shared hit=212
  ->  Hash Join  (cost=261.58..413.00 rows=3141 width=56) (actual time=2.455..4.476 rows=3141.00 loops=1)
        Hash Cond: (f.cargo_id = c.id)
        Buffers: shared hit=142
        ->  Hash Join  (cost=217.08..360.22 rows=3141 width=31) (actual time=2.189..3.588 rows=3141.00 loops=1)
              Hash Cond: (f.id = et_stats.funcionario_id)
              Buffers: shared hit=120
              ->  Seq Scan on funcionarios f  (cost=0.00..130.00 rows=5000 width=27) (actual time=0.014..0.305 rows=5000.00 loops=1)
                    Buffers: shared hit=80
              ->  Hash  (cost=177.82..177.82 rows=3141 width=12) (actual time=2.155..2.157 rows=3141.00 loops=1)
                    Buckets: 4096  Batches: 1  Memory Usage: 167kB
                    Buffers: shared hit=40
                    ->  Subquery Scan on et_stats  (cost=115.00..177.82 rows=3141 width=12) (actual time=1.213..1.770 rows=3141.00 loops=1)
                          Buffers: shared hit=40
                          ->  HashAggregate  (cost=115.00..146.41 rows=3141 width=12) (actual time=1.211..1.557 rows=3141.00 loops=1)
                                Group Key: escalas_tripulacao.funcionario_id
                                Batches: 1  Memory Usage: 217kB
                                Buffers: shared hit=40
                                ->  Seq Scan on escalas_tripulacao  (cost=0.00..90.00 rows=5000 width=8) (actual time=0.009..0.213 rows=5000.00 loops=1)
                                      Buffers: shared hit=40
        ->  Hash  (cost=32.00..32.00 rows=1000 width=33) (actual time=0.260..0.261 rows=1000.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 74kB
              Buffers: shared hit=22
              ->  Seq Scan on cargos_funcionarios c  (cost=0.00..32.00 rows=1000 width=33) (actual time=0.025..0.124 rows=1000.00 loops=1)
                    Buffers: shared hit=22
  ->  Hash  (cost=120.00..120.00 rows=5000 width=26) (actual time=1.363..1.363 rows=5000.00 loops=1)
        Buckets: 8192  Batches: 1  Memory Usage: 358kB
        Buffers: shared hit=70
        ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=26) (actual time=0.013..0.625 rows=5000.00 loops=1)
              Buffers: shared hit=70
Planning:
  Buffers: shared hit=24
Planning Time: 0.476 ms
Execution Time: 7.010 ms
```

---


### Query 19: Embarques realizados agrupados por terminal e mês
* **Tabelas:** cartoes_embarque, passagens, reservas, voos, terminais, aeroportos
* **Antipadrão:** Uso indevido da função TO_CHAR no WHERE e GROUP BY, impedindo o uso de índices de data
* **Estratégia:** Utilizar comparação por faixa de datas sargable (>= e <) no WHERE e DATE_TRUNC no GROUP BY.

#### Comparação de Custo e Tempo
* **Custo Antes:** `158.21..158.77` | **Custo Depois:** `184.51..211.24` (**-33.05% de redução**)
* **Tempo Antes:** `8.547 ms` | **Tempo Depois:** `1.920 ms`

#### Plano Antes:
```text
GroupAggregate  (cost=158.21..158.77 rows=25 width=46) (actual time=8.061..8.507 rows=396.00 loops=1)
  Group Key: t.nome, (to_char(ce.hora_embarque, 'YYYY-MM'::text))
  Buffers: shared hit=60
  ->  Sort  (cost=158.21..158.27 rows=25 width=42) (actual time=8.053..8.124 rows=2134.00 loops=1)
        Sort Key: t.nome, (to_char(ce.hora_embarque, 'YYYY-MM'::text))
        Sort Method: quicksort  Memory: 169kB
        Buffers: shared hit=60
        ->  Hash Join  (cost=30.50..157.63 rows=25 width=42) (actual time=1.169..4.079 rows=2134.00 loops=1)
              Hash Cond: (ce.terminal_id = t.id)
              Buffers: shared hit=60
              ->  Seq Scan on cartoes_embarque ce  (cost=0.00..127.00 rows=25 width=16) (actual time=0.918..2.760 rows=2134.00 loops=1)
                    Filter: (to_char(hora_embarque, 'YYYY'::text) = '2026'::text)
                    Rows Removed by Filter: 2866
                    Buffers: shared hit=52
              ->  Hash  (cost=18.00..18.00 rows=1000 width=10) (actual time=0.241..0.242 rows=1000.00 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 50kB
                    Buffers: shared hit=8
                    ->  Seq Scan on terminais t  (cost=0.00..18.00 rows=1000 width=10) (actual time=0.019..0.104 rows=1000.00 loops=1)
                          Buffers: shared hit=8
Planning:
  Buffers: shared hit=12
Planning Time: 0.230 ms
Execution Time: 8.547 ms
```

#### Plano Depois:
```text
HashAggregate  (cost=184.51..211.24 rows=2138 width=22) (actual time=1.803..1.860 rows=396.00 loops=1)
  Group Key: t.nome, date_trunc('month'::text, ce.hora_embarque)
  Batches: 1  Memory Usage: 121kB
  Buffers: shared hit=60
  ->  Hash Join  (cost=30.50..168.48 rows=2138 width=18) (actual time=0.229..1.367 rows=2134.00 loops=1)
        Hash Cond: (ce.terminal_id = t.id)
        Buffers: shared hit=60
        ->  Seq Scan on cartoes_embarque ce  (cost=0.00..127.00 rows=2138 width=16) (actual time=0.010..0.487 rows=2134.00 loops=1)
              Filter: ((hora_embarque >= '2025-12-31 21:00:00-03'::timestamp with time zone) AND (hora_embarque < '2026-12-31 21:00:00-03'::timestamp with time zone))
              Rows Removed by Filter: 2866
              Buffers: shared hit=52
        ->  Hash  (cost=18.00..18.00 rows=1000 width=10) (actual time=0.214..0.214 rows=1000.00 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 50kB
              Buffers: shared hit=8
              ->  Seq Scan on terminais t  (cost=0.00..18.00 rows=1000 width=10) (actual time=0.007..0.092 rows=1000.00 loops=1)
                    Buffers: shared hit=8
Planning:
  Buffers: shared hit=12
Planning Time: 0.222 ms
Execution Time: 1.920 ms
```

---


### Query 20: Dashboard executivo consolidado (Faturamento, Total de Bagagens) de voos caros
* **Tabelas:** voos, aeroportos, reservas, passagens, bagagens
* **Antipadrão:** Uso indevido da palavra-chave MATERIALIZED em CTEs (impede Inline CTE)
* **Estratégia:** Remover MATERIALIZED permitindo que o planejador de consultas faça inline e aplique pushdown do filtro.

#### Comparação de Custo e Tempo
* **Custo Antes:** `1056.71..1140.43` | **Custo Depois:** `986.11..1077.67` (**5.5% de redução**)
* **Tempo Antes:** `12.901 ms` | **Tempo Depois:** `12.180 ms`

#### Plano Antes:
```text
Hash Join  (cost=1056.71..1140.43 rows=1033 width=50) (actual time=11.280..12.500 rows=1034.00 loops=1)
  Hash Cond: (v.aeroporto_origem_id = a.id)
  Buffers: shared hit=313
  CTE v_receita
    ->  HashAggregate  (cost=125.00..164.22 rows=3138 width=36) (actual time=2.020..2.713 rows=3138.00 loops=1)
          Group Key: r.voo_id
          Batches: 1  Memory Usage: 1233kB
          Buffers: shared hit=50
          ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=10) (actual time=0.017..0.247 rows=5000.00 loops=1)
                Buffers: shared hit=50
  CTE v_bagagens
    ->  HashAggregate  (cost=467.27..498.65 rows=3138 width=12) (actual time=5.308..5.567 rows=2325.00 loops=1)
          Group Key: r_1.voo_id
          Batches: 1  Memory Usage: 217kB
          Buffers: shared hit=141
          ->  Hash Join  (cost=319.00..442.27 rows=5000 width=8) (actual time=2.131..4.466 rows=5000.00 loops=1)
                Hash Cond: (p.reserva_id = r_1.id)
                Buffers: shared hit=141
                ->  Hash Join  (cost=156.50..266.64 rows=5000 width=8) (actual time=1.110..2.438 rows=5000.00 loops=1)
                      Hash Cond: (b.passagem_id = p.id)
                      Buffers: shared hit=91
                      ->  Seq Scan on bagagens b  (cost=0.00..97.00 rows=5000 width=8) (actual time=0.012..0.237 rows=5000.00 loops=1)
                            Buffers: shared hit=47
                      ->  Hash  (cost=94.00..94.00 rows=5000 width=8) (actual time=1.063..1.064 rows=5000.00 loops=1)
                            Buckets: 8192  Batches: 1  Memory Usage: 260kB
                            Buffers: shared hit=44
                            ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=8) (actual time=0.009..0.440 rows=5000.00 loops=1)
                                  Buffers: shared hit=44
                ->  Hash  (cost=100.00..100.00 rows=5000 width=8) (actual time=0.989..0.990 rows=5000.00 loops=1)
                      Buckets: 8192  Batches: 1  Memory Usage: 260kB
                      Buffers: shared hit=50
                      ->  Seq Scan on reservas r_1  (cost=0.00..100.00 rows=5000 width=8) (actual time=0.013..0.439 rows=5000.00 loops=1)
                            Buffers: shared hit=50
  ->  Hash Right Join  (cost=211.33..292.34 rows=1033 width=50) (actual time=10.059..11.041 rows=1034.00 loops=1)
        Hash Cond: (bag.voo_id = v.id)
        Buffers: shared hit=243
        ->  CTE Scan on v_bagagens bag  (cost=0.00..62.76 rows=3138 width=12) (actual time=5.309..5.957 rows=2325.00 loops=1)
              Storage: Memory  Maximum Storage: 123kB
              Buffers: shared hit=141
        ->  Hash  (cost=198.42..198.42 rows=1033 width=46) (actual time=4.737..4.738 rows=1034.00 loops=1)
              Buckets: 2048  Batches: 1  Memory Usage: 70kB
              Buffers: shared hit=102
              ->  Hash Right Join  (cost=127.41..198.42 rows=1033 width=46) (actual time=2.950..4.585 rows=1034.00 loops=1)
                    Hash Cond: (rec.voo_id = v.id)
                    Buffers: shared hit=102
                    ->  CTE Scan on v_receita rec  (cost=0.00..62.76 rows=3138 width=36) (actual time=2.023..3.254 rows=3138.00 loops=1)
                          Storage: Memory  Maximum Storage: 155kB
                          Buffers: shared hit=50
                    ->  Hash  (cost=114.50..114.50 rows=1033 width=14) (actual time=0.914..0.915 rows=1034.00 loops=1)
                          Buckets: 2048  Batches: 1  Memory Usage: 65kB
                          Buffers: shared hit=52
                          ->  Seq Scan on voos v  (cost=0.00..114.50 rows=1033 width=14) (actual time=0.017..0.779 rows=1034.00 loops=1)
                                Filter: (preco_base > '2000'::numeric)
                                Rows Removed by Filter: 3966
                                Buffers: shared hit=52
  ->  Hash  (cost=120.00..120.00 rows=5000 width=8) (actual time=1.211..1.211 rows=5000.00 loops=1)
        Buckets: 8192  Batches: 1  Memory Usage: 260kB
        Buffers: shared hit=70
        ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=8) (actual time=0.011..0.498 rows=5000.00 loops=1)
              Buffers: shared hit=70
Planning:
  Buffers: shared hit=36
Planning Time: 0.670 ms
Execution Time: 12.901 ms
```

#### Plano Depois:
```text
Hash Join  (cost=986.11..1077.67 rows=1033 width=50) (actual time=10.438..11.754 rows=1034.00 loops=1)
  Hash Cond: (v.aeroporto_origem_id = a.id)
  Buffers: shared hit=313
  ->  Hash Right Join  (cost=803.61..892.46 rows=1033 width=50) (actual time=9.219..10.300 rows=1034.00 loops=1)
        Hash Cond: (r.voo_id = v.id)
        Buffers: shared hit=243
        ->  HashAggregate  (cost=125.00..164.22 rows=3138 width=36) (actual time=2.097..2.787 rows=3138.00 loops=1)
              Group Key: r.voo_id
              Batches: 1  Memory Usage: 1233kB
              Buffers: shared hit=50
              ->  Seq Scan on reservas r  (cost=0.00..100.00 rows=5000 width=10) (actual time=0.020..0.255 rows=5000.00 loops=1)
                    Buffers: shared hit=50
        ->  Hash  (cost=665.69..665.69 rows=1033 width=22) (actual time=7.108..7.111 rows=1034.00 loops=1)
              Buckets: 2048  Batches: 1  Memory Usage: 69kB
              Buffers: shared hit=193
              ->  Hash Right Join  (cost=594.68..665.69 rows=1033 width=22) (actual time=6.416..6.961 rows=1034.00 loops=1)
                    Hash Cond: (r_1.voo_id = v.id)
                    Buffers: shared hit=193
                    ->  HashAggregate  (cost=467.27..498.65 rows=3138 width=12) (actual time=5.595..5.849 rows=2325.00 loops=1)
                          Group Key: r_1.voo_id
                          Batches: 1  Memory Usage: 217kB
                          Buffers: shared hit=141
                          ->  Hash Join  (cost=319.00..442.27 rows=5000 width=8) (actual time=2.057..4.660 rows=5000.00 loops=1)
                                Hash Cond: (p.reserva_id = r_1.id)
                                Buffers: shared hit=141
                                ->  Hash Join  (cost=156.50..266.64 rows=5000 width=8) (actual time=1.024..2.512 rows=5000.00 loops=1)
                                      Hash Cond: (b.passagem_id = p.id)
                                      Buffers: shared hit=91
                                      ->  Seq Scan on bagagens b  (cost=0.00..97.00 rows=5000 width=8) (actual time=0.010..0.254 rows=5000.00 loops=1)
                                            Buffers: shared hit=47
                                      ->  Hash  (cost=94.00..94.00 rows=5000 width=8) (actual time=0.969..0.969 rows=5000.00 loops=1)
                                            Buckets: 8192  Batches: 1  Memory Usage: 260kB
                                            Buffers: shared hit=44
                                            ->  Seq Scan on passagens p  (cost=0.00..94.00 rows=5000 width=8) (actual time=0.010..0.422 rows=5000.00 loops=1)
                                                  Buffers: shared hit=44
                                ->  Hash  (cost=100.00..100.00 rows=5000 width=8) (actual time=1.004..1.004 rows=5000.00 loops=1)
                                      Buckets: 8192  Batches: 1  Memory Usage: 260kB
                                      Buffers: shared hit=50
                                      ->  Seq Scan on reservas r_1  (cost=0.00..100.00 rows=5000 width=8) (actual time=0.006..0.436 rows=5000.00 loops=1)
                                            Buffers: shared hit=50
                    ->  Hash  (cost=114.50..114.50 rows=1033 width=14) (actual time=0.810..0.810 rows=1034.00 loops=1)
                          Buckets: 2048  Batches: 1  Memory Usage: 65kB
                          Buffers: shared hit=52
                          ->  Seq Scan on voos v  (cost=0.00..114.50 rows=1033 width=14) (actual time=0.009..0.683 rows=1034.00 loops=1)
                                Filter: (preco_base > '2000'::numeric)
                                Rows Removed by Filter: 3966
                                Buffers: shared hit=52
  ->  Hash  (cost=120.00..120.00 rows=5000 width=8) (actual time=1.187..1.187 rows=5000.00 loops=1)
        Buckets: 8192  Batches: 1  Memory Usage: 260kB
        Buffers: shared hit=70
        ->  Seq Scan on aeroportos a  (cost=0.00..120.00 rows=5000 width=8) (actual time=0.019..0.466 rows=5000.00 loops=1)
              Buffers: shared hit=70
Planning:
  Buffers: shared hit=36
Planning Time: 0.743 ms
Execution Time: 12.180 ms
```

---
