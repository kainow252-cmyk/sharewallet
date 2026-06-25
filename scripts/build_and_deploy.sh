#!/bin/bash
# build_and_deploy.sh — Build completo do ShareWallet Flutter Web
#
# USO:
#   bash scripts/build_and_deploy.sh
#
# ETAPAS:
#   1. flutter build web --release --base-href /app/
#   2. python3 scripts/patch_build.py   → remove serviceWorkerSettings (cache do browser)
#   3. npx wrangler pages deploy        → deploy para Cloudflare Pages
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== ShareWallet — Build & Deploy ==="
echo "Diretório: $PROJECT_DIR"
echo ""

# 1. Flutter build
echo "[1/3] flutter build web --release --base-href /app/ ..."
cd "$PROJECT_DIR"
flutter build web --release --base-href /app/
echo ""

# 2. Patch pós-build (remove SW, headers anti-cache)
echo "[2/3] Aplicando patches pós-build ..."
python3 scripts/patch_build.py
echo ""

# 3. Deploy
echo "[3/3] Deploy para Cloudflare Pages ..."
npx wrangler pages deploy build/web --project-name=sharewallet-app --commit-dirty=true
echo ""
echo "=== Deploy concluído ==="
