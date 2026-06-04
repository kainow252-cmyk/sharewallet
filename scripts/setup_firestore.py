#!/usr/bin/env python3
"""
Script de setup completo do Firestore para o Affiliate Wallet.
Execute APÓS criar o Firestore Database no Console:
https://console.cloud.google.com/datastore/setup?project=affiliate-wallet-75853

Uso: python3 setup_firestore.py
"""
import sys
from datetime import datetime, timedelta

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("❌ firebase-admin não instalado. Execute: pip install firebase-admin==7.1.0")
    sys.exit(1)

KEY_FILE = "/opt/flutter/firebase-adminsdk.json"
PROJECT_ID = "affiliate-wallet-75853"

print(f"🔥 Conectando ao Firebase projeto: {PROJECT_ID}")

# Inicializar
try:
    if not firebase_admin._apps:
        cred = credentials.Certificate(KEY_FILE)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    # Teste de conexão
    list(db.collections())
    print("✅ Firestore Database conectado!\n")
except Exception as e:
    if "NOT_FOUND" in str(e) or "does not exist" in str(e):
        print("❌ Firestore Database NÃO criado ainda!")
        print()
        print("👉 Acesse e crie o banco de dados:")
        print("   https://console.cloud.google.com/datastore/setup?project=affiliate-wallet-75853")
        print()
        print("   Passos:")
        print("   1. Selecione 'Cloud Firestore'")
        print("   2. Clique em 'SELECIONAR MODO NATIVO'")
        print("   3. Região: southamerica-east1 (São Paulo)")
        print("   4. Clique em 'CRIAR BANCO DE DADOS'")
        print("   5. Execute este script novamente")
        sys.exit(1)
    elif "SERVICE_DISABLED" in str(e) or "has not been used" in str(e):
        print("❌ Firestore API desabilitada!")
        print()
        print("👉 Habilite a API e crie o banco:")
        print("   https://console.cloud.google.com/datastore/setup?project=affiliate-wallet-75853")
        sys.exit(1)
    else:
        print(f"❌ Erro inesperado: {e}")
        sys.exit(1)

now = datetime.now()

# ── PRODUTOS ───────────────────────────────────────────────────────────────────
print("📦 Criando collection: products")
products = [
    {
        "id": "prod_001",
        "nome": "Seguro Motoboy",
        "valor": 10.0,
        "comissao": 0.20,
        "descricao": "Seguro completo para motoboys com cobertura total em acidentes, roubo e assistência 24h.",
        "categoria": "seguros",
        "chargeType": "pixAutomatico",
        "periodicidade": "mensal",
        "diaCobranca": 5,
        "beneficios": "Cobertura em acidentes|Proteção contra roubo|Assistência 24h|Indenização hospitalar|Suporte emergencial",
        "ativo": True,
        "createdAt": firestore.SERVER_TIMESTAMP,
    },
    {
        "id": "prod_002",
        "nome": "Telesena+",
        "valor": 25.0,
        "comissao": 0.25,
        "descricao": "Acesso premium à plataforma Telesena com sorteios diários e benefícios exclusivos.",
        "categoria": "entretenimento",
        "chargeType": "pixAutomatico",
        "periodicidade": "mensal",
        "diaCobranca": 5,
        "beneficios": "Sorteios diários|Números da sorte|Acesso VIP|Prêmios em dinheiro|Notificações de sorteio",
        "ativo": True,
        "createdAt": firestore.SERVER_TIMESTAMP,
    },
    {
        "id": "prod_003",
        "nome": "Clube de Benefícios",
        "valor": 19.90,
        "comissao": 0.30,
        "descricao": "Descontos em farmácias, supermercados, restaurantes e muito mais todo mês.",
        "categoria": "beneficios",
        "chargeType": "pixAutomatico",
        "periodicidade": "mensal",
        "diaCobranca": 5,
        "beneficios": "Desconto em farmácias|Cashback em supermercados|Restaurantes parceiros|Descontos em combustível|Saúde e bem-estar",
        "ativo": True,
        "createdAt": firestore.SERVER_TIMESTAMP,
    },
    {
        "id": "prod_004",
        "nome": "Assistência Residencial",
        "valor": 15.0,
        "comissao": 0.20,
        "descricao": "Suporte técnico para sua casa: encanamento, elétrica, chaveiro e muito mais.",
        "categoria": "assistencia",
        "chargeType": "pixAutomatico",
        "periodicidade": "mensal",
        "diaCobranca": 5,
        "beneficios": "Encanamento emergencial|Elétrica 24h|Chaveiro|Vidraceiro|Dedetização anual",
        "ativo": True,
        "createdAt": firestore.SERVER_TIMESTAMP,
    },
    {
        "id": "prod_005",
        "nome": "Curso de Finanças",
        "valor": 97.0,
        "comissao": 0.40,
        "descricao": "Aprenda a organizar suas finanças, investir e conquistar sua independência financeira.",
        "categoria": "cursos",
        "chargeType": "unico",
        "beneficios": "Acesso vitalício|40 horas de conteúdo|Certificado|Suporte do professor|Comunidade exclusiva",
        "ativo": True,
        "createdAt": firestore.SERVER_TIMESTAMP,
    },
    {
        "id": "prod_006",
        "nome": "Garantia Estendida Digital",
        "valor": 29.90,
        "comissao": 0.25,
        "descricao": "Proteja seus dispositivos eletrônicos contra danos e defeitos com cobertura total.",
        "categoria": "garantias",
        "chargeType": "pixAvulso",
        "periodicidade": "anual",
        "beneficios": "Celulares e tablets|Notebooks|Smart TVs|Assistência técnica|Reposição garantida",
        "ativo": True,
        "createdAt": firestore.SERVER_TIMESTAMP,
    },
]

for p in products:
    doc_id = p.pop("id")
    db.collection("products").document(doc_id).set(p)
    print(f"  ✅ {doc_id}: {p['nome']}")

# ── AFILIADOS ─────────────────────────────────────────────────────────────────
print("\n👥 Criando collection: affiliates")
affiliates = [
    {
        "id": "aff_001",
        "nome": "João Silva",
        "email": "joao@email.com",
        "cpf": "123.456.789-00",
        "telefone": "(11) 99999-1111",
        "affiliateCode": "ABC123",
        "sponsorCode": None,
        "saldoDisponivel": 125.50,
        "totalComissoes": 342.00,
        "totalSacado": 216.50,
        "totalIndicados": 12,
        "totalAssinaturas": 8,
        "status": "ativo",
        "pixKey": "joao@email.com",
        "createdAt": now - timedelta(days=90),
    },
    {
        "id": "aff_002",
        "nome": "Maria Souza",
        "email": "maria@email.com",
        "cpf": "987.654.321-00",
        "telefone": "(11) 98888-2222",
        "affiliateCode": "XYZ789",
        "sponsorCode": "ABC123",
        "saldoDisponivel": 87.20,
        "totalComissoes": 187.20,
        "totalSacado": 100.00,
        "totalIndicados": 5,
        "totalAssinaturas": 4,
        "status": "ativo",
        "pixKey": "98888-2222",
        "createdAt": now - timedelta(days=45),
    },
    {
        "id": "aff_003",
        "nome": "Carlos Lima",
        "email": "carlos@email.com",
        "cpf": "111.222.333-44",
        "telefone": "(21) 97777-3333",
        "affiliateCode": "DEF456",
        "sponsorCode": "ABC123",
        "saldoDisponivel": 210.00,
        "totalComissoes": 510.00,
        "totalSacado": 300.00,
        "totalIndicados": 21,
        "totalAssinaturas": 15,
        "status": "ativo",
        "pixKey": "carlos@email.com",
        "createdAt": now - timedelta(days=180),
    },
    {
        "id": "aff_004",
        "nome": "Ana Ferreira",
        "email": "ana@email.com",
        "cpf": "444.555.666-77",
        "telefone": "(31) 96666-4444",
        "affiliateCode": "GHI321",
        "sponsorCode": None,
        "saldoDisponivel": 0.0,
        "totalComissoes": 45.00,
        "totalSacado": 45.00,
        "totalIndicados": 2,
        "totalAssinaturas": 1,
        "status": "suspenso",
        "pixKey": None,
        "createdAt": now - timedelta(days=30),
    },
    {
        "id": "aff_005",
        "nome": "Pedro Rocha",
        "email": "pedro@email.com",
        "cpf": "777.888.999-00",
        "telefone": "(85) 95555-5555",
        "affiliateCode": "JKL654",
        "sponsorCode": "DEF456",
        "saldoDisponivel": 340.80,
        "totalComissoes": 780.80,
        "totalSacado": 440.00,
        "totalIndicados": 31,
        "totalAssinaturas": 24,
        "status": "ativo",
        "pixKey": "777.888.999-00",
        "createdAt": now - timedelta(days=270),
    },
]

for a in affiliates:
    doc_id = a.pop("id")
    db.collection("affiliates").document(doc_id).set(a)
    print(f"  ✅ {doc_id}: {a['nome']} ({a['affiliateCode']})")

# ── ASSINATURAS ───────────────────────────────────────────────────────────────
print("\n🔄 Criando collection: subscriptions")
subscriptions = [
    {
        "id": "sub_001",
        "productId": "prod_001",
        "productNome": "Seguro Motoboy",
        "valor": 10.00,
        "comissao": 0.20,
        "affiliateCode": "ABC123",
        "affiliateNome": "Carlos Motoboy",
        "status": "ativa",
        "chargeType": "pixAutomatico",
        "dataInicio": now - timedelta(days=120),
        "proximaCobranca": now + timedelta(days=5),
        "diaCobranca": 5,
        "pixKey": "carlos.moto@gmail.com",
        "wooviSubscriptionId": "woovi_sub_001",
        "motivo": None,
    },
    {
        "id": "sub_002",
        "productId": "prod_002",
        "productNome": "Telesena+",
        "valor": 25.00,
        "comissao": 0.25,
        "affiliateCode": "ABC123",
        "affiliateNome": "Fernanda Costa",
        "status": "ativa",
        "chargeType": "pixAutomatico",
        "dataInicio": now - timedelta(days=90),
        "proximaCobranca": now + timedelta(days=5),
        "diaCobranca": 5,
        "pixKey": "fernanda@email.com",
        "wooviSubscriptionId": "woovi_sub_002",
        "motivo": None,
    },
    {
        "id": "sub_003",
        "productId": "prod_003",
        "productNome": "Clube de Benefícios",
        "valor": 19.90,
        "comissao": 0.30,
        "affiliateCode": "DEF456",
        "affiliateNome": "Roberto Alves",
        "status": "pendente",
        "chargeType": "pixAutomatico",
        "dataInicio": now - timedelta(days=60),
        "proximaCobranca": now + timedelta(days=2),
        "diaCobranca": 5,
        "pixKey": "11999990000",
        "wooviSubscriptionId": "woovi_sub_003",
        "motivo": "Saldo insuficiente",
    },
    {
        "id": "sub_004",
        "productId": "prod_001",
        "productNome": "Seguro Motoboy",
        "valor": 10.00,
        "comissao": 0.20,
        "affiliateCode": "XYZ789",
        "affiliateNome": "Luiz Motoboy",
        "status": "ativa",
        "chargeType": "pixAutomatico",
        "dataInicio": now - timedelta(days=150),
        "proximaCobranca": now + timedelta(days=5),
        "diaCobranca": 5,
        "pixKey": "luiz@gmail.com",
        "wooviSubscriptionId": "woovi_sub_004",
        "motivo": None,
    },
    {
        "id": "sub_005",
        "productId": "prod_004",
        "productNome": "Assistência Residencial",
        "valor": 15.00,
        "comissao": 0.20,
        "affiliateCode": "JKL654",
        "affiliateNome": "Sandra Oliveira",
        "status": "cancelada",
        "chargeType": "pixAutomatico",
        "dataInicio": now - timedelta(days=200),
        "proximaCobranca": now + timedelta(days=30),
        "diaCobranca": 5,
        "pixKey": "sandra@email.com",
        "wooviSubscriptionId": None,
        "motivo": "Cancelado pelo usuário",
    },
]

for s in subscriptions:
    doc_id = s.pop("id")
    db.collection("subscriptions").document(doc_id).set(s)
    print(f"  ✅ {doc_id}: {s['productNome']} — {s['status']}")

# ── SAQUES ─────────────────────────────────────────────────────────────────────
print("\n💸 Criando collection: withdrawals")
withdrawals = [
    {
        "id": "wd_001",
        "affiliateId": "aff_001",
        "affiliateNome": "João Silva",
        "affiliateCode": "ABC123",
        "valor": 125.50,
        "pixKey": "joao@email.com",
        "status": "pendente",
        "solicitadoEm": now - timedelta(hours=3),
        "processadoEm": None,
        "txId": None,
        "motivo": None,
    },
    {
        "id": "wd_002",
        "affiliateId": "aff_005",
        "affiliateNome": "Pedro Rocha",
        "affiliateCode": "JKL654",
        "valor": 200.00,
        "pixKey": "777.888.999-00",
        "status": "pendente",
        "solicitadoEm": now - timedelta(hours=8),
        "processadoEm": None,
        "txId": None,
        "motivo": None,
    },
    {
        "id": "wd_003",
        "affiliateId": "aff_003",
        "affiliateNome": "Carlos Lima",
        "affiliateCode": "DEF456",
        "valor": 150.00,
        "pixKey": "carlos@email.com",
        "status": "aprovado",
        "solicitadoEm": now - timedelta(days=2),
        "processadoEm": now - timedelta(days=1),
        "txId": "woovi_tx_abc123",
        "motivo": None,
    },
    {
        "id": "wd_004",
        "affiliateId": "aff_002",
        "affiliateNome": "Maria Souza",
        "affiliateCode": "XYZ789",
        "valor": 100.00,
        "pixKey": "98888-2222",
        "status": "aprovado",
        "solicitadoEm": now - timedelta(days=5),
        "processadoEm": now - timedelta(days=4),
        "txId": "woovi_tx_def456",
        "motivo": None,
    },
    {
        "id": "wd_005",
        "affiliateId": "aff_004",
        "affiliateNome": "Ana Ferreira",
        "affiliateCode": "GHI321",
        "valor": 45.00,
        "pixKey": "",
        "status": "recusado",
        "solicitadoEm": now - timedelta(days=7),
        "processadoEm": now - timedelta(days=6),
        "txId": None,
        "motivo": "Conta suspensa — aguardando verificação",
    },
]

for w in withdrawals:
    doc_id = w.pop("id")
    db.collection("withdrawals").document(doc_id).set(w)
    print(f"  ✅ {doc_id}: R$ {w['valor']:.2f} — {w['status']}")

# ── MÉTRICAS ───────────────────────────────────────────────────────────────────
print("\n📊 Criando collection: metrics (dashboard)")
db.collection("metrics").document("current").set({
    "receitaTotal": 12450.00,
    "receitaMes": 3280.00,
    "comissoesTotal": 2490.00,
    "comissoesMes": 656.00,
    "totalAfiliados": 47,
    "afiliadosAtivos": 38,
    "totalAssinaturas": 183,
    "assinaturasAtivas": 161,
    "assinaturasPendentes": 12,
    "mrr": 1610.00,
    "saquesPendentes": 5,
    "valorSaquesPendentes": 742.50,
    "updatedAt": firestore.SERVER_TIMESTAMP,
})
print("  ✅ metrics/current criado")

# ── CONFIGURAÇÕES GLOBAIS ─────────────────────────────────────────────────────
print("\n⚙️  Criando collection: config")
db.collection("config").document("global").set({
    "saqueMinimo": 100.0,
    "wooviEnabled": True,
    "pixAutomaticoEnabled": True,
    "diaCobrancaPadrao": 5,
    "versaoApp": "1.0.0",
    "updatedAt": firestore.SERVER_TIMESTAMP,
})
print("  ✅ config/global criado")

print("\n" + "="*60)
print("🎉 SETUP COMPLETO!")
print("="*60)
print(f"\n✅ Collections criadas:")
print(f"   📦 products      — {len(products)} produtos")
print(f"   👥 affiliates    — {len(affiliates)} afiliados")
print(f"   🔄 subscriptions — {len(subscriptions)} assinaturas")
print(f"   💸 withdrawals   — {len(withdrawals)} saques")
print(f"   📊 metrics       — 1 documento")
print(f"   ⚙️  config        — 1 documento")
print(f"\n🔗 Visualize no Firestore:")
print(f"   https://console.firebase.google.com/project/{PROJECT_ID}/firestore")
