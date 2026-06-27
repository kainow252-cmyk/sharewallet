#!/usr/bin/env python3
"""
importar_clientes.py  —  ShareWallet v2
========================================
Importa bases CSV (beneficiários INSS/consignado por UF + CAGED 2024)
para o banco de clientes do Cloudflare Worker via POST /api/customers/import

Campos salvos por cliente:
  CPF · Nome · Data Nasc. · Sexo
  E-mail (até 3) · Telefone celular (até 3) · Telefone fixo (até 2)
  Endereço completo (CEP, Rua, Bairro, Cidade, UF)
  Benefício INSS: NB, Status, Espécie
  Dados bancários: Banco, Agência, Conta, Meio de Pagamento
  Financeiro: Margem disponível, Margem RCC, Margem RMC,
              Valor benefício, Renda mensal

Estrutura do CSV (separador ;):
  NB;CPF;NOME;DTNASCIMENTO;ESP;DIB;MR;BANCOPAGTO;AGENCIAPAGTO;ORGAOPAGADOR;
  CONTACORRENTE;MEIOPAGTO;STATUSBENEFICIO;BLOQUEIO;PENSAOALIMENTICIA;
  REPRESENTANTE;SEXO;DDB;BANCORMC;VALORRMC;BANCORCC;VALORRCC;
  BANCOEMPRESTIMO;CONTRATO;VLEMPRESTIMO;INICIODODESCONTO;PRAZO;VLPARCELA;
  TIPOEMPRESTIMO;DATAAVERBACAO;SITUACAOEMPRESTIMO;COMPETENCIA;
  COMPETENCIA_FINAL;TAXA;SALDO;BAIRRO;MUNICIPIO;UF;CEP;ENDERECO;
  DDD(0);FONE(0);DDD(1);FONE(1);DDD(2);FONE(2);
  DDDF(0);FIXO(0);DDDF(1);FIXO(1);
  EMAIL(1);EMAIL(2);EMAIL(3);NOVO_MR;SOMA_PARCELAS;MARGEM

Uso:
  python3 importar_clientes.py arquivo.csv [arquivo2.csv ...]
  python3 importar_clientes.py --all          # todos os CSVs do diretório
  python3 importar_clientes.py --drive        # baixa e importa do Google Drive
  python3 importar_clientes.py --test         # 100 linhas do primeiro CSV
  python3 importar_clientes.py --max 5000 arquivo.csv
"""

import csv, sys, os, time, re, json, io, glob, argparse
import hashlib, tempfile, urllib.request, urllib.parse, urllib.error

API_URL    = "https://api.sharewallet.com.br/api/customers/import"
BATCH_SIZE = 300    # máx 500 no Worker
SLEEP_SEC  = 0.20   # entre batches

# ── IDs dos arquivos no Google Drive ──────────────────────────────────────────
DRIVE_FILES = {
    # Bases por UF (DEZ/2025) — beneficiários INSS/consignado
    "baseSPDEZ25.csv":  "1KNGaCgRzau8_Ax54k5c8f0n93A5p0Z1B",  # SP  ~1 GB
    "baseSEDEZ25.csv":  "1FjN6m6vlfkTenuAfBz9Su9-Xhz41oRLP",  # SE  ~181 MB
    "baseSCDEZ25.csv":  "1bOckvZmroptC8qX-OI-7bAAIIVZtH5f2",  # SC  ~605 MB
    "baseRSDEZ25.csv":  "1gKiLXrSDBq68XU5_rjXj_PRvDrfs7E6R",  # RS  ~1.1 GB
    "baseRODEZ25.csv":  "1v0_SRwS-qlpEHwwaJSPSJtALX9nrU528",  # RO  ~110 MB
    "baseRNDEZ25.csv":  "1yD2IQu7sRlPWYI7Pk5BtY6PAEhGGM1GA",  # RN  ~317 MB
    "baseRJDEZ25.csv":  "1YchQ3x8gVkq2yzTK1dXBARx850mJ_mvY",  # RJ  ~1.4 GB
    "basePRDEZ25.csv":  "1Ec15ZzilpMI4kieXZA1yjAiitmUst_Ad",  # PR  ~495 MB
    "basePIDEZ25.csv":  "1TzGkRSsaw2mAeptiNrKg2fmPMvYFC6vZ",  # PI  ~277 MB
    "basePBDEZ25.csv":  "1jwwgvKEPvFH_v-SVoC-WPShlF6YL3fRJ",  # PB  ~329 MB
    "basePADEZ25.csv":  "1xSLW7nkenpr-zCtwR4ScJJfDq5r6om7D",  # PA  ~617 MB
    "baseMTDEZ25.csv":  "1TyXb5sZvGcVE8_m6S7PkOjrnJRhu7kAS",  # MT  ~212 MB
    "baseMSDEZ25.csv":  "1hxXOXzTv4CIMywjf9rfEoJZCV_OHo1aU",  # MS  ~217 MB
    "baseMGDEZ25.csv":  "1Pxkxt9YsVBzVaIH7ip753AELB7jvRhw-",  # MG  ~1.5 GB
    "baseMADEZ25.csv":  "1bIztP8lEZ7RXMU3ajTdcjGw1oa5Pu-r5",  # MA  ~702 MB
    "baseGODEZ25.csv":  "1A4U8pMIEaiSvX7ku_HLp-tkqLC4wcCPm",  # GO  ~419 MB
    "baseESDEZ25.csv":  "1nH5l-r1Yim4W_n2jsSsOaT0Z0HC4eIbg",  # ES  ~292 MB
    "baseDFDEZ25.csv":  "1QgwaKVma-Dz8EVfFHnDSgTtl0osz8Ptj",  # DF  ~143 MB
    "baseCEDEZ25.csv":  "1crS2SsNohYnOhaKBy01HMMWk8JMbFMqP",  # CE  ~759 MB
    "baseBADEZ25.csv":  "1D-ZbNAfPbTBKd_igUFFU5CzR1sMIFZ6d",  # BA  ~1.1 GB
    "baseAMDEZ25.csv":  "1MpcSIkVlt11Zr755A0mus8SeVfbumdFe",  # AM  ~235 MB
    "baseALDEZ25.csv":  "1qh2MO4aKEEg6ORMxvduzx3Ealg8VFGED",  # AL  ~276 MB
    # CAGED 2024 (partes)
    "Caged-2024_PT2.csv":  "1tv8VQBec5Z9HvNZxvo6UMgiuFAbLS0VF",
    "Caged-2024_PT3.csv":  "1wysv9h3wmrwF7iZ2dAngM6OyGrFrXe-I",
    "Caged-2024_PT4.csv":  "1Jgq-zr6oCq9A39rrTpphxHGEL7uTh5Us",
    "Caged-2024_PT5.csv":  "17ban1ZLcrMkYOgatWhAqa4JqKIfYCu0-",
    "Caged-2024_PT8.csv":  "1rsp25ERHTKSpCsqJ0yzU7ZRRMn7CTDYa",
    "Caged-2024_PT9.csv":  "1L2U1-tcxUdwXw79qY2g__D6ASOhGHLmv",
    "Caged-2024_PT10.csv": "1SZTVrYDRDiy9rxiSNQA6riWUptkDD0j8",
    "Caged-2024_PT11.csv": "1UeXhnCxkJ84RFbWDvk_agOCObXJjO4yl",
    "Caged-2024_PT12.csv": "13KLg0yTjRO9foPFHJ-RIbFSf6EqRhpfI",
    "Caged-2024_PT13.csv": "1SjecuWUHZt9hchGWlRkqb4nNcfxtq9G5",
    "Caged-2024_PT14.csv": "1XfcDJvyIoglz06c2t-Ihpj8-tO7lPdjr",
    "Caged-2024_PT15.csv": "1qQBNypJIyoCfaQlIrVNuIrf69TWf1rlZ",
}


# ── Helpers ────────────────────────────────────────────────────────────────────

def _d(v): return re.sub(r'\D', '', str(v or ''))

def _limpar_float(v) -> float:
    try:
        s = str(v or '').strip().replace(',', '.')
        s = re.sub(r'\.0$', '', s)   # remove ".0" de floats importados como string
        return round(float(s), 2) if s else 0.0
    except Exception:
        return 0.0

def _limpar_cep(v) -> str:
    c = _d(v)
    if c.endswith('0') and len(c) == 9:   # artefato ".0" ao ler float
        c = c[:-1]
    return c[:8].zfill(8) if c else ''

def _tel(ddd, fone) -> str:
    d = _d(ddd); f = _d(fone)
    if not f or f in ('0', '00'):
        return ''
    return (d + f)[:11]

def _email(v) -> str:
    e = str(v or '').strip().lower()
    return e if '@' in e and '.' in e.split('@')[-1] else ''

def _titulo(v) -> str:
    return str(v or '').strip().title()

def _upper(v) -> str:
    return str(v or '').strip().upper()

def _data(dt) -> str:
    """Aceita DD/MM/AAAA ou AAAA-MM-DD → retorna DD/MM/AAAA"""
    dt = str(dt or '').strip()
    if re.match(r'^\d{2}/\d{2}/\d{4}$', dt):
        return dt
    if re.match(r'^\d{4}-\d{2}-\d{2}$', dt):
        p = dt.split('-')
        return f"{p[2]}/{p[1]}/{p[0]}"
    return dt

def _cpf_valido(cpf: str) -> bool:
    c = _d(cpf)
    if len(c) != 11 or re.match(r'^(\d)\1{10}$', c):
        return False
    soma = sum(int(c[i]) * (10 - i) for i in range(9))
    r = (soma * 10) % 11
    if r in (10, 11): r = 0
    if r != int(c[9]): return False
    soma = sum(int(c[i]) * (11 - i) for i in range(10))
    r = (soma * 10) % 11
    if r in (10, 11): r = 0
    return r == int(c[10])


# ── Converte linha CSV → dict cliente ─────────────────────────────────────────

def _linha_para_cliente(vals: list, col: dict, origem: str = 'importacao') -> dict | None:
    """
    vals: lista de valores da linha (já sem header)
    col:  dict {nome_coluna: índice}
    """
    def g(k):
        i = col.get(k, -1)
        return vals[i].strip() if 0 <= i < len(vals) else ''

    cpf  = _d(g('CPF'))
    if not _cpf_valido(cpf):
        return None

    nasc = _data(g('DTNASCIMENTO'))
    if not re.match(r'^\d{2}/\d{2}/\d{4}$', nasc):
        return None

    nome = _titulo(g('NOME'))
    if not nome:
        return None

    # Telefones celulares (até 3)
    fone1 = _tel(g('DDD(0)'), g('FONE(0)'))
    fone2 = _tel(g('DDD(1)'), g('FONE(1)'))
    fone3 = _tel(g('DDD(2)'), g('FONE(2)'))

    # Telefones fixos (até 2)
    fixo1 = _tel(g('DDDF(0)'), g('FIXO(0)'))
    fixo2 = _tel(g('DDDF(1)'), g('FIXO(1)'))

    # E-mails (até 3)
    email1 = _email(g('EMAIL(1)'))
    email2 = _email(g('EMAIL(2)'))
    email3 = _email(g('EMAIL(3)'))

    # Endereço
    cep    = _limpar_cep(g('CEP'))
    rua    = _titulo(g('ENDERECO'))
    bairro = _titulo(g('BAIRRO'))
    cidade = _titulo(g('MUNICIPIO'))
    estado = _upper(g('UF'))[:2]

    # Benefício INSS
    nb             = g('NB')
    status_benef   = _upper(g('STATUSBENEFICIO'))
    especie        = g('ESP')           # código da espécie (ex: 41, 32, 57...)

    # Dados bancários
    banco_pagto    = g('BANCOPAGTO')
    agencia_pagto  = g('AGENCIAPAGTO')
    conta_corrente = g('CONTACORRENTE')
    meio_pagto     = _upper(g('MEIOPAGTO'))

    # Dados financeiros
    margem_disp    = _limpar_float(g('MARGEM'))      # MARGEM = margem disponível
    margem_rmc     = _limpar_float(g('VALORRMC'))
    margem_rcc     = _limpar_float(g('VALORRCC'))
    valor_benef    = _limpar_float(g('MR'))           # MR = valor do benefício mensal
    # NOVO_MR = novo valor margem após empréstimos
    renda_mensal   = _limpar_float(g('NOVO_MR')) or valor_benef

    sexo = _upper(g('SEXO'))[:1]   # M ou F

    return {
        "cpf":            cpf,
        "data_nascimento": nasc,
        "nome":           nome,
        "sexo":           sexo,
        "email":          email1,
        "email2":         email2,
        "email3":         email3,
        "telefone":       fone1,
        "telefone2":      fone2,
        "telefone3":      fone3,
        "fixo1":          fixo1,
        "fixo2":          fixo2,
        "cep":            cep,
        "rua":            rua,
        "numero":         "",
        "complemento":    "",
        "bairro":         bairro,
        "cidade":         cidade,
        "estado":         estado,
        # Benefício
        "beneficio_nb":       nb,
        "beneficio_status":   status_benef,
        "beneficio_especie":  especie,
        # Bancário
        "banco_pagto":    banco_pagto,
        "agencia_pagto":  agencia_pagto,
        "conta_corrente": conta_corrente,
        "meio_pagto":     meio_pagto,
        # Financeiro
        "margem_disponivel": margem_disp,
        "margem_rmc":        margem_rmc,
        "margem_rcc":        margem_rcc,
        "valor_beneficio":   valor_benef,
        "renda_mensal":      renda_mensal,
        "origem":            origem,
    }


# ── Envio para a API ───────────────────────────────────────────────────────────

def enviar_batch(batch: list) -> dict:
    body = json.dumps({"customers": batch}).encode()
    req  = urllib.request.Request(
        API_URL, data=body,
        headers={
            "Content-Type":  "application/json",
            "User-Agent":    "ShareWallet-Importer/2.0",
            "Accept":        "application/json",
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.read().decode(errors='replace')[:200]}"}
    except Exception as e:
        return {"error": str(e)}


# ── Importação de arquivo ──────────────────────────────────────────────────────

def importar_arquivo(filepath: str, max_rows: int = 0,
                     origem: str = 'importacao') -> tuple[int, int, int]:
    """Retorna (total_lidas, ok, skip)"""
    print(f"\n📂  {os.path.basename(filepath)}")

    # Detectar encoding
    enc = 'latin-1'
    for e in ('latin-1', 'utf-8', 'cp1252', 'iso-8859-1'):
        try:
            with open(filepath, 'r', encoding=e) as f:
                f.read(8192)
            enc = e; break
        except Exception:
            continue
    print(f"   encoding={enc}")

    with open(filepath, 'r', encoding=enc, errors='replace') as f:
        header_line = f.readline()

    sep = ';' if header_line.count(';') > header_line.count(',') else ','
    print(f"   sep='{sep}'")

    headers = [h.strip() for h in header_line.split(sep)]
    col = {h: i for i, h in enumerate(headers)}
    print(f"   {len(headers)} colunas | ex: {headers[:6]}")

    # Verificação mínima
    for req_col in ('CPF', 'NOME', 'DTNASCIMENTO'):
        if req_col not in col:
            print(f"   ⚠️  Coluna '{req_col}' ausente — pulando")
            return 0, 0, 0

    total = ok_n = skip_n = 0
    batch: list = []
    seen: set   = set()

    with open(filepath, 'r', encoding=enc, errors='replace') as f:
        reader = csv.reader(f, delimiter=sep)
        next(reader, None)  # skip header

        for vals in reader:
            total += 1
            if max_rows and total > max_rows:
                break

            cliente = _linha_para_cliente(vals, col, origem)
            if not cliente:
                skip_n += 1
                continue

            key = (cliente['cpf'], cliente['data_nascimento'])
            if key in seen:
                skip_n += 1
                continue
            seen.add(key)

            batch.append(cliente)

            if len(batch) >= BATCH_SIZE:
                res = enviar_batch(batch)
                i   = res.get('result', {}).get('inserted', 0) if res.get('success') else 0
                s   = res.get('result', {}).get('skipped',  len(batch)) if res.get('success') else len(batch)
                ok_n   += i
                skip_n += s
                if not res.get('success'):
                    print(f"   ❌ batch erro: {res.get('error','?')}")
                else:
                    print(f"   ✅ batch: +{i} inseridos | total ok={ok_n:,}")
                batch = []
                time.sleep(SLEEP_SEC)

    if batch:
        res = enviar_batch(batch)
        i   = res.get('result', {}).get('inserted', 0) if res.get('success') else 0
        s   = res.get('result', {}).get('skipped',  len(batch)) if res.get('success') else len(batch)
        ok_n   += i
        skip_n += s
        if not res.get('success'):
            print(f"   ❌ batch final erro: {res.get('error','?')}")
        else:
            print(f"   ✅ batch final: +{i} inseridos")

    taxa = f"{ok_n/total*100:.1f}%" if total else "0%"
    print(f"   📊 {total:,} lidas | {ok_n:,} ok | {skip_n:,} ignoradas | {taxa} aproveitamento")
    return total, ok_n, skip_n


# ── Download Google Drive ──────────────────────────────────────────────────────

def baixar_drive(file_id: str, destino: str) -> bool:
    url = f"https://drive.usercontent.google.com/download?id={file_id}&export=download&confirm=t"
    print(f"   ⬇️  baixando {os.path.basename(destino)} ...")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=600) as r, open(destino, 'wb') as f:
            total_mb = 0
            while True:
                chunk = r.read(2 * 1024 * 1024)
                if not chunk: break
                f.write(chunk)
                total_mb += len(chunk) / (1024 * 1024)
                if int(total_mb) % 100 == 0 and total_mb > 0:
                    print(f"      ... {total_mb:.0f} MB")
        print(f"   ✅ {total_mb:.0f} MB baixados")
        return True
    except Exception as e:
        print(f"   ❌ download falhou: {e}")
        return False


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description='Importa bases CSV → banco clientes ShareWallet')
    ap.add_argument('arquivos', nargs='*', help='CSVs a importar')
    ap.add_argument('--all',    action='store_true', help='Todos os CSVs do diretório')
    ap.add_argument('--drive',  action='store_true', help='Baixa do Drive e importa')
    ap.add_argument('--test',   action='store_true', help='Teste: 200 linhas do 1º CSV')
    ap.add_argument('--max',    type=int, default=0,  help='Máx linhas por arquivo (0=sem limite)')
    ap.add_argument('--origem', default='importacao', help='origem (importacao/manual)')
    args = ap.parse_args()

    arquivos = list(args.arquivos)
    if args.all:
        arquivos += sorted(glob.glob('*.csv'))
        arquivos  = list(dict.fromkeys(arquivos))

    if args.test:
        csvs = args.arquivos or sorted(glob.glob('*.csv'))
        if not csvs:
            print("❌ Nenhum CSV encontrado para teste.")
            return
        print(f"🧪 TESTE — {csvs[0]} (200 linhas)")
        t, o, s = importar_arquivo(csvs[0], max_rows=200, origem='teste')
        print(f"\n✅ {t} lidas | {o} ok | {s} skip")
        return

    if args.drive:
        print(f"📡 Modo Drive: {len(DRIVE_FILES)} arquivos")
        tmp = tempfile.mkdtemp(prefix='sw_import_')
        gt = go = gs = 0
        for nome, fid in DRIVE_FILES.items():
            dest = os.path.join(tmp, nome)
            if baixar_drive(fid, dest):
                t, o, s = importar_arquivo(dest, max_rows=args.max, origem=args.origem)
                gt += t; go += o; gs += s
                try: os.remove(dest)
                except: pass
        print(f"\n🏁 DRIVE CONCLUÍDO — {gt:,} lidas | {go:,} ok | {gs:,} skip")
        return

    if not arquivos:
        print("❌ Informe arquivos ou use --all / --drive / --test")
        print("Uso: python3 importar_clientes.py arquivo.csv [...]")
        print("     python3 importar_clientes.py --all")
        print("     python3 importar_clientes.py --drive")
        print("     python3 importar_clientes.py --test")
        sys.exit(1)

    gt = go = gs = 0
    for arq in arquivos:
        if not os.path.isfile(arq):
            print(f"⚠️  Não encontrado: {arq}")
            continue
        t, o, s = importar_arquivo(arq, max_rows=args.max, origem=args.origem)
        gt += t; go += o; gs += s

    print(f"\n🏁 CONCLUÍDO — {gt:,} lidas | {go:,} ok | {gs:,} skip")
    if gt:
        print(f"   Taxa aproveitamento: {go/gt*100:.1f}%")


if __name__ == '__main__':
    main()
