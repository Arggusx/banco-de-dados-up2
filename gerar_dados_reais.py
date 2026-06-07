"""
gerar_dados_reais.py — Pipeline de dados para benchmark de Aeroporto
=====================================================================
Gera dados realistas com Faker, estrutura com pandas, e injeta
DIRETAMENTE no PostgreSQL via psycopg2 COPY (bulk load).

Dependencias:
    pip install faker pandas psycopg2-binary

Variaveis de ambiente (opcionais — usa defaults se nao definidas):
    PGHOST       (default: localhost)
    PGPORT       (default: 5432)
    PGDATABASE   (default: aeroporto_benchmark)
    PGUSER       (default: postgres)
    PGPASSWORD   (default: 1234)

Uso:
    python gerar_dados_reais.py
"""

import io
import os
import random
import string
import sys
import time
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from itertools import product
from pathlib import Path

import pandas as pd
import psycopg2
from faker import Faker

# =====================================================================
# CONFIGURACAO
# =====================================================================

DB_CONFIG = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": int(os.getenv("PGPORT", "5432")),
    "dbname": os.getenv("PGDATABASE", "aeroporto"),
    "user": os.getenv("PGUSER", "postgres"),
    "password": os.getenv("PGPASSWORD", "12345678"),
}

LOOKUP_ROWS = 1_000   # 10 tabelas basicas
CORE_ROWS   = 5_000   # 10 tabelas de negocio
TOTAL_EXPECTED = 10 * LOOKUP_ROWS + 10 * CORE_ROWS  # 60.000

# Diretorio temporario para CSVs intermediarios (sera limpo ao final)
BASE_DIR = Path(__file__).resolve().parent
TEMP_CSV_DIR = BASE_DIR / "_temp_csv_carga"

fake = Faker(["pt_BR", "en_US", "es_ES", "fr_FR", "de_DE"])
Faker.seed(42)
random.seed(42)


# =====================================================================
# FUNCOES AUXILIARES
# =====================================================================

def clip(value, max_len):
    """Trunca string e remove quebras de linha."""
    if value is None:
        return None
    return str(value).replace("\n", " ").replace("\r", " ")[:max_len]


def money(min_val, max_val):
    return f"{random.uniform(min_val, max_val):.2f}"


def iso_dt(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S+00")


def random_date(start_year, end_year, max_today=False):
    start = date(start_year, 1, 1)
    end = date(end_year, 12, 31)
    if max_today:
        hoje = date.today()
        if end > hoje:
            end = hoje
    return start + timedelta(days=random.randint(0, (end - start).days))


def random_timestamp(start_year=2025, end_year=2027):
    d = random_date(start_year, end_year)
    return datetime(d.year, d.month, d.day,
                    random.randint(0, 23), random.randint(0, 59),
                    tzinfo=timezone.utc)


def code_sequence(length, alphabet=string.ascii_uppercase):
    for chars in product(alphabet, repeat=length):
        yield "".join(chars)


def base36_sequence(length):
    alphabet = string.ascii_uppercase + string.digits
    for chars in product(alphabet, repeat=length):
        yield "".join(chars)


# =====================================================================
# GERADORES DE DADOS (retornam DataFrames pandas)
# =====================================================================

def gerar_paises():
    iso2 = base36_sequence(2)
    iso3 = base36_sequence(3)
    continentes = [
        "EUROPA", "ASIA", "AFRICA", "AMERICA_DO_NORTE",
        "AMERICA_DO_SUL", "OCEANIA", "ANTARTICA",
    ]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"{clip(fake.country(), 80)} Benchmark {i:04d}",
            "codigo_iso2": next(iso2),
            "codigo_iso3": next(iso3),
            "continente": random.choice(continentes),
        })
    return pd.DataFrame(rows)


def gerar_cidades():
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"{clip(fake.city(), 90)} {i:04d}",
            "pais_id": random.randint(1, LOOKUP_ROWS),
            "estado_provincia": clip(fake.state(), 90),
            "populacao": random.randint(25_000, 25_000_000),
            "latitude": f"{random.uniform(-60, 70):.6f}",
            "longitude": f"{random.uniform(-170, 170):.6f}",
        })
    return pd.DataFrame(rows)


def gerar_fabricantes():
    bases = ["Airbus", "Boeing", "Embraer", "ATR", "Bombardier", "Cessna", "Gulfstream"]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"{random.choice(bases)} Benchmark Works {i:04d}",
            "pais_origem_id": random.randint(1, LOOKUP_ROWS),
            "ano_fundacao": random.randint(1900, 2026),
            "website": f"https://fabricante-{i:04d}.example.com",
            "ativo": random.choice([True, True, True, False]),
        })
    return pd.DataFrame(rows)


def gerar_modelos_aeronave():
    families = ["A", "B", "E", "CRJ", "ATR", "G", "C"]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"{random.choice(families)}-{random.randint(100, 999)}-{i:04d}",
            "fabricante_id": random.randint(1, LOOKUP_ROWS),
            "capacidade_passageiros": random.randint(40, 420),
            "alcance_km": random.randint(800, 15_500),
            "peso_max_decolagem_kg": f"{random.uniform(18_000, 380_000):.2f}",
            "ano_primeiro_voo": random.randint(1950, 2026),
            "envergadura_metros": f"{random.uniform(15, 80):.2f}",
        })
    return pd.DataFrame(rows)


def gerar_cargos_funcionarios():
    cargos = [
        "Comandante", "Copiloto", "Comissario", "Agente de Gate",
        "Mecanico", "Analista Operacional", "Despachante",
        "Supervisor de Pista", "Seguranca", "Coordenador de Torre",
    ]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        min_s = Decimal(random.randint(2_000, 18_000))
        max_s = min_s + Decimal(random.randint(1_500, 25_000))
        rows.append({
            "id": i,
            "nome": f"{random.choice(cargos)} {i:04d}",
            "descricao": clip(fake.sentence(nb_words=10), 250),
            "nivel_acesso": random.randint(1, 10),
            "salario_min": f"{min_s:.2f}",
            "salario_max": f"{max_s:.2f}",
        })
    return pd.DataFrame(rows)


def gerar_status_voo():
    bases = ["PROGRAMADO", "EMBARQUE", "TAXIANDO", "EM_VOO",
             "ATRASADO", "CANCELADO", "CONCLUIDO"]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "codigo": f"ST{i:04d}",
            "descricao": f"{random.choice(bases)} - variacao operacional {i:04d}",
            "cor_hex": f"#{random.randint(0, 0xFFFFFF):06X}",
            "ordem_exibicao": i,
        })
    return pd.DataFrame(rows)


def gerar_categorias_tarifa():
    bases = ["LIGHT", "STANDARD", "FLEX", "BUSINESS", "FIRST"]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"{random.choice(bases)}_{i:04d}",
            "descricao": clip(fake.sentence(nb_words=12), 250),
            "multiplicador_preco": f"{random.uniform(0.75, 3.80):.2f}",
            "bagagem_inclusa_kg": random.randint(0, 64),
            "prioridade_embarque": random.randint(1, 5),
        })
    return pd.DataFrame(rows)


def gerar_tipos_bagagem():
    bases = ["MAO", "PORAO", "ESPECIAL", "ESPORTIVA", "OVERSIZED", "FRAGIL"]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"{random.choice(bases)}_{i:04d}",
            "descricao": clip(fake.sentence(nb_words=10), 250),
            "peso_max_kg": f"{random.uniform(8, 64):.2f}",
            "dimensoes_max_cm": f"{random.randint(40,120)}x{random.randint(30,90)}x{random.randint(20,70)}",
            "taxa_extra": money(0, 650),
        })
    return pd.DataFrame(rows)


def gerar_fornecedores():
    servicos = [
        "CATERING", "COMBUSTIVEL", "LIMPEZA", "MANUTENCAO", "SEGURANCA",
        "HANDLING", "TRANSPORTE", "TECNOLOGIA", "LOGISTICA", "CONSULTORIA",
    ]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"{clip(fake.company(), 120)} {i:04d}",
            "pais_id": random.randint(1, LOOKUP_ROWS),
            "tipo_servico": random.choice(servicos),
            "telefone": clip(fake.phone_number(), 30),
            "email": f"fornecedor{i:04d}@example.com",
            "cnpj_vat": f"VAT{i:010d}",
            "ativo": random.choice([True, True, True, False]),
            "data_contrato": random_date(2010, 2026).isoformat(),
        })
    return pd.DataFrame(rows)


def gerar_terminais():
    tipos = ["DOMESTICO", "INTERNACIONAL", "MISTO", "CARGA"]
    rows = []
    for i in range(1, LOOKUP_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"T{i:04d}",
            "aeroporto_id": i,  # sera mapeado para aeroportos.id (1..LOOKUP_ROWS subset de CORE_ROWS)
            "capacidade_gates": random.randint(4, 80),
            "tipo": random.choice(tipos),
            "ativo": random.choice([True, True, True, False]),
        })
    return pd.DataFrame(rows)


# --- TABELAS CORE (5.000 registros cada) ---

def gerar_aeroportos():
    iata_codes = code_sequence(3)
    icao_codes = code_sequence(4)
    rows = []
    for i in range(1, CORE_ROWS + 1):
        rows.append({
            "id": i,
            "nome": f"Aeroporto Internacional {clip(fake.city(), 80)} {i:04d}",
            "codigo_iata": next(iata_codes),
            "codigo_icao": next(icao_codes),
            "cidade_id": random.randint(1, LOOKUP_ROWS),
            "latitude": f"{random.uniform(-60, 70):.6f}",
            "longitude": f"{random.uniform(-170, 170):.6f}",
            "altitude_metros": random.randint(0, 4_500),
            "fuso_horario": random.choice([
                "UTC", "America/Sao_Paulo", "Europe/Lisbon",
                "Europe/London", "America/New_York",
            ]),
            "ativo": random.choice([True, True, True, False]),
        })
    return pd.DataFrame(rows)


def gerar_aeronaves():
    matriculas = set()
    rows = []
    while len(rows) < CORE_ROWS:
        i = len(rows) + 1
        mat = f"PR-{''.join(random.choices(string.ascii_uppercase + string.digits, k=5))}"
        if mat in matriculas:
            continue
        matriculas.add(mat)
        rows.append({
            "id": i,
            "matricula": mat,
            "modelo_id": random.randint(1, LOOKUP_ROWS),
            "ano_fabricacao": random.randint(1990, 2026),
            "data_ultima_revisao": random_date(2023, 2026).isoformat(),
            "total_horas_voo": random.randint(0, 95_000),
            "ativa": random.choice([True, True, True, False]),
        })
    return pd.DataFrame(rows)


def gerar_passageiros():
    rows = []
    for i in range(1, CORE_ROWS + 1):
        rows.append({
            "id": i,
            "nome": clip(fake.first_name(), 100),
            "sobrenome": clip(fake.last_name(), 100),
            "email": f"passageiro{i:05d}@example.com",
            "telefone": clip(fake.phone_number(), 30),
            "data_nascimento": random_date(1940, 2012, max_today=True).isoformat(),
            "numero_passaporte": f"P{i:08d}",
            "nacionalidade_id": random.randint(1, LOOKUP_ROWS),
            "programa_fidelidade": random.choice(
                ["NENHUM", "SILVER", "GOLD", "PLATINUM", "BLACK"]
            ),
            "milhas_acumuladas": random.randint(0, 450_000),
        })
    return pd.DataFrame(rows)


def gerar_funcionarios(cargos_df):
    rows = []
    for i in range(1, CORE_ROWS + 1):
        cargo_id = random.randint(1, LOOKUP_ROWS)
        cargo = cargos_df.iloc[cargo_id - 1]
        sal_min = float(cargo["salario_min"])
        sal_max = float(cargo["salario_max"])
        salario = random.uniform(sal_min, sal_max)
        rows.append({
            "id": i,
            "nome": clip(fake.first_name(), 100),
            "sobrenome": clip(fake.last_name(), 100),
            "email": f"funcionario{i:05d}@airport.example.com",
            "cargo_id": cargo_id,
            "aeroporto_base_id": random.randint(1, CORE_ROWS),
            "data_contratacao": random_date(2005, 2026, max_today=True).isoformat(),
            "salario": f"{salario:.2f}",
            "ativo": random.choice([True, True, True, False]),
            "numero_identificacao": f"EMP{i:08d}",
        })
    return pd.DataFrame(rows)


def gerar_voos():
    rows = []
    for i in range(1, CORE_ROWS + 1):
        origem = random.randint(1, LOOKUP_ROWS)
        destino = random.randint(1, CORE_ROWS)
        while destino == origem:
            destino = random.randint(1, CORE_ROWS)
        partida = random_timestamp(2025, 2027)
        chegada = partida + timedelta(minutes=random.randint(45, 900))
        rows.append({
            "id": i,
            "numero_voo": f"{random.choice(['AZ','TP','LA','G3','AD','AF'])}{i:04d}",
            "aeronave_id": random.randint(1, CORE_ROWS),
            "aeroporto_origem_id": origem,
            "aeroporto_destino_id": destino,
            "data_partida": iso_dt(partida),
            "data_chegada": iso_dt(chegada),
            "status_id": random.randint(1, LOOKUP_ROWS),
            "preco_base": money(120, 3_500),
        })
    return pd.DataFrame(rows)


def gerar_escalas_tripulacao(voos_df):
    funcoes = [
        "COMANDANTE", "COPILOTO", "COMISSARIO",
        "COMISSARIO_CHEFE", "MECANICO_BORDO", "ENGENHEIRO_VOO",
    ]
    pairs = set()
    rows = []
    while len(rows) < CORE_ROWS:
        func_id = random.randint(1, CORE_ROWS)
        voo_id = random.randint(1, CORE_ROWS)
        if (func_id, voo_id) in pairs:
            continue
        pairs.add((func_id, voo_id))
        voo = voos_df.iloc[voo_id - 1]
        dt_str = voo["data_partida"].replace("+00", "+00:00")
        atrib = datetime.fromisoformat(dt_str).date() - timedelta(days=random.randint(1, 30))
        rows.append({
            "id": len(rows) + 1,
            "funcionario_id": func_id,
            "voo_id": voo_id,
            "funcao": random.choice(funcoes),
            "data_atribuicao": atrib.isoformat(),
            "confirmado": random.choice([True, True, True, False]),
        })
    return pd.DataFrame(rows)


def gerar_reservas(voos_df, categorias_df):
    statuses = ["CONFIRMADA", "CANCELADA", "PENDENTE", "EMBARCADA", "NO_SHOW"]
    rows = []
    for i in range(1, CORE_ROWS + 1):
        voo_id = i
        cat_id = random.randint(1, LOOKUP_ROWS)
        voo = voos_df.iloc[voo_id - 1]
        cat = categorias_df.iloc[cat_id - 1]
        dt_str = voo["data_partida"].replace("+00", "+00:00")
        partida = datetime.fromisoformat(dt_str)
        reserva_dt = partida - timedelta(days=random.randint(1, 180), hours=random.randint(0, 23))
        preco = Decimal(str(voo["preco_base"])) * Decimal(str(cat["multiplicador_preco"]))
        rows.append({
            "id": i,
            "passageiro_id": random.randint(1, CORE_ROWS),
            "voo_id": voo_id,
            "categoria_tarifa_id": cat_id,
            "codigo_reserva": f"{i:06X}"[-6:],
            "data_reserva": iso_dt(reserva_dt),
            "preco_total": f"{preco:.2f}",
            "status": random.choice(statuses),
        })
    return pd.DataFrame(rows)


def gerar_passagens(reservas_df):
    classes = ["ECONOMICA", "EXECUTIVA", "PRIMEIRA_CLASSE"]
    rows = []
    for i in range(1, CORE_ROWS + 1):
        reserva = reservas_df.iloc[i - 1]
        dt_str = reserva["data_reserva"].replace("+00", "+00:00")
        reserva_dt = datetime.fromisoformat(dt_str)
        emitida = reserva_dt + timedelta(minutes=random.randint(1, 240))
        rows.append({
            "id": i,
            "reserva_id": i,
            "numero_passagem": f"TKT{i:010d}",
            "assento": f"{random.randint(1, 39)}{random.choice('ABCDEF')}",
            "classe": random.choice(classes),
            "emitida_em": iso_dt(emitida),
        })
    return pd.DataFrame(rows)


def gerar_bagagens(tipos_df):
    statuses = ["DESPACHADA", "EM_TRANSITO", "ENTREGUE", "EXTRAVIADA", "DANIFICADA"]
    rows = []
    for i in range(1, CORE_ROWS + 1):
        tipo_id = random.randint(1, LOOKUP_ROWS)
        tipo = tipos_df.iloc[tipo_id - 1]
        max_peso = float(tipo["peso_max_kg"])
        rows.append({
            "id": i,
            "passagem_id": i,
            "tipo_bagagem_id": tipo_id,
            "peso_kg": f"{random.uniform(2.0, max_peso):.2f}",
            "codigo_rastreio": f"BAG{i:010d}",
            "status": random.choice(statuses),
        })
    return pd.DataFrame(rows)


def gerar_cartoes_embarque(reservas_df, voos_df):
    rows = []
    for i in range(1, CORE_ROWS + 1):
        reserva = reservas_df.iloc[i - 1]
        voo = voos_df.iloc[int(reserva["voo_id"]) - 1]
        dt_str = voo["data_partida"].replace("+00", "+00:00")
        partida = datetime.fromisoformat(dt_str)
        embarque = partida - timedelta(minutes=random.randint(30, 180))
        terminal_id = int(voo["aeroporto_origem_id"])
        # Garantir que terminal_id esta dentro do range de terminais (1..LOOKUP_ROWS)
        if terminal_id > LOOKUP_ROWS:
            terminal_id = random.randint(1, LOOKUP_ROWS)
        rows.append({
            "id": i,
            "passagem_id": i,
            "terminal_id": terminal_id,
            "gate": f"{random.choice(string.ascii_uppercase)}{random.randint(1,99):02d}",
            "zona_embarque": random.randint(1, 6),
            "hora_embarque": iso_dt(embarque),
            "codigo_barras": f"BRD{i:012d}",
            "impresso": random.choice([True, True, False]),
        })
    return pd.DataFrame(rows)


# =====================================================================
# ORQUESTRACAO — gera todos os DataFrames
# =====================================================================

def gerar_todos_dataframes():
    """Gera os 20 DataFrames na ordem correta de dependencias."""
    print("  [1/20] paises...")
    paises = gerar_paises()
    print("  [2/20] cidades...")
    cidades = gerar_cidades()
    print("  [3/20] fabricantes...")
    fabricantes = gerar_fabricantes()
    print("  [4/20] modelos_aeronave...")
    modelos = gerar_modelos_aeronave()
    print("  [5/20] cargos_funcionarios...")
    cargos = gerar_cargos_funcionarios()
    print("  [6/20] status_voo...")
    status = gerar_status_voo()
    print("  [7/20] categorias_tarifa...")
    categorias = gerar_categorias_tarifa()
    print("  [8/20] tipos_bagagem...")
    tipos = gerar_tipos_bagagem()
    print("  [9/20] fornecedores...")
    fornecedores = gerar_fornecedores()
    print("  [10/20] aeroportos...")
    aeroportos = gerar_aeroportos()
    print("  [11/20] terminais...")
    terminais = gerar_terminais()
    print("  [12/20] aeronaves...")
    aeronaves = gerar_aeronaves()
    print("  [13/20] passageiros...")
    passageiros = gerar_passageiros()
    print("  [14/20] funcionarios...")
    funcionarios = gerar_funcionarios(cargos)
    print("  [15/20] voos...")
    voos = gerar_voos()
    print("  [16/20] escalas_tripulacao...")
    escalas = gerar_escalas_tripulacao(voos)
    print("  [17/20] reservas...")
    reservas = gerar_reservas(voos, categorias)
    print("  [18/20] passagens...")
    passagens = gerar_passagens(reservas)
    print("  [19/20] bagagens...")
    bagagens = gerar_bagagens(tipos)
    print("  [20/20] cartoes_embarque...")
    cartoes = gerar_cartoes_embarque(reservas, voos)

    # Ordem de carga (respeita FKs)
    return [
        ("paises", paises),
        ("cidades", cidades),
        ("fabricantes", fabricantes),
        ("modelos_aeronave", modelos),
        ("cargos_funcionarios", cargos),
        ("status_voo", status),
        ("categorias_tarifa", categorias),
        ("tipos_bagagem", tipos),
        ("fornecedores", fornecedores),
        ("aeroportos", aeroportos),
        ("terminais", terminais),
        ("aeronaves", aeronaves),
        ("passageiros", passageiros),
        ("funcionarios", funcionarios),
        ("voos", voos),
        ("escalas_tripulacao", escalas),
        ("reservas", reservas),
        ("passagens", passagens),
        ("bagagens", bagagens),
        ("cartoes_embarque", cartoes),
    ]


# =====================================================================
# VALIDACAO DE VOLUMETRIA
# =====================================================================

LOOKUP_TABLES = {
    "paises", "cidades", "fabricantes", "modelos_aeronave",
    "cargos_funcionarios", "status_voo", "categorias_tarifa",
    "tipos_bagagem", "terminais", "fornecedores",
}

def validar_volumetria(tables):
    """Garante que cada tabela tem exatamente a quantidade esperada."""
    total = 0
    for name, df in tables:
        expected = LOOKUP_ROWS if name in LOOKUP_TABLES else CORE_ROWS
        actual = len(df)
        if actual != expected:
            raise ValueError(f"ERRO: {name} — esperado {expected}, gerado {actual}")
        total += actual
    if total != TOTAL_EXPECTED:
        raise ValueError(f"ERRO: total esperado {TOTAL_EXPECTED}, gerado {total}")
    print(f"  Validacao OK: {total:,} registros em 20 tabelas.")


# =====================================================================
# CARGA NO POSTGRESQL VIA COPY (bulk)
# =====================================================================

def carregar_tabela_copy(cur, table_name, df):
    """
    Usa o metodo copy_expert do psycopg2 para fazer bulk insert
    via COPY FROM STDIN (formato CSV). Muito mais rapido que INSERT.
    """
    columns = list(df.columns)
    col_list = ", ".join(columns)

    # Escreve o DataFrame em um buffer StringIO como CSV (sem header)
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False, lineterminator="\n")
    buffer.seek(0)

    copy_sql = (
        f"COPY {table_name} ({col_list}) "
        f"FROM STDIN WITH (FORMAT csv, DELIMITER ',', QUOTE '\"', ESCAPE '\"', NULL '')"
    )
    cur.copy_expert(copy_sql, buffer)


def salvar_csvs_temporarios(tables):
    """
    Salva CSVs intermediarios no diretorio temporario.
    Util para debug ou como fallback, mas serao removidos ao final.
    """
    TEMP_CSV_DIR.mkdir(exist_ok=True)
    for name, df in tables:
        path = TEMP_CSV_DIR / f"{name}.csv"
        df.to_csv(path, index=False, encoding="utf-8")
    print(f"  CSVs temporarios salvos em: {TEMP_CSV_DIR}")


def limpar_csvs_temporarios():
    """Remove o diretorio temporario de CSVs."""
    import shutil
    if TEMP_CSV_DIR.exists():
        shutil.rmtree(TEMP_CSV_DIR)
        print("  CSVs temporarios removidos com sucesso.")


def carregar_no_postgres(tables):
    """
    Conecta ao PostgreSQL, desabilita triggers temporariamente,
    faz TRUNCATE em cascata, e carrega todas as tabelas via COPY.
    """
    print(f"\n  Conectando ao PostgreSQL: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['dbname']}")

    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False

    try:
        with conn.cursor() as cur:
            # Desabilitar triggers de validacao durante a carga em massa
            cur.execute("SET session_replication_role = 'replica';")

            # Truncar todas as tabelas na ordem reversa de dependencia
            all_tables = ", ".join(name for name, _ in reversed(tables))
            cur.execute(f"TRUNCATE TABLE {all_tables} RESTART IDENTITY CASCADE;")
            print("  TRUNCATE concluido.")

            # Carregar cada tabela via COPY
            for name, df in tables:
                carregar_tabela_copy(cur, name, df)
                print(f"    OK {name}: {len(df):,} registros carregados")

            # Reposicionar sequencias SERIAL
            for name, _ in tables:
                cur.execute(
                    f"SELECT setval(pg_get_serial_sequence('{name}', 'id'), "
                    f"(SELECT COALESCE(MAX(id), 1) FROM {name}), true);"
                )

            # Reabilitar triggers
            cur.execute("SET session_replication_role = 'origin';")

            # Atualizar estatisticas para o otimizador de queries
            cur.execute("ANALYZE;")

        conn.commit()
        print("\n  COMMIT realizado. Carga concluida com sucesso!")

    except Exception as e:
        conn.rollback()
        print(f"\n  ERRO: Rollback executado. Detalhes: {e}")
        raise
    finally:
        conn.close()


# =====================================================================
# MAIN
# =====================================================================

def main():
    start = time.time()

    print("=" * 65)
    print("  AEROPORTO — Pipeline de Geracao de Dados para Benchmark")
    print("=" * 65)

    # 1) Gerar DataFrames
    print("\n[ETAPA 1] Gerando dados com Faker + pandas...")
    tables = gerar_todos_dataframes()

    # 2) Validar volumetria
    print("\n[ETAPA 2] Validando volumetria...")
    validar_volumetria(tables)

    # 3) Salvar CSVs temporarios (pandas)
    print("\n[ETAPA 3] Salvando CSVs temporarios...")
    salvar_csvs_temporarios(tables)

    # 4) Carregar no PostgreSQL via COPY
    print("\n[ETAPA 4] Carregando dados no PostgreSQL via COPY...")
    carregar_no_postgres(tables)

    # 5) Limpar CSVs temporarios
    print("\n[ETAPA 5] Limpando arquivos temporarios...")
    limpar_csvs_temporarios()

    elapsed = time.time() - start
    total = sum(len(df) for _, df in tables)
    print(f"\n{'=' * 65}")
    print(f"  CONCLUIDO: {total:,} registros inseridos em {elapsed:.2f}s")
    print(f"  Banco: {DB_CONFIG['dbname']} @ {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print(f"{'=' * 65}")


if __name__ == "__main__":
    main()
