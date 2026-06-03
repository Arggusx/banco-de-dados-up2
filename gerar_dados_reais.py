#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
===================================================================
 GERADOR DE DADOS REALISTAS — Sistema Aeroportuário PostgreSQL
===================================================================
 Gera 60.000 registos (10 tabelas lookup × 1.000 + 10 tabelas
 negócio × 5.000) com dados realistas em português (Faker pt_BR).
 
 Saídas:
   1. dml.sql          — INSERT em blocos de 100 valores
   2. csv_output/      — Um CSV por tabela (via pandas)
   3. PostgreSQL       — Inserção directa via COPY (psycopg2)
   
 Autor: Script gerado automaticamente
 Data:  2026-06-03
===================================================================
"""

import io
import os
import csv
import sys
import time
import random
import string
import itertools
from datetime import datetime, timedelta, date, timezone

from faker import Faker
import psycopg2
import pandas as pd

# Reconfigurar a codificação do terminal para UTF-8 no Windows
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        pass

# ===================================================================
# CONFIGURAÇÃO DO BANCO DE DADOS
# ===================================================================
DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "dbname": "aeroporto_benchmark",
    "user": "postgres",
    "password": "1234",
}

# ===================================================================
# CONSTANTES DE VOLUME
# ===================================================================
LOOKUP_COUNT = 1_000    # Registos por tabela lookup
BUSINESS_COUNT = 5_000  # Registos por tabela de negócio
BATCH_SIZE = 100        # Valores por INSERT no dml.sql

# ===================================================================
# INICIALIZAÇÃO DO FAKER E SEEDS
# ===================================================================
fake = Faker("pt_BR")
Faker.seed(42)
random.seed(42)

# ===================================================================
# DIRETÓRIOS DE SAÍDA
# ===================================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_DIR = os.path.join(BASE_DIR, "csv_output")
DML_FILE = os.path.join(BASE_DIR, "dml.sql")


# ===================================================================
# FUNÇÕES UTILITÁRIAS
# ===================================================================

def escape_sql(value) -> str:
    """Escapa valores para uso em SQL INSERT statements."""
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (datetime, date)):
        return f"'{value.isoformat()}'"
    # String — escapar aspas simples
    s = str(value).replace("'", "''")
    return f"'{s}'"


def gerar_insert_batch(tabela: str, colunas: list, registos: list) -> str:
    """
    Gera INSERT statements em blocos de BATCH_SIZE.
    Retorna string SQL completa para a tabela.
    """
    linhas = []
    total = len(registos)
    
    for i in range(0, total, BATCH_SIZE):
        bloco = registos[i:i + BATCH_SIZE]
        valores_lista = []
        for reg in bloco:
            vals = ", ".join(escape_sql(reg[c]) for c in colunas)
            valores_lista.append(f"({vals})")
        
        cols_str = ", ".join(colunas)
        valores_str = ",\n".join(valores_lista)
        linhas.append(f"INSERT INTO {tabela} ({cols_str}) VALUES\n{valores_str};\n")
    
    return "\n".join(linhas)


def dataframe_para_csv_buffer(df: pd.DataFrame) -> io.StringIO:
    """Converte DataFrame para buffer CSV para uso com COPY."""
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False, quoting=csv.QUOTE_ALL)
    buffer.seek(0)
    return buffer


def bulk_insert_copy(cursor, tabela: str, colunas: list, buffer: io.StringIO):
    """Inserção via COPY FROM STDIN — método mais rápido do PostgreSQL."""
    cols = ", ".join(colunas)
    sql = f"COPY {tabela} ({cols}) FROM STDIN WITH (FORMAT csv, DELIMITER ',', NULL '', QUOTE '\"')"
    cursor.copy_expert(sql, buffer)


def gerar_codigos_unicos_letras(tamanho: int, quantidade: int) -> list:
    """
    Gera códigos únicos de letras maiúsculas com o tamanho especificado.
    Para tamanho=2: AA, AB, AC, ..., ZZ (676 combinações) + extensões
    Para tamanho=3: AAA, AAB, ..., (17576 combinações)
    """
    letras = string.ascii_uppercase
    codigos = set()
    
    # Gerar combinações sistemáticas
    if tamanho == 2:
        chars = string.ascii_uppercase + string.digits
        for combo in itertools.product(chars, repeat=2):
            codigos.add("".join(combo))
            if len(codigos) >= quantidade:
                break
    elif tamanho == 3:
        for combo in itertools.product(letras, repeat=3):
            codigos.add("".join(combo))
            if len(codigos) >= quantidade:
                break
    elif tamanho == 4:
        for combo in itertools.product(letras, repeat=4):
            codigos.add("".join(combo))
            if len(codigos) >= quantidade:
                break
    
    resultado = sorted(codigos)[:quantidade]
    return resultado


# ===================================================================
# GERADORES DE DADOS POR TABELA
# ===================================================================

# -------------------------------------------------------------------
# Dados de referência reais para os primeiros registos
# -------------------------------------------------------------------
PAISES_REAIS = [
    ("Brasil", "BR", "BRA", "AMERICA_DO_SUL"),
    ("Portugal", "PT", "PRT", "EUROPA"),
    ("Estados Unidos", "US", "USA", "AMERICA_DO_NORTE"),
    ("Argentina", "AR", "ARG", "AMERICA_DO_SUL"),
    ("Alemanha", "DE", "DEU", "EUROPA"),
    ("França", "FR", "FRA", "EUROPA"),
    ("Itália", "IT", "ITA", "EUROPA"),
    ("Espanha", "ES", "ESP", "EUROPA"),
    ("Reino Unido", "GB", "GBR", "EUROPA"),
    ("Japão", "JP", "JPN", "ASIA"),
    ("China", "CN", "CHN", "ASIA"),
    ("Índia", "IN", "IND", "ASIA"),
    ("Austrália", "AU", "AUS", "OCEANIA"),
    ("Canadá", "CA", "CAN", "AMERICA_DO_NORTE"),
    ("México", "MX", "MEX", "AMERICA_DO_NORTE"),
    ("Rússia", "RU", "RUS", "EUROPA"),
    ("Coreia do Sul", "KR", "KOR", "ASIA"),
    ("Indonésia", "ID", "IDN", "ASIA"),
    ("Turquia", "TR", "TUR", "ASIA"),
    ("Arábia Saudita", "SA", "SAU", "ASIA"),
    ("África do Sul", "ZA", "ZAF", "AFRICA"),
    ("Nigéria", "NG", "NGA", "AFRICA"),
    ("Egito", "EG", "EGY", "AFRICA"),
    ("Chile", "CL", "CHL", "AMERICA_DO_SUL"),
    ("Colômbia", "CO", "COL", "AMERICA_DO_SUL"),
    ("Peru", "PE", "PER", "AMERICA_DO_SUL"),
    ("Venezuela", "VE", "VEN", "AMERICA_DO_SUL"),
    ("Uruguai", "UY", "URY", "AMERICA_DO_SUL"),
    ("Paraguai", "PY", "PRY", "AMERICA_DO_SUL"),
    ("Bolívia", "BO", "BOL", "AMERICA_DO_SUL"),
    ("Equador", "EC", "ECU", "AMERICA_DO_SUL"),
    ("Noruega", "NO", "NOR", "EUROPA"),
    ("Suécia", "SE", "SWE", "EUROPA"),
    ("Dinamarca", "DK", "DNK", "EUROPA"),
    ("Finlândia", "FI", "FIN", "EUROPA"),
    ("Polónia", "PL", "POL", "EUROPA"),
    ("Holanda", "NL", "NLD", "EUROPA"),
    ("Bélgica", "BE", "BEL", "EUROPA"),
    ("Suíça", "CH", "CHE", "EUROPA"),
    ("Áustria", "AT", "AUT", "EUROPA"),
    ("Grécia", "GR", "GRC", "EUROPA"),
    ("Irlanda", "IE", "IRL", "EUROPA"),
    ("República Checa", "CZ", "CZE", "EUROPA"),
    ("Roménia", "RO", "ROU", "EUROPA"),
    ("Hungria", "HU", "HUN", "EUROPA"),
    ("Nova Zelândia", "NZ", "NZL", "OCEANIA"),
    ("Tailândia", "TH", "THA", "ASIA"),
    ("Malásia", "MY", "MYS", "ASIA"),
    ("Filipinas", "PH", "PHL", "ASIA"),
    ("Vietname", "VN", "VNM", "ASIA"),
]

CONTINENTES = [
    "EUROPA", "ASIA", "AFRICA",
    "AMERICA_DO_NORTE", "AMERICA_DO_SUL",
    "OCEANIA", "ANTARTICA",
]

FABRICANTES_REAIS = [
    "Boeing", "Airbus", "Embraer", "Bombardier", "Cessna",
    "Dassault Aviation", "Gulfstream", "ATR", "Pilatus", "Saab",
    "Lockheed Martin", "Mitsubishi Aircraft", "COMAC", "Sukhoi",
    "Tupolev", "Antonov", "Fokker", "BAE Systems", "De Havilland",
    "Beechcraft",
]

MODELOS_REAIS = [
    ("Boeing 737-800", 189, 5765), ("Boeing 747-400", 416, 13450),
    ("Boeing 777-300ER", 396, 13650), ("Boeing 787-9", 296, 14140),
    ("Boeing 767-300ER", 269, 11070), ("Airbus A320neo", 194, 6300),
    ("Airbus A330-300", 440, 11750), ("Airbus A350-900", 325, 15000),
    ("Airbus A380-800", 853, 15200), ("Airbus A220-300", 160, 6297),
    ("Embraer E195-E2", 146, 4815), ("Embraer E175", 88, 3704),
    ("ATR 72-600", 78, 1528), ("Bombardier CRJ-900", 90, 2956),
    ("Cessna Citation X", 12, 6020),
]

FUSOS_HORARIOS = [
    "America/Sao_Paulo", "America/New_York", "America/Chicago",
    "America/Los_Angeles", "Europe/London", "Europe/Paris",
    "Europe/Berlin", "Europe/Madrid", "Europe/Rome", "Europe/Lisbon",
    "Asia/Tokyo", "Asia/Shanghai", "Asia/Dubai", "Asia/Kolkata",
    "Asia/Singapore", "Australia/Sydney", "Pacific/Auckland",
    "America/Buenos_Aires", "America/Lima", "America/Bogota",
    "Africa/Cairo", "Africa/Johannesburg", "America/Mexico_City",
    "America/Toronto", "Asia/Seoul",
]

TIPOS_SERVICO_FORNECEDOR = [
    "CATERING", "COMBUSTIVEL", "LIMPEZA", "MANUTENCAO",
    "SEGURANCA", "HANDLING", "TRANSPORTE", "TECNOLOGIA",
    "LOGISTICA", "CONSULTORIA",
]

STATUS_RESERVA_OPCOES = ["CONFIRMADA", "CANCELADA", "PENDENTE", "EMBARCADA", "NO_SHOW"]
CLASSES_PASSAGEM = ["ECONOMICA", "EXECUTIVA", "PRIMEIRA_CLASSE"]
STATUS_BAGAGEM_OPCOES = ["DESPACHADA", "EM_TRANSITO", "ENTREGUE", "EXTRAVIADA", "DANIFICADA"]
FUNCOES_TRIPULACAO = [
    "COMANDANTE", "COPILOTO", "COMISSARIO",
    "COMISSARIO_CHEFE", "MECANICO_BORDO", "ENGENHEIRO_VOO",
]
TIPOS_TERMINAL = ["DOMESTICO", "INTERNACIONAL", "MISTO", "CARGA"]

PROGRAMAS_FIDELIDADE = [
    "SMILES", "LATAM_PASS", "TUDO_AZUL", "MILES_AND_GO",
    "SKYWARDS", "AADVANTAGE", "MILEAGE_PLUS", "FLYING_BLUE",
    "EXECUTIVE_CLUB", "ASIA_MILES", None, None, None,
]


# -------------------------------------------------------------------
# 1. PAÍSES (1.000 registos)
# -------------------------------------------------------------------
def gerar_paises(qtd: int) -> list:
    """Gera registos de países com códigos ISO únicos."""
    print(f"  🌍 [01/20] Gerando {qtd:,} países...")
    inicio = time.time()
    
    registos = []
    iso2_usados = set()
    iso3_usados = set()
    
    # Primeiro: países reais
    for i, (nome, iso2, iso3, cont) in enumerate(PAISES_REAIS):
        if i >= qtd:
            break
        registos.append({
            "nome": nome,
            "codigo_iso2": iso2,
            "codigo_iso3": iso3,
            "continente": cont,
        })
        iso2_usados.add(iso2)
        iso3_usados.add(iso3)
    
    # Gerar códigos ISO2 e ISO3 restantes sistematicamente
    todos_iso2 = gerar_codigos_unicos_letras(2, 1000)
    todos_iso3 = gerar_codigos_unicos_letras(3, 1000)
    
    # Filtrar os já usados
    iso2_disponiveis = [c for c in todos_iso2 if c not in iso2_usados]
    iso3_disponiveis = [c for c in todos_iso3 if c not in iso3_usados]
    
    idx2 = 0
    idx3 = 0
    nomes_pais_usados = {r["nome"] for r in registos}
    
    while len(registos) < qtd:
        # Gerar nome fictício de país
        nome_base = fake.city()
        nome_pais = f"República de {nome_base}"
        tentativa = 0
        while nome_pais in nomes_pais_usados:
            tentativa += 1
            nome_pais = f"República de {nome_base} {tentativa}"
        nomes_pais_usados.add(nome_pais)
        
        # Nome pode ficar longo — truncar a 100 caracteres
        nome_pais = nome_pais[:100]
        
        iso2 = iso2_disponiveis[idx2]
        iso3 = iso3_disponiveis[idx3]
        idx2 += 1
        idx3 += 1
        
        registos.append({
            "nome": nome_pais,
            "codigo_iso2": iso2,
            "codigo_iso3": iso3,
            "continente": random.choice(CONTINENTES),
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} países gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 2. CIDADES (1.000 registos)
# -------------------------------------------------------------------
def gerar_cidades(qtd: int) -> list:
    """Gera registos de cidades com referência a países."""
    print(f"  🏙️  [02/20] Gerando {qtd:,} cidades...")
    inicio = time.time()
    
    registos = []
    for _ in range(qtd):
        registos.append({
            "nome": fake.city()[:150],
            "pais_id": random.randint(1, LOOKUP_COUNT),
            "estado_provincia": fake.state()[:100] if random.random() > 0.1 else None,
            "populacao": random.randint(5_000, 15_000_000),
            "latitude": round(random.uniform(-90.0, 90.0), 6),
            "longitude": round(random.uniform(-180.0, 180.0), 6),
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} cidades geradas em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 3. FABRICANTES (1.000 registos)
# -------------------------------------------------------------------
def gerar_fabricantes(qtd: int) -> list:
    """Gera registos de fabricantes de aeronaves."""
    print(f"  🏭 [03/20] Gerando {qtd:,} fabricantes...")
    inicio = time.time()
    
    registos = []
    nomes_usados = set()
    
    # Fabricantes reais primeiro
    for nome in FABRICANTES_REAIS:
        if len(registos) >= qtd:
            break
        registos.append({
            "nome": nome,
            "pais_origem_id": random.randint(1, LOOKUP_COUNT),
            "ano_fundacao": random.randint(1900, 2020),
            "website": f"https://www.{nome.lower().replace(' ', '').replace('.', '')}.com"[:255],
            "ativo": True,
        })
        nomes_usados.add(nome)
    
    # Fabricantes fictícios
    prefixos = ["Aero", "Sky", "Air", "Jet", "Wing", "Fly", "Tech", "Nova", "Star", "Global"]
    sufixos = ["Corp", "Industries", "Aviation", "Aerospace", "Systems", "Dynamics", "Works", "Manufacturing", "Engineering", "Solutions"]
    
    while len(registos) < qtd:
        nome = f"{random.choice(prefixos)}{random.choice(sufixos)} {len(registos)}"[:100]
        if nome not in nomes_usados:
            nomes_usados.add(nome)
            registos.append({
                "nome": nome,
                "pais_origem_id": random.randint(1, LOOKUP_COUNT),
                "ano_fundacao": random.randint(1950, 2024),
                "website": f"https://www.{nome.lower().replace(' ', '')}.com"[:255],
                "ativo": random.random() > 0.1,
            })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} fabricantes gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 4. MODELOS DE AERONAVE (1.000 registos)
# -------------------------------------------------------------------
def gerar_modelos_aeronave(qtd: int) -> list:
    """Gera registos de modelos de aeronave."""
    print(f"  ✈️  [04/20] Gerando {qtd:,} modelos de aeronave...")
    inicio = time.time()
    
    registos = []
    nomes_usados = set()
    
    # Modelos reais
    for nome, cap, alcance in MODELOS_REAIS:
        if len(registos) >= qtd:
            break
        registos.append({
            "nome": nome,
            "fabricante_id": random.randint(1, LOOKUP_COUNT),
            "capacidade_passageiros": cap,
            "alcance_km": alcance,
            "peso_max_decolagem_kg": round(random.uniform(20000, 500000), 2),
            "ano_primeiro_voo": random.randint(1970, 2024),
            "envergadura_metros": round(random.uniform(20.0, 80.0), 2),
        })
        nomes_usados.add(nome)
    
    # Modelos fictícios
    series = ["X", "Y", "Z", "A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W"]
    while len(registos) < qtd:
        idx = len(registos)
        serie = series[idx % len(series)]
        numero = 100 + idx
        nome = f"Modelo {serie}-{numero}"[:100]
        if nome not in nomes_usados:
            nomes_usados.add(nome)
            cap = random.randint(50, 500)
            registos.append({
                "nome": nome,
                "fabricante_id": random.randint(1, LOOKUP_COUNT),
                "capacidade_passageiros": cap,
                "alcance_km": random.randint(1000, 16000),
                "peso_max_decolagem_kg": round(random.uniform(15000, 600000), 2),
                "ano_primeiro_voo": random.randint(1960, 2025),
                "envergadura_metros": round(random.uniform(15.0, 85.0), 2),
            })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} modelos gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 5. CARGOS DE FUNCIONÁRIOS (1.000 registos) — nome UNIQUE
# -------------------------------------------------------------------
def gerar_cargos_funcionarios(qtd: int) -> list:
    """Gera registos de cargos com nomes ÚNICOS."""
    print(f"  👔 [05/20] Gerando {qtd:,} cargos de funcionários...")
    inicio = time.time()
    
    # Base de cargos aeroportuários
    bases = [
        "Piloto Comercial", "Piloto Executivo", "Copiloto",
        "Comissário de Bordo", "Comissário Chefe", "Chefe de Cabine",
        "Engenheiro de Voo", "Mecânico de Aeronaves", "Técnico de Manutenção",
        "Controlador de Tráfego Aéreo", "Despachante de Voo",
        "Gerente de Operações", "Supervisor de Pista", "Agente de Check-in",
        "Agente de Embarque", "Agente de Segurança", "Inspetor de Segurança",
        "Coordenador de Logística", "Analista de Operações", "Diretor de Terminal",
        "Gerente de Manutenção", "Supervisor de Handling", "Técnico de Radar",
        "Operador de Equipamentos", "Motorista de Pista",
        "Gerente de Recursos Humanos", "Analista Financeiro",
        "Auditor Operacional", "Gerente de Qualidade", "Instrutor de Voo",
        "Meteorologista Aeronáutico", "Engenheiro Aeronáutico",
        "Administrador de Sistemas", "Analista de TI", "Gerente de TI",
        "Bombeiro Aeroportuário", "Paramédico Aeroportuário",
        "Oficial de Segurança da Aviação", "Fiscal de Alfândega",
        "Gerente Comercial",
    ]
    
    registos = []
    nomes_usados = set()
    
    # Gerar cargos base
    for base in bases:
        if len(registos) >= qtd:
            break
        nome = base[:100]
        nomes_usados.add(nome)
        nivel = random.randint(1, 10)
        sal_min = round(random.uniform(2000, 15000), 2)
        sal_max = round(sal_min + random.uniform(1000, 20000), 2)
        registos.append({
            "nome": nome,
            "descricao": f"Cargo de {nome.lower()} na operação aeroportuária.",
            "nivel_acesso": nivel,
            "salario_min": sal_min,
            "salario_max": sal_max,
        })
    
    # Gerar variações numeradas para atingir 1.000
    nivel_sufixos = ["Júnior", "Pleno", "Sénior", "Master", "Especialista"]
    setor_sufixos = ["Setor A", "Setor B", "Setor C", "Setor D", "Setor E"]
    
    base_idx = 0
    var_idx = 0
    while len(registos) < qtd:
        base = bases[base_idx % len(bases)]
        
        # Tentar com nível
        if var_idx < len(nivel_sufixos):
            nome = f"{base} {nivel_sufixos[var_idx]}"[:100]
        elif var_idx < len(nivel_sufixos) + len(setor_sufixos):
            sidx = var_idx - len(nivel_sufixos)
            nome = f"{base} {setor_sufixos[sidx]}"[:100]
        else:
            # Variações numeradas
            num = var_idx - len(nivel_sufixos) - len(setor_sufixos) + 1
            nome = f"{base} Nível {num}"[:100]
        
        if nome not in nomes_usados:
            nomes_usados.add(nome)
            nivel = random.randint(1, 10)
            sal_min = round(random.uniform(2000, 15000), 2)
            sal_max = round(sal_min + random.uniform(1000, 20000), 2)
            registos.append({
                "nome": nome,
                "descricao": f"Cargo de {nome.lower()} na operação aeroportuária.",
                "nivel_acesso": nivel,
                "salario_min": sal_min,
                "salario_max": sal_max,
            })
        
        var_idx += 1
        if var_idx > 50:  # Reset para próxima base
            base_idx += 1
            var_idx = 0
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} cargos gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 6. STATUS DE VOO (1.000 registos) — codigo UNIQUE
# -------------------------------------------------------------------
def gerar_status_voo(qtd: int) -> list:
    """Gera registos de status de voo com códigos ÚNICOS."""
    print(f"  📊 [06/20] Gerando {qtd:,} status de voo...")
    inicio = time.time()
    
    # Status base reais
    status_base = [
        ("PROGRAMADO", "Voo programado aguardando execução", "#3498DB"),
        ("EMBARQUE", "Embarque de passageiros em andamento", "#F39C12"),
        ("EM_VOO", "Aeronave em voo", "#27AE60"),
        ("ATERRISSADO", "Aeronave aterrissou no destino", "#2ECC71"),
        ("CANCELADO", "Voo cancelado", "#E74C3C"),
        ("ATRASADO", "Voo com atraso", "#E67E22"),
        ("DESVIADO", "Voo desviado para outro aeroporto", "#9B59B6"),
        ("TAXIANDO", "Aeronave em taxiamento na pista", "#1ABC9C"),
        ("PORTAO_ABERTO", "Portão de embarque aberto", "#F1C40F"),
        ("PORTAO_FECHADO", "Portão de embarque fechado", "#E74C3C"),
        ("DECOLANDO", "Aeronave em procedimento de decolagem", "#3498DB"),
        ("APROXIMACAO", "Aeronave em aproximação final", "#2980B9"),
        ("MANUTENCAO", "Voo suspenso por manutenção", "#95A5A6"),
        ("AGUARDANDO_PISTA", "Aguardando liberação de pista", "#D35400"),
        ("CHECK_IN_ABERTO", "Check-in disponível para passageiros", "#16A085"),
        ("CONCLUIDO", "Voo concluído com sucesso", "#27AE60"),
        ("SUSPENSO", "Voo suspenso temporariamente", "#BDC3C7"),
        ("REAGENDADO", "Voo reagendado para nova data", "#8E44AD"),
        ("EMERGENCIA", "Voo em situação de emergência", "#C0392B"),
        ("PRE_VOO", "Preparação pré-voo em andamento", "#2C3E50"),
    ]
    
    registos = []
    codigos_usados = set()
    
    for codigo, desc, cor in status_base:
        if len(registos) >= qtd:
            break
        registos.append({
            "codigo": codigo[:20],
            "descricao": desc[:200],
            "cor_hex": cor,
            "ordem_exibicao": len(registos) + 1,
        })
        codigos_usados.add(codigo[:20])
    
    # Variantes numeradas
    idx = 1
    while len(registos) < qtd:
        for base_cod, _, _ in status_base:
            if len(registos) >= qtd:
                break
            codigo = f"{base_cod[:14]}_{idx}"[:20]
            if codigo not in codigos_usados:
                codigos_usados.add(codigo)
                cor = f"#{random.randint(0, 0xFFFFFF):06X}"
                registos.append({
                    "codigo": codigo,
                    "descricao": f"Variante {idx} do status {base_cod.lower().replace('_', ' ')}"[:200],
                    "cor_hex": cor,
                    "ordem_exibicao": len(registos) + 1,
                })
        idx += 1
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} status gerados em {elapsed:.2f}s")
    return registos[:qtd]


# -------------------------------------------------------------------
# 7. CATEGORIAS DE TARIFA (1.000 registos) — nome UNIQUE
# -------------------------------------------------------------------
def gerar_categorias_tarifa(qtd: int) -> list:
    """Gera registos de categorias de tarifa com nomes ÚNICOS."""
    print(f"  💰 [07/20] Gerando {qtd:,} categorias de tarifa...")
    inicio = time.time()
    
    bases = [
        ("ECONOMICA_LIGHT", 0.80, 0, 5), ("ECONOMICA_STANDARD", 1.00, 23, 4),
        ("ECONOMICA_PLUS", 1.20, 30, 3), ("ECONOMICA_FLEX", 1.40, 30, 3),
        ("EXECUTIVA_LIGHT", 2.00, 32, 2), ("EXECUTIVA_STANDARD", 2.50, 40, 2),
        ("EXECUTIVA_FLEX", 3.00, 40, 1), ("PRIMEIRA_CLASSE", 4.00, 50, 1),
        ("PRIMEIRA_FLEX", 5.00, 50, 1), ("PREMIUM_ECONOMY", 1.60, 25, 3),
        ("BUSINESS_SAVER", 2.20, 35, 2), ("BUSINESS_FULL", 3.50, 45, 1),
        ("PROMO_BASICA", 0.60, 0, 5), ("PROMO_ESPECIAL", 0.70, 15, 4),
        ("CORPORATE", 1.80, 30, 2), ("ESTUDANTE", 0.75, 20, 4),
        ("MILITAR", 0.85, 25, 3), ("IDOSO", 0.90, 23, 4),
        ("FAMILIA", 1.10, 25, 3), ("GRUPO", 0.95, 20, 4),
    ]
    
    registos = []
    nomes_usados = set()
    
    for nome, mult, bag, pri in bases:
        if len(registos) >= qtd:
            break
        registos.append({
            "nome": nome[:50],
            "descricao": f"Tarifa {nome.lower().replace('_', ' ')}.",
            "multiplicador_preco": mult,
            "bagagem_inclusa_kg": bag,
            "prioridade_embarque": pri,
        })
        nomes_usados.add(nome[:50])
    
    # Variantes
    idx = 1
    while len(registos) < qtd:
        for base_nome, mult, bag, pri in bases:
            if len(registos) >= qtd:
                break
            nome = f"{base_nome[:42]}_{idx}"[:50]
            if nome not in nomes_usados:
                nomes_usados.add(nome)
                registos.append({
                    "nome": nome,
                    "descricao": f"Variante {idx} da tarifa {base_nome.lower().replace('_', ' ')}.",
                    "multiplicador_preco": round(mult + random.uniform(-0.3, 0.3), 2) or 0.50,
                    "bagagem_inclusa_kg": max(0, bag + random.randint(-5, 10)),
                    "prioridade_embarque": random.randint(1, 5),
                })
        idx += 1
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} categorias geradas em {elapsed:.2f}s")
    return registos[:qtd]


# -------------------------------------------------------------------
# 8. TIPOS DE BAGAGEM (1.000 registos) — nome UNIQUE
# -------------------------------------------------------------------
def gerar_tipos_bagagem(qtd: int) -> list:
    """Gera registos de tipos de bagagem com nomes ÚNICOS."""
    print(f"  🧳 [08/20] Gerando {qtd:,} tipos de bagagem...")
    inicio = time.time()
    
    bases = [
        ("MAO_PEQUENA", 8.0, "40x30x20", 0.00),
        ("MAO_STANDARD", 10.0, "55x35x25", 0.00),
        ("MAO_GRANDE", 12.0, "55x40x25", 25.00),
        ("PORAO_PEQUENA", 18.0, "60x40x30", 30.00),
        ("PORAO_STANDARD", 23.0, "70x50x30", 0.00),
        ("PORAO_GRANDE", 32.0, "80x60x40", 50.00),
        ("PORAO_EXTRA", 40.0, "90x70x50", 100.00),
        ("ESPECIAL_ESPORTIVA", 30.0, "Variável", 80.00),
        ("ESPECIAL_MUSICAL", 25.0, "Variável", 75.00),
        ("ESPECIAL_ANIMAL", 15.0, "50x40x30", 120.00),
        ("ESPECIAL_FRAGIL", 20.0, "60x50x40", 60.00),
        ("OVERSIZED", 50.0, "100x80x60", 200.00),
        ("CARGA_LEVE", 45.0, "80x60x50", 150.00),
        ("CARGA_PESADA", 80.0, "120x80x60", 300.00),
        ("INFANTIL", 10.0, "45x35x20", 0.00),
        ("DIPLOMATICA", 32.0, "70x50x35", 0.00),
        ("TRIPULACAO", 15.0, "55x40x25", 0.00),
        ("MEDICA", 20.0, "50x40x30", 0.00),
        ("DUTY_FREE", 5.0, "40x30x20", 0.00),
        ("PRIORITARIA", 32.0, "70x50x30", 35.00),
    ]
    
    registos = []
    nomes_usados = set()
    
    for nome, peso, dim, taxa in bases:
        if len(registos) >= qtd:
            break
        registos.append({
            "nome": nome[:50],
            "descricao": f"Bagagem do tipo {nome.lower().replace('_', ' ')}.",
            "peso_max_kg": peso,
            "dimensoes_max_cm": dim[:30],
            "taxa_extra": taxa,
        })
        nomes_usados.add(nome[:50])
    
    # Variantes
    idx = 1
    while len(registos) < qtd:
        for base_nome, peso, dim, taxa in bases:
            if len(registos) >= qtd:
                break
            nome = f"{base_nome[:42]}_{idx}"[:50]
            if nome not in nomes_usados:
                nomes_usados.add(nome)
                registos.append({
                    "nome": nome,
                    "descricao": f"Variante {idx} do tipo {base_nome.lower().replace('_', ' ')}.",
                    "peso_max_kg": round(peso + random.uniform(-2, 10), 2),
                    "dimensoes_max_cm": dim[:30],
                    "taxa_extra": round(max(0, taxa + random.uniform(-10, 50)), 2),
                })
        idx += 1
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} tipos gerados em {elapsed:.2f}s")
    return registos[:qtd]


# -------------------------------------------------------------------
# 9. AEROPORTOS (5.000 registos) — iata e icao UNIQUE
# -------------------------------------------------------------------
def gerar_aeroportos(qtd: int) -> list:
    """Gera registos de aeroportos com códigos IATA/ICAO únicos."""
    print(f"  🛫 [09/20] Gerando {qtd:,} aeroportos...")
    inicio = time.time()
    
    # Gerar códigos únicos
    codigos_iata = gerar_codigos_unicos_letras(3, qtd)
    codigos_icao = gerar_codigos_unicos_letras(4, qtd)
    
    registos = []
    for i in range(qtd):
        registos.append({
            "nome": f"Aeroporto {fake.city()}"[:200],
            "codigo_iata": codigos_iata[i],
            "codigo_icao": codigos_icao[i],
            "cidade_id": random.randint(1, LOOKUP_COUNT),
            "latitude": round(random.uniform(-90.0, 90.0), 6),
            "longitude": round(random.uniform(-180.0, 180.0), 6),
            "altitude_metros": random.randint(0, 4500),
            "fuso_horario": random.choice(FUSOS_HORARIOS),
            "ativo": random.random() > 0.05,
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} aeroportos gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 10. TERMINAIS (1.000 registos) — UNIQUE(nome, aeroporto_id)
# -------------------------------------------------------------------
def gerar_terminais(qtd: int) -> list:
    """Gera registos de terminais com unicidade (nome, aeroporto_id)."""
    print(f"  🏢 [10/20] Gerando {qtd:,} terminais...")
    inicio = time.time()
    
    registos = []
    pares_usados = set()
    
    nomes_terminal = [f"Terminal {c}" for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
    nomes_terminal += [f"T{i}" for i in range(1, 51)]
    
    for _ in range(qtd):
        tentativas = 0
        while tentativas < 1000:
            aeroporto_id = random.randint(1, BUSINESS_COUNT)
            nome = random.choice(nomes_terminal)
            par = (nome, aeroporto_id)
            if par not in pares_usados:
                pares_usados.add(par)
                break
            tentativas += 1
        
        registos.append({
            "nome": nome[:50],
            "aeroporto_id": aeroporto_id,
            "capacidade_gates": random.randint(2, 50),
            "tipo": random.choice(TIPOS_TERMINAL),
            "ativo": random.random() > 0.05,
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} terminais gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 11. FORNECEDORES (1.000 registos)
# -------------------------------------------------------------------
def gerar_fornecedores(qtd: int) -> list:
    """Gera registos de fornecedores de serviços aeroportuários."""
    print(f"  🤝 [11/20] Gerando {qtd:,} fornecedores...")
    inicio = time.time()
    
    registos = []
    for _ in range(qtd):
        registos.append({
            "nome": fake.company()[:150],
            "pais_id": random.randint(1, LOOKUP_COUNT),
            "tipo_servico": random.choice(TIPOS_SERVICO_FORNECEDOR),
            "telefone": fake.phone_number()[:30],
            "email": fake.company_email()[:150],
            "cnpj_vat": fake.cnpj()[:30],
            "ativo": random.random() > 0.08,
            "data_contrato": fake.date_between(start_date="-10y", end_date="today"),
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} fornecedores gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 12. AERONAVES (5.000 registos) — matricula UNIQUE
# -------------------------------------------------------------------
def gerar_aeronaves(qtd: int) -> list:
    """Gera registos de aeronaves com matrícula única."""
    print(f"  🛩️  [12/20] Gerando {qtd:,} aeronaves...")
    inicio = time.time()
    
    registos = []
    matriculas_usadas = set()
    
    prefixos = ["PR", "PT", "PP", "PS", "PU", "N", "G", "D", "F", "EC", "VH", "JA", "B", "HL", "TC"]
    
    for i in range(qtd):
        # Gerar matrícula única
        while True:
            prefixo = random.choice(prefixos)
            numero = f"{random.randint(100, 9999)}"
            sufixo = random.choice(string.ascii_uppercase)
            matricula = f"{prefixo}-{numero}{sufixo}"[:15]
            if matricula not in matriculas_usadas:
                matriculas_usadas.add(matricula)
                break
        
        registos.append({
            "matricula": matricula,
            "modelo_id": random.randint(1, LOOKUP_COUNT),
            "ano_fabricacao": random.randint(1990, 2025),
            "data_ultima_revisao": fake.date_between(start_date="-2y", end_date="today"),
            "total_horas_voo": random.randint(0, 80000),
            "ativa": random.random() > 0.05,
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} aeronaves geradas em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 13. PASSAGEIROS (5.000 registos) — email UNIQUE
# -------------------------------------------------------------------
def gerar_passageiros(qtd: int) -> list:
    """Gera registos de passageiros com emails únicos."""
    print(f"  🧑 [13/20] Gerando {qtd:,} passageiros...")
    inicio = time.time()
    
    registos = []
    emails_usados = set()
    
    for i in range(qtd):
        nome = fake.first_name()
        sobrenome = fake.last_name()
        
        # Garantir email único
        email_base = f"{nome.lower()}.{sobrenome.lower()}".replace(" ", "")
        email = f"{email_base}{i}@{fake.free_email_domain()}"[:200]
        while email in emails_usados:
            email = f"{email_base}{i}{random.randint(100,999)}@{fake.free_email_domain()}"[:200]
        emails_usados.add(email)
        
        # Data de nascimento: entre 1940 e 2008 (mínimo ~18 anos)
        data_nasc = fake.date_of_birth(minimum_age=18, maximum_age=85)
        
        registos.append({
            "nome": nome[:100],
            "sobrenome": sobrenome[:100],
            "email": email,
            "telefone": fake.phone_number()[:30],
            "data_nascimento": data_nasc,
            "numero_passaporte": f"{random.choice(string.ascii_uppercase)}{random.choice(string.ascii_uppercase)}{random.randint(100000, 999999)}"[:20],
            "nacionalidade_id": random.randint(1, LOOKUP_COUNT),
            "programa_fidelidade": random.choice(PROGRAMAS_FIDELIDADE),
            "milhas_acumuladas": random.randint(0, 500000),
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} passageiros gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 14. FUNCIONÁRIOS (5.000 registos) — email e numero_identificacao UNIQUE
# -------------------------------------------------------------------
def gerar_funcionarios(qtd: int) -> list:
    """Gera registos de funcionários com email e nº identificação únicos."""
    print(f"  👨‍✈️ [14/20] Gerando {qtd:,} funcionários...")
    inicio = time.time()
    
    registos = []
    emails_usados = set()
    nums_usados = set()
    
    for i in range(qtd):
        nome = fake.first_name()
        sobrenome = fake.last_name()
        
        # Email único
        email = f"{nome.lower()}.{sobrenome.lower()}.func{i}@aeroporto.com.br"[:200]
        while email in emails_usados:
            email = f"{nome.lower()}{random.randint(100,9999)}.func{i}@aeroporto.com.br"[:200]
        emails_usados.add(email)
        
        # Número de identificação único
        num_id = f"FUNC-{i+1:06d}"[:30]
        nums_usados.add(num_id)
        
        registos.append({
            "nome": nome[:100],
            "sobrenome": sobrenome[:100],
            "email": email,
            "cargo_id": random.randint(1, LOOKUP_COUNT),
            "aeroporto_base_id": random.randint(1, BUSINESS_COUNT),
            "data_contratacao": fake.date_between(start_date="-15y", end_date="today"),
            "salario": round(random.uniform(2500, 35000), 2),
            "ativo": random.random() > 0.05,
            "numero_identificacao": num_id,
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} funcionários gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 15. VOOS (5.000 registos) — origem != destino, partida < chegada
# -------------------------------------------------------------------
def gerar_voos(qtd: int) -> list:
    """Gera registos de voos com consistência de datas e rotas."""
    print(f"  🛫 [15/20] Gerando {qtd:,} voos...")
    inicio = time.time()
    
    companhias = ["LA", "G3", "AD", "TP", "AA", "UA", "DL", "LH", "AF", "BA", "IB", "EK", "QR", "SQ", "JJ"]
    
    registos = []
    for i in range(qtd):
        # Garantir origem != destino
        origem = random.randint(1, BUSINESS_COUNT)
        destino = random.randint(1, BUSINESS_COUNT)
        while destino == origem:
            destino = random.randint(1, BUSINESS_COUNT)
        
        # Gerar número de voo
        cia = random.choice(companhias)
        num = random.randint(100, 9999)
        numero_voo = f"{cia}{num}"[:10]
        
        # Datas coerentes: partida antes da chegada (1h a 14h de diferença)
        base_date = fake.date_time_between(start_date="-1y", end_date="+6m")
        data_partida = base_date.replace(tzinfo=timezone.utc)
        duracao_horas = random.uniform(1.0, 14.0)
        data_chegada = data_partida + timedelta(hours=duracao_horas)
        
        registos.append({
            "numero_voo": numero_voo,
            "aeronave_id": random.randint(1, BUSINESS_COUNT),
            "aeroporto_origem_id": origem,
            "aeroporto_destino_id": destino,
            "data_partida": data_partida,
            "data_chegada": data_chegada,
            "status_id": random.randint(1, LOOKUP_COUNT),
            "preco_base": round(random.uniform(50, 2500), 2),
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} voos gerados em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 16. ESCALAS DE TRIPULAÇÃO (5.000) — UNIQUE(funcionario_id, voo_id)
# -------------------------------------------------------------------
def gerar_escalas_tripulacao(qtd: int) -> list:
    """Gera escalas de tripulação sem pares (funcionário, voo) duplicados."""
    print(f"  👥 [16/20] Gerando {qtd:,} escalas de tripulação...")
    inicio = time.time()
    
    registos = []
    pares_usados = set()
    
    for _ in range(qtd):
        tentativas = 0
        while tentativas < 5000:
            func_id = random.randint(1, BUSINESS_COUNT)
            voo_id = random.randint(1, BUSINESS_COUNT)
            par = (func_id, voo_id)
            if par not in pares_usados:
                pares_usados.add(par)
                break
            tentativas += 1
        
        registos.append({
            "funcionario_id": func_id,
            "voo_id": voo_id,
            "funcao": random.choice(FUNCOES_TRIPULACAO),
            "data_atribuicao": fake.date_between(start_date="-1y", end_date="today"),
            "confirmado": random.random() > 0.2,
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} escalas geradas em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 17. RESERVAS (5.000) — codigo_reserva UNIQUE (6 chars alfanuméricos)
# -------------------------------------------------------------------
def gerar_reservas(qtd: int, categorias_tarifa: list, voos: list) -> list:
    """Gera reservas com código único e preço coerente."""
    print(f"  📋 [17/20] Gerando {qtd:,} reservas...")
    inicio = time.time()
    
    registos = []
    codigos_usados = set()
    
    chars = string.ascii_uppercase + string.digits
    
    for i in range(qtd):
        # Código de reserva único (6 chars)
        while True:
            codigo = "".join(random.choices(chars, k=6))
            if codigo not in codigos_usados:
                codigos_usados.add(codigo)
                break
        
        # Preço coerente: preco_base * multiplicador
        voo_idx = random.randint(0, len(voos) - 1)
        cat_idx = random.randint(0, len(categorias_tarifa) - 1)
        preco_base = voos[voo_idx]["preco_base"]
        multiplicador = categorias_tarifa[cat_idx]["multiplicador_preco"]
        preco_total = round(preco_base * multiplicador, 2)
        # Garantir preco_total > 0
        if preco_total <= 0:
            preco_total = round(preco_base * 1.0, 2)
        if preco_total <= 0:
            preco_total = 50.00
        
        # Data de reserva com timezone
        data_reserva = fake.date_time_between(start_date="-1y", end_date=datetime.now())
        data_reserva = data_reserva.replace(tzinfo=timezone.utc)
        
        registos.append({
            "passageiro_id": random.randint(1, BUSINESS_COUNT),
            "voo_id": voo_idx + 1,  # ID 1-based
            "categoria_tarifa_id": cat_idx + 1,  # ID 1-based
            "codigo_reserva": codigo,
            "data_reserva": data_reserva,
            "preco_total": preco_total,
            "status": random.choice(STATUS_RESERVA_OPCOES),
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} reservas geradas em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 18. PASSAGENS (5.000) — numero_passagem UNIQUE
# -------------------------------------------------------------------
def gerar_passagens(qtd: int) -> list:
    """Gera passagens com número único e assento válido."""
    print(f"  🎫 [18/20] Gerando {qtd:,} passagens...")
    inicio = time.time()
    
    registos = []
    numeros_usados = set()
    
    letras_assento = "ABCDEF"
    
    for i in range(qtd):
        # Número de passagem único — formato TKT-XXXXX
        numero = f"TKT-{i+1:05d}"[:20]
        numeros_usados.add(numero)
        
        # Assento: número(1-40) + letra(A-F)
        fila = random.randint(1, 40)
        letra = random.choice(letras_assento)
        assento = f"{fila}{letra}"[:5]
        
        # Data de emissão
        emitida_em = fake.date_time_between(start_date="-1y", end_date=datetime.now())
        emitida_em = emitida_em.replace(tzinfo=timezone.utc)
        
        registos.append({
            "reserva_id": i + 1,  # 1:1 com reservas
            "numero_passagem": numero,
            "assento": assento,
            "classe": random.choice(CLASSES_PASSAGEM),
            "emitida_em": emitida_em,
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} passagens geradas em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 19. BAGAGENS (5.000) — codigo_rastreio UNIQUE, peso <= tipo peso_max
# -------------------------------------------------------------------
def gerar_bagagens(qtd: int, tipos_bagagem: list) -> list:
    """Gera bagagens com código de rastreio único e peso coerente."""
    print(f"  🧳 [19/20] Gerando {qtd:,} bagagens...")
    inicio = time.time()
    
    registos = []
    codigos_usados = set()
    
    for i in range(qtd):
        # Código de rastreio único — formato BAG-XXXXXXXX
        codigo = f"BAG-{i+1:08d}"[:20]
        codigos_usados.add(codigo)
        
        # Tipo de bagagem e peso coerente
        tipo_idx = random.randint(0, len(tipos_bagagem) - 1)
        peso_max = tipos_bagagem[tipo_idx]["peso_max_kg"]
        # peso entre 2 e min(32, peso_max)
        peso_limite = min(32.0, peso_max)
        if peso_limite < 2.0:
            peso_limite = peso_max  # caso peso_max < 2 (improvável)
        peso = round(random.uniform(2.0, peso_limite), 2)
        
        registos.append({
            "passagem_id": random.randint(1, BUSINESS_COUNT),
            "tipo_bagagem_id": tipo_idx + 1,  # ID 1-based
            "peso_kg": peso,
            "codigo_rastreio": codigo,
            "status": random.choice(STATUS_BAGAGEM_OPCOES),
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} bagagens geradas em {elapsed:.2f}s")
    return registos


# -------------------------------------------------------------------
# 20. CARTÕES DE EMBARQUE (5.000) — passagem_id UNIQUE, codigo_barras UNIQUE
# -------------------------------------------------------------------
def gerar_cartoes_embarque(qtd: int) -> list:
    """Gera cartões de embarque — um por passagem (UNIQUE FK)."""
    print(f"  🎟️  [20/20] Gerando {qtd:,} cartões de embarque...")
    inicio = time.time()
    
    registos = []
    codigos_usados = set()
    
    for i in range(qtd):
        # passagem_id UNIQUE — exatamente 1 cartão por passagem (1..5000)
        passagem_id = i + 1
        
        # Código de barras único
        codigo = f"BRD-{i+1:010d}-{random.randint(10,99)}"[:30]
        codigos_usados.add(codigo)
        
        # Gate: letra + número
        gate_letra = random.choice(string.ascii_uppercase[:8])  # A-H
        gate_num = random.randint(1, 30)
        gate = f"{gate_letra}{gate_num}"[:10]
        
        # Hora de embarque
        hora_embarque = fake.date_time_between(start_date="-1y", end_date="+6m")
        hora_embarque = hora_embarque.replace(tzinfo=timezone.utc)
        
        registos.append({
            "passagem_id": passagem_id,
            "terminal_id": random.randint(1, LOOKUP_COUNT),
            "gate": gate,
            "zona_embarque": random.randint(1, 6),
            "hora_embarque": hora_embarque,
            "codigo_barras": codigo,
            "impresso": random.random() > 0.3,
        })
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(registos):,} cartões gerados em {elapsed:.2f}s")
    return registos


# ===================================================================
# EXPORTAÇÃO DML.SQL
# ===================================================================

def exportar_dml_sql(todas_tabelas: dict, caminho: str):
    """Exporta todos os dados para um ficheiro dml.sql com batch INSERTs."""
    print(f"\n  📝 Exportando dml.sql ({caminho})...")
    inicio = time.time()
    
    # Definição de colunas por tabela (sem 'id' — é SERIAL)
    colunas_por_tabela = {
        "paises": ["nome", "codigo_iso2", "codigo_iso3", "continente"],
        "cidades": ["nome", "pais_id", "estado_provincia", "populacao", "latitude", "longitude"],
        "fabricantes": ["nome", "pais_origem_id", "ano_fundacao", "website", "ativo"],
        "modelos_aeronave": ["nome", "fabricante_id", "capacidade_passageiros", "alcance_km",
                             "peso_max_decolagem_kg", "ano_primeiro_voo", "envergadura_metros"],
        "cargos_funcionarios": ["nome", "descricao", "nivel_acesso", "salario_min", "salario_max"],
        "status_voo": ["codigo", "descricao", "cor_hex", "ordem_exibicao"],
        "categorias_tarifa": ["nome", "descricao", "multiplicador_preco", "bagagem_inclusa_kg",
                               "prioridade_embarque"],
        "tipos_bagagem": ["nome", "descricao", "peso_max_kg", "dimensoes_max_cm", "taxa_extra"],
        "aeroportos": ["nome", "codigo_iata", "codigo_icao", "cidade_id", "latitude", "longitude",
                       "altitude_metros", "fuso_horario", "ativo"],
        "terminais": ["nome", "aeroporto_id", "capacidade_gates", "tipo", "ativo"],
        "fornecedores": ["nome", "pais_id", "tipo_servico", "telefone", "email", "cnpj_vat",
                         "ativo", "data_contrato"],
        "aeronaves": ["matricula", "modelo_id", "ano_fabricacao", "data_ultima_revisao",
                      "total_horas_voo", "ativa"],
        "passageiros": ["nome", "sobrenome", "email", "telefone", "data_nascimento",
                         "numero_passaporte", "nacionalidade_id", "programa_fidelidade",
                         "milhas_acumuladas"],
        "funcionarios": ["nome", "sobrenome", "email", "cargo_id", "aeroporto_base_id",
                          "data_contratacao", "salario", "ativo", "numero_identificacao"],
        "voos": ["numero_voo", "aeronave_id", "aeroporto_origem_id", "aeroporto_destino_id",
                 "data_partida", "data_chegada", "status_id", "preco_base"],
        "escalas_tripulacao": ["funcionario_id", "voo_id", "funcao", "data_atribuicao", "confirmado"],
        "reservas": ["passageiro_id", "voo_id", "categoria_tarifa_id", "codigo_reserva",
                     "data_reserva", "preco_total", "status"],
        "passagens": ["reserva_id", "numero_passagem", "assento", "classe", "emitida_em"],
        "bagagens": ["passagem_id", "tipo_bagagem_id", "peso_kg", "codigo_rastreio", "status"],
        "cartoes_embarque": ["passagem_id", "terminal_id", "gate", "zona_embarque",
                              "hora_embarque", "codigo_barras", "impresso"],
    }
    
    # Ordem de inserção (respeita dependências FK)
    ordem = [
        "paises", "cidades", "fabricantes", "modelos_aeronave",
        "cargos_funcionarios", "status_voo", "categorias_tarifa", "tipos_bagagem",
        "aeroportos", "terminais", "fornecedores",
        "aeronaves", "passageiros", "funcionarios", "voos",
        "escalas_tripulacao", "reservas", "passagens", "bagagens", "cartoes_embarque",
    ]
    
    with open(caminho, "w", encoding="utf-8") as f:
        f.write("-- ===================================================================\n")
        f.write("-- DML (Data Manipulation Language) — Dados Realistas\n")
        f.write("-- Gerado automaticamente por gerar_dados_reais.py\n")
        f.write(f"-- Total: 60.000 registos em 20 tabelas\n")
        f.write(f"-- Data: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("-- ===================================================================\n\n")
        
        # Desabilitar triggers antes da carga
        f.write("-- Desabilitar triggers para performance na carga de dados\n")
        f.write("ALTER TABLE reservas DISABLE TRIGGER trg_validar_capacidade_reserva;\n")
        f.write("ALTER TABLE funcionarios DISABLE TRIGGER trg_validar_salario_funcionario;\n\n")
        
        f.write("BEGIN;\n\n")
        
        total_registos = 0
        for tabela in ordem:
            registos = todas_tabelas[tabela]
            colunas = colunas_por_tabela[tabela]
            
            f.write(f"-- {tabela.upper()} ({len(registos):,} registos)\n")
            sql = gerar_insert_batch(tabela, colunas, registos)
            f.write(sql)
            f.write("\n")
            total_registos += len(registos)
        
        f.write("COMMIT;\n\n")
        
        # Reabilitar triggers
        f.write("-- Reabilitar triggers após carga de dados\n")
        f.write("ALTER TABLE reservas ENABLE TRIGGER trg_validar_capacidade_reserva;\n")
        f.write("ALTER TABLE funcionarios ENABLE TRIGGER trg_validar_salario_funcionario;\n\n")
        
        # Resetar sequências
        f.write("-- Resetar sequências SERIAL para o próximo valor correto\n")
        for tabela in ordem:
            qtd_tab = len(todas_tabelas[tabela])
            f.write(f"SELECT setval('{tabela}_id_seq', {qtd_tab}, true);\n")
        
        f.write("\n-- ===================================================================\n")
        f.write(f"-- FIM DO DML — {total_registos:,} registos inseridos\n")
        f.write("-- ===================================================================\n")
    
    elapsed = time.time() - inicio
    tamanho_mb = os.path.getsize(caminho) / (1024 * 1024)
    print(f"      ✔ dml.sql exportado em {elapsed:.2f}s ({tamanho_mb:.1f} MB)")


# ===================================================================
# EXPORTAÇÃO CSV
# ===================================================================

def exportar_csvs(todas_tabelas: dict, diretorio: str):
    """Exporta cada tabela como CSV via pandas."""
    print(f"\n  📁 Exportando CSVs para {diretorio}/...")
    inicio = time.time()
    
    os.makedirs(diretorio, exist_ok=True)
    
    for tabela, registos in todas_tabelas.items():
        df = pd.DataFrame(registos)
        caminho = os.path.join(diretorio, f"{tabela}.csv")
        df.to_csv(caminho, index=False, encoding="utf-8")
    
    elapsed = time.time() - inicio
    print(f"      ✔ {len(todas_tabelas)} CSVs exportados em {elapsed:.2f}s")


# ===================================================================
# INSERÇÃO DIRECTA NO POSTGRESQL VIA COPY
# ===================================================================

def inserir_postgresql(todas_tabelas: dict):
    """Insere dados directamente no PostgreSQL via COPY (mais rápido)."""
    print(f"\n  🐘 Inserindo dados no PostgreSQL ({DB_CONFIG['dbname']})...")
    inicio_total = time.time()
    
    # Definição de colunas por tabela (mesma ordem que exportação DML)
    colunas_por_tabela = {
        "paises": ["nome", "codigo_iso2", "codigo_iso3", "continente"],
        "cidades": ["nome", "pais_id", "estado_provincia", "populacao", "latitude", "longitude"],
        "fabricantes": ["nome", "pais_origem_id", "ano_fundacao", "website", "ativo"],
        "modelos_aeronave": ["nome", "fabricante_id", "capacidade_passageiros", "alcance_km",
                             "peso_max_decolagem_kg", "ano_primeiro_voo", "envergadura_metros"],
        "cargos_funcionarios": ["nome", "descricao", "nivel_acesso", "salario_min", "salario_max"],
        "status_voo": ["codigo", "descricao", "cor_hex", "ordem_exibicao"],
        "categorias_tarifa": ["nome", "descricao", "multiplicador_preco", "bagagem_inclusa_kg",
                               "prioridade_embarque"],
        "tipos_bagagem": ["nome", "descricao", "peso_max_kg", "dimensoes_max_cm", "taxa_extra"],
        "aeroportos": ["nome", "codigo_iata", "codigo_icao", "cidade_id", "latitude", "longitude",
                       "altitude_metros", "fuso_horario", "ativo"],
        "terminais": ["nome", "aeroporto_id", "capacidade_gates", "tipo", "ativo"],
        "fornecedores": ["nome", "pais_id", "tipo_servico", "telefone", "email", "cnpj_vat",
                         "ativo", "data_contrato"],
        "aeronaves": ["matricula", "modelo_id", "ano_fabricacao", "data_ultima_revisao",
                      "total_horas_voo", "ativa"],
        "passageiros": ["nome", "sobrenome", "email", "telefone", "data_nascimento",
                         "numero_passaporte", "nacionalidade_id", "programa_fidelidade",
                         "milhas_acumuladas"],
        "funcionarios": ["nome", "sobrenome", "email", "cargo_id", "aeroporto_base_id",
                          "data_contratacao", "salario", "ativo", "numero_identificacao"],
        "voos": ["numero_voo", "aeronave_id", "aeroporto_origem_id", "aeroporto_destino_id",
                 "data_partida", "data_chegada", "status_id", "preco_base"],
        "escalas_tripulacao": ["funcionario_id", "voo_id", "funcao", "data_atribuicao", "confirmado"],
        "reservas": ["passageiro_id", "voo_id", "categoria_tarifa_id", "codigo_reserva",
                     "data_reserva", "preco_total", "status"],
        "passagens": ["reserva_id", "numero_passagem", "assento", "classe", "emitida_em"],
        "bagagens": ["passagem_id", "tipo_bagagem_id", "peso_kg", "codigo_rastreio", "status"],
        "cartoes_embarque": ["passagem_id", "terminal_id", "gate", "zona_embarque",
                              "hora_embarque", "codigo_barras", "impresso"],
    }
    
    ordem = [
        "paises", "cidades", "fabricantes", "modelos_aeronave",
        "cargos_funcionarios", "status_voo", "categorias_tarifa", "tipos_bagagem",
        "aeroportos", "terminais", "fornecedores",
        "aeronaves", "passageiros", "funcionarios", "voos",
        "escalas_tripulacao", "reservas", "passagens", "bagagens", "cartoes_embarque",
    ]
    
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False
        cursor = conn.cursor()
        print(f"      ✔ Conexão estabelecida com {DB_CONFIG['host']}:{DB_CONFIG['port']}")
        
        # Limpar tabelas (ordem inversa de dependências)
        print("      🗑️  Limpando tabelas existentes...")
        for tabela in reversed(ordem):
            cursor.execute(f"TRUNCATE TABLE {tabela} RESTART IDENTITY CASCADE;")
        print("      ✔ Tabelas limpas.")
        
        # Desabilitar triggers
        print("      ⚙️  Desabilitando triggers...")
        cursor.execute("ALTER TABLE reservas DISABLE TRIGGER trg_validar_capacidade_reserva;")
        cursor.execute("ALTER TABLE funcionarios DISABLE TRIGGER trg_validar_salario_funcionario;")
        print("      ✔ Triggers desabilitados.")
        
        # Inserir tabela por tabela via COPY
        total_inserido = 0
        for tabela in ordem:
            inicio = time.time()
            registos = todas_tabelas[tabela]
            colunas = colunas_por_tabela[tabela]
            
            df = pd.DataFrame(registos)
            # Reordenar colunas conforme esperado
            df = df[colunas]
            
            buffer = dataframe_para_csv_buffer(df)
            bulk_insert_copy(cursor, tabela, colunas, buffer)
            
            elapsed = time.time() - inicio
            total_inserido += len(registos)
            print(f"      ✔ {tabela:<25s} — {len(registos):>5,} registos ({elapsed:.2f}s)")
        
        # Reabilitar triggers
        print("      ⚙️  Reabilitando triggers...")
        cursor.execute("ALTER TABLE reservas ENABLE TRIGGER trg_validar_capacidade_reserva;")
        cursor.execute("ALTER TABLE funcionarios ENABLE TRIGGER trg_validar_salario_funcionario;")
        print("      ✔ Triggers reabilitados.")
        
        # Resetar sequências
        print("      🔢 Resetando sequências SERIAL...")
        for tabela in ordem:
            qtd_tab = len(todas_tabelas[tabela])
            cursor.execute(f"SELECT setval('{tabela}_id_seq', {qtd_tab}, true);")
        print("      ✔ Sequências resetadas.")
        
        conn.commit()
        elapsed_total = time.time() - inicio_total
        print(f"\n      ✔ COMMIT realizado — {total_inserido:,} registos inseridos em {elapsed_total:.2f}s")
        
        # Validação
        print("\n  📊 Validação — Contagem de registos:")
        total_validado = 0
        for tabela in ordem:
            cursor.execute(f"SELECT COUNT(*) FROM {tabela};")
            count = cursor.fetchone()[0]
            total_validado += count
            esperado = len(todas_tabelas[tabela])
            status = "✔" if count == esperado else "✘"
            print(f"      {status} {tabela:<25s} — {count:>5,} / {esperado:>5,}")
        
        print(f"\n      📊 TOTAL: {total_validado:,} registos no banco de dados")
        
    except psycopg2.OperationalError as e:
        print(f"\n      ⚠️  Não foi possível conectar ao PostgreSQL: {e}")
        print("      ℹ️  Os ficheiros dml.sql e CSVs foram gerados normalmente.")
        print("      ℹ️  Execute o dml.sql manualmente após iniciar o PostgreSQL.")
        return
    except Exception as e:
        if 'conn' in locals():
            conn.rollback()
        print(f"\n      ✘ ERRO durante inserção: {e}")
        print("      ROLLBACK realizado. Nenhum dado foi persistido.")
        raise
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
            print("      ✔ Conexão encerrada.")


# ===================================================================
# FUNÇÃO PRINCIPAL
# ===================================================================

def main():
    print("=" * 70)
    print(" ✈️  GERADOR DE DADOS REALISTAS — Aeroporto PostgreSQL")
    print("=" * 70)
    print(f" 📦 Total: 60.000 registos (10 lookup × 1.000 + 10 negócio × 5.000)")
    print(f" 🌐 Locale: pt_BR | Seeds: Faker(42) + random(42)")
    print(f" 📂 Saídas: dml.sql + csv_output/ + PostgreSQL (COPY)")
    print("=" * 70)
    print()
    
    inicio_global = time.time()
    
    # =================================================================
    # FASE 1: Geração de dados em memória
    # =================================================================
    print("━" * 70)
    print(" FASE 1: Geração de dados em memória")
    print("━" * 70)
    
    # Tabelas lookup (1.000 registos cada)
    paises = gerar_paises(LOOKUP_COUNT)
    cidades = gerar_cidades(LOOKUP_COUNT)
    fabricantes = gerar_fabricantes(LOOKUP_COUNT)
    modelos_aeronave = gerar_modelos_aeronave(LOOKUP_COUNT)
    cargos_funcionarios = gerar_cargos_funcionarios(LOOKUP_COUNT)
    status_voo = gerar_status_voo(LOOKUP_COUNT)
    categorias_tarifa = gerar_categorias_tarifa(LOOKUP_COUNT)
    tipos_bagagem = gerar_tipos_bagagem(LOOKUP_COUNT)
    
    # Tabelas de negócio (5.000 registos cada)
    aeroportos = gerar_aeroportos(BUSINESS_COUNT)
    terminais = gerar_terminais(LOOKUP_COUNT)  # 1.000 conforme especificado
    fornecedores = gerar_fornecedores(LOOKUP_COUNT)  # 1.000 conforme especificado
    aeronaves = gerar_aeronaves(BUSINESS_COUNT)
    passageiros = gerar_passageiros(BUSINESS_COUNT)
    funcionarios = gerar_funcionarios(BUSINESS_COUNT)
    voos = gerar_voos(BUSINESS_COUNT)
    escalas_tripulacao = gerar_escalas_tripulacao(BUSINESS_COUNT)
    reservas = gerar_reservas(BUSINESS_COUNT, categorias_tarifa, voos)
    passagens = gerar_passagens(BUSINESS_COUNT)
    bagagens = gerar_bagagens(BUSINESS_COUNT, tipos_bagagem)
    cartoes_embarque = gerar_cartoes_embarque(BUSINESS_COUNT)
    
    # Dicionário com todos os dados
    todas_tabelas = {
        "paises": paises,
        "cidades": cidades,
        "fabricantes": fabricantes,
        "modelos_aeronave": modelos_aeronave,
        "cargos_funcionarios": cargos_funcionarios,
        "status_voo": status_voo,
        "categorias_tarifa": categorias_tarifa,
        "tipos_bagagem": tipos_bagagem,
        "aeroportos": aeroportos,
        "terminais": terminais,
        "fornecedores": fornecedores,
        "aeronaves": aeronaves,
        "passageiros": passageiros,
        "funcionarios": funcionarios,
        "voos": voos,
        "escalas_tripulacao": escalas_tripulacao,
        "reservas": reservas,
        "passagens": passagens,
        "bagagens": bagagens,
        "cartoes_embarque": cartoes_embarque,
    }
    
    total_registos = sum(len(v) for v in todas_tabelas.values())
    elapsed_fase1 = time.time() - inicio_global
    print(f"\n  📊 Total gerado: {total_registos:,} registos em {elapsed_fase1:.2f}s")
    
    # =================================================================
    # FASE 2: Exportação DML.SQL
    # =================================================================
    print("\n" + "━" * 70)
    print(" FASE 2: Exportação DML.SQL (batch INSERT × 100)")
    print("━" * 70)
    exportar_dml_sql(todas_tabelas, DML_FILE)
    
    # =================================================================
    # FASE 3: Exportação CSV
    # =================================================================
    print("\n" + "━" * 70)
    print(" FASE 3: Exportação CSV (pandas)")
    print("━" * 70)
    exportar_csvs(todas_tabelas, CSV_DIR)
    
    # =================================================================
    # FASE 4: Inserção directa no PostgreSQL
    # =================================================================
    print("\n" + "━" * 70)
    print(" FASE 4: Inserção directa no PostgreSQL (COPY)")
    print("━" * 70)
    inserir_postgresql(todas_tabelas)
    
    # =================================================================
    # RESUMO FINAL
    # =================================================================
    elapsed_total = time.time() - inicio_global
    print("\n" + "=" * 70)
    print(" ✅ GERAÇÃO CONCLUÍDA COM SUCESSO!")
    print("=" * 70)
    print(f"  📊 Total de registos: {total_registos:,}")
    print(f"  ⏱️  Tempo total: {elapsed_total:.2f}s")
    print(f"  📄 DML: {DML_FILE}")
    print(f"  📁 CSVs: {CSV_DIR}/")
    print(f"  🐘 PostgreSQL: {DB_CONFIG['dbname']} @ {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print()
    print("  📋 Resumo por tabela:")
    print(f"  {'Tabela':<25s} | {'Registos':>8s} | {'Tipo':<10s}")
    print(f"  {'-'*25}-+-{'-'*8}-+-{'-'*10}")
    for tabela, registos in todas_tabelas.items():
        tipo = "Lookup" if len(registos) == LOOKUP_COUNT else "Negócio"
        print(f"  {tabela:<25s} | {len(registos):>8,} | {tipo:<10s}")
    print(f"  {'-'*25}-+-{'-'*8}-+-{'-'*10}")
    print(f"  {'TOTAL':<25s} | {total_registos:>8,} |")
    print("=" * 70)


if __name__ == "__main__":
    main()
