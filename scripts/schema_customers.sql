-- ── products ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id          TEXT PRIMARY KEY,
  nome        TEXT NOT NULL,
  descricao   TEXT NOT NULL DEFAULT '',
  valor       REAL NOT NULL DEFAULT 0,
  comissao    REAL NOT NULL DEFAULT 0,
  categoria   TEXT NOT NULL DEFAULT 'geral',
  charge_type TEXT NOT NULL DEFAULT 'pixRecorrente',
  periodicidade TEXT,
  dia_cobranca  INTEGER,
  beneficios    TEXT,
  imagem_url    TEXT,
  ativo       INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── affiliates ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS affiliates (
  id              TEXT PRIMARY KEY,
  nome            TEXT NOT NULL DEFAULT '',
  email           TEXT NOT NULL UNIQUE,
  cpf             TEXT NOT NULL DEFAULT '',
  telefone        TEXT NOT NULL DEFAULT '',
  affiliate_code  TEXT NOT NULL UNIQUE,
  sponsor_code    TEXT,
  pix_key         TEXT,
  status          TEXT NOT NULL DEFAULT 'ativo',
  saldo_disponivel  REAL NOT NULL DEFAULT 0,
  saldo_pendente    REAL NOT NULL DEFAULT 0,
  total_comissoes   REAL NOT NULL DEFAULT 0,
  total_sacado      REAL NOT NULL DEFAULT 0,
  total_indicados   INTEGER NOT NULL DEFAULT 0,
  total_assinaturas INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── wallets ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wallets (
  user_id           TEXT PRIMARY KEY,
  saldo_disponivel  REAL NOT NULL DEFAULT 0,
  saldo_pendente    REAL NOT NULL DEFAULT 0,
  total_recebido    REAL NOT NULL DEFAULT 0,
  total_sacado      REAL NOT NULL DEFAULT 0,
  total_indicados   INTEGER NOT NULL DEFAULT 0,
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── subscriptions ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS subscriptions (
  id              TEXT PRIMARY KEY,
  product_id      TEXT NOT NULL,
  product_nome    TEXT NOT NULL DEFAULT '',
  valor           REAL NOT NULL DEFAULT 0,
  comissao        REAL NOT NULL DEFAULT 0,
  affiliate_code  TEXT NOT NULL DEFAULT '',
  affiliate_nome  TEXT,
  charge_type     TEXT NOT NULL DEFAULT 'pixRecorrente',
  status          TEXT NOT NULL DEFAULT 'ativa',
  pix_key         TEXT,
  dia_cobranca    INTEGER NOT NULL DEFAULT 5,
  data_inicio     TEXT NOT NULL DEFAULT (datetime('now')),
  proxima_cobranca TEXT,
  data_cancelamento TEXT,
  motivo          TEXT,
  woovi_subscription_id TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── sales ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sales (
  id              TEXT PRIMARY KEY,
  user_id         TEXT NOT NULL,
  product_id      TEXT NOT NULL,
  product_nome    TEXT NOT NULL DEFAULT '',
  valor           REAL NOT NULL DEFAULT 0,
  comissao        REAL NOT NULL DEFAULT 0,
  affiliate_code  TEXT NOT NULL DEFAULT '',
  status          TEXT NOT NULL DEFAULT 'aprovado',
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── withdrawals ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS withdrawals (
  id              TEXT PRIMARY KEY,
  user_id         TEXT NOT NULL,
  affiliate_nome  TEXT NOT NULL DEFAULT '',
  affiliate_code  TEXT NOT NULL DEFAULT '',
  valor           REAL NOT NULL DEFAULT 0,
  pix_key         TEXT NOT NULL DEFAULT '',
  status          TEXT NOT NULL DEFAULT 'pendente',
  solicitado_em   TEXT NOT NULL DEFAULT (datetime('now')),
  processado_em   TEXT,
  tx_id           TEXT,
  motivo          TEXT
);

-- ── customers ─────────────────────────────────────────────────────────────────
-- Banco de dados enriquecido de clientes (beneficiários INSS/consignado)
-- Chave primária: CPF (11 dígitos, sem máscara) + data_nascimento (DD/MM/AAAA)
-- Fonte: bases por UF DEZ/2025 + CAGED 2024
CREATE TABLE IF NOT EXISTS customers (
  -- Identificação
  cpf             TEXT NOT NULL,
  data_nascimento TEXT NOT NULL,           -- DD/MM/AAAA
  nome            TEXT NOT NULL DEFAULT '',
  sexo            TEXT NOT NULL DEFAULT '', -- M | F

  -- Contatos (até 3 celulares + 2 fixos + 3 e-mails)
  email           TEXT NOT NULL DEFAULT '',
  email2          TEXT NOT NULL DEFAULT '',
  email3          TEXT NOT NULL DEFAULT '',
  telefone        TEXT NOT NULL DEFAULT '', -- celular principal (só dígitos)
  telefone2       TEXT NOT NULL DEFAULT '',
  telefone3       TEXT NOT NULL DEFAULT '',
  fixo1           TEXT NOT NULL DEFAULT '', -- fixo 1
  fixo2           TEXT NOT NULL DEFAULT '', -- fixo 2

  -- Endereço
  cep             TEXT NOT NULL DEFAULT '', -- 8 dígitos sem traço
  rua             TEXT NOT NULL DEFAULT '',
  numero          TEXT NOT NULL DEFAULT '',
  complemento     TEXT NOT NULL DEFAULT '',
  bairro          TEXT NOT NULL DEFAULT '',
  cidade          TEXT NOT NULL DEFAULT '',
  estado          TEXT NOT NULL DEFAULT '', -- UF 2 chars

  -- Benefício INSS
  beneficio_nb      TEXT NOT NULL DEFAULT '', -- número do benefício
  beneficio_status  TEXT NOT NULL DEFAULT '', -- ATIVO | CESSADO | SUSPENSO
  beneficio_especie TEXT NOT NULL DEFAULT '', -- código espécie (32=aposentadoria, 41=LOAS, etc)

  -- Dados bancários (banco pagador do benefício)
  banco_pagto    TEXT NOT NULL DEFAULT '', -- código banco
  agencia_pagto  TEXT NOT NULL DEFAULT '',
  conta_corrente TEXT NOT NULL DEFAULT '',
  meio_pagto     TEXT NOT NULL DEFAULT '', -- CONTA CORRENTE | CARTÃO | etc

  -- Dados financeiros (consignado)
  margem_disponivel REAL NOT NULL DEFAULT 0, -- margem livre para empréstimo
  margem_rcc        REAL NOT NULL DEFAULT 0, -- margem Cartão de Crédito Consignado
  margem_rmc        REAL NOT NULL DEFAULT 0, -- margem Reserva de Margem Consignável
  valor_beneficio   REAL NOT NULL DEFAULT 0, -- valor bruto do benefício
  renda_mensal      REAL NOT NULL DEFAULT 0, -- renda mensal líquida

  -- Controle interno
  origem          TEXT NOT NULL DEFAULT 'compra', -- 'compra'|'importacao'|'manual'
  total_compras   INTEGER NOT NULL DEFAULT 0,
  ultima_compra   TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),

  PRIMARY KEY (cpf, data_nascimento)
);

-- ── índices ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_affiliates_code   ON affiliates(affiliate_code);
CREATE INDEX IF NOT EXISTS idx_affiliates_email  ON affiliates(email);
CREATE INDEX IF NOT EXISTS idx_subscriptions_code ON subscriptions(affiliate_code);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_sales_user        ON sales(user_id);
CREATE INDEX IF NOT EXISTS idx_sales_code        ON sales(affiliate_code);
CREATE INDEX IF NOT EXISTS idx_withdrawals_user  ON withdrawals(user_id);
CREATE INDEX IF NOT EXISTS idx_products_ativo    ON products(ativo);
CREATE INDEX IF NOT EXISTS idx_customers_cpf     ON customers(cpf);
CREATE INDEX IF NOT EXISTS idx_customers_nasc    ON customers(data_nascimento);
