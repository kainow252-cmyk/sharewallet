#!/usr/bin/env python3
"""
patch_build.py — Aplica patches pós-build no Flutter web.
Execute após: flutter build web --release --base-href /app/

Patches aplicados:
  1. Remove serviceWorkerSettings do flutter_bootstrap.js
     → Elimina o timeout de 4000ms "prepareServiceWorker took more than 4000ms"
     → O unregister no index.html já limpa caches antigos
  2. Copia web/_headers para build/web/_headers (anti-cache headers)
"""

import re
import shutil
import os

BUILD_DIR = os.path.join(os.path.dirname(__file__), '..', 'build', 'web')
WEB_DIR   = os.path.join(os.path.dirname(__file__), '..', 'web')

def patch_bootstrap():
    path = os.path.join(BUILD_DIR, 'flutter_bootstrap.js')
    if not os.path.exists(path):
        print(f'SKIP: {path} not found')
        return

    with open(path, 'r') as f:
        content = f.read()

    # Remove serviceWorkerSettings block
    patched = re.sub(
        r'_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[^}]*\}\s*\}\)',
        '_flutter.loader.load({})',
        content
    )

    if patched != content:
        with open(path, 'w') as f:
            f.write(patched)
        print('OK: flutter_bootstrap.js — serviceWorkerSettings removido')
    else:
        print('SKIP: flutter_bootstrap.js — já sem serviceWorkerSettings ou padrão não encontrado')

def copy_headers():
    src = os.path.join(WEB_DIR, '_headers')
    dst = os.path.join(BUILD_DIR, '_headers')
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f'OK: _headers copiado para build/web/')
    else:
        print(f'SKIP: web/_headers não encontrado')

if __name__ == '__main__':
    patch_bootstrap()
    copy_headers()
    print('Patches aplicados com sucesso.')
