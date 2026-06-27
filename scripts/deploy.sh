#!/bin/bash
# deploy.sh — Build + Patch + Deploy completo do ShareWallet Web
# Uso: bash scripts/deploy.sh
set -e

echo "=== 1/4 Build Flutter Web ==="
flutter build web --release --base-href /app/

echo ""
echo "=== 2/4 Aplicar Patches pós-build ==="
python3 scripts/patch_build.py

echo ""
echo "=== 3/4 Deploy Cloudflare Pages ==="
npx wrangler pages deploy build/web --project-name sharewallet-app --commit-dirty=true

echo ""
echo "=== 4/4 Deploy Cloudflare Worker (API) ==="
npx wrangler deploy sharewallet-api-clean.js --config wrangler-api.toml

echo ""
echo "✅ Deploy completo!"
echo "   App: https://sharewallet.com.br/app/"
echo "   API: https://api.sharewallet.com.br"
