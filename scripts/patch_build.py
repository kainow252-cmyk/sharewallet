#!/usr/bin/env python3
"""
patch_build.py — Aplica patches pós-build no Flutter web.
Execute após: flutter build web --release --base-href /app/

Patches aplicados:
  1. Remove serviceWorkerSettings do flutter_bootstrap.js
     → Sem isso, o Flutter registra um SW que cacheia main.dart.js
       e serve código antigo mesmo após novos deploys.
  2. Substitui flutter_service_worker.js por SW suicida (web/flutter_service_worker.js)
     → O SW antigo nos browsers dos usuários vai detectar o novo arquivo,
       instalá-lo, e ele apaga todos os caches + se auto-desregistra.
     → Garante que nenhum browser fique preso com código antigo.
  3. Copia web/_headers para build/web/_headers (anti-cache headers)
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
    # O flutter_bootstrap.js gerado pelo Flutter pode ter duas formas:
    # 1. Minificada: _flutter.loader.load({serviceWorkerSettings:{serviceWorkerVersion:"..."}})
    # 2. Com quebras de linha: _flutter.loader.load({\n  serviceWorkerSettings: {\n    ...\n  }\n});
    # O re.DOTALL faz o '.' casar com '\n', permitindo capturar ambos os formatos.
    patched = re.sub(
        r'_flutter\.loader\.load\(\{[\s\n]*serviceWorkerSettings\s*:\s*\{[^}]*\}[\s\n]*\}\)',
        '_flutter.loader.load({})',
        content,
        flags=re.DOTALL,
    )

    if patched != content:
        with open(path, 'w') as f:
            f.write(patched)
        print('OK: flutter_bootstrap.js — serviceWorkerSettings removido')
    else:
        print('SKIP: flutter_bootstrap.js — já sem serviceWorkerSettings ou padrão não encontrado')


def deploy_kill_switch_sw():
    """
    Substitui o flutter_service_worker.js gerado pelo Flutter pelo SW suicida.

    O SW suicida (web/flutter_service_worker.js) quando ativado:
      1. Apaga todos os caches do browser
      2. Força reload de todas as abas abertas
      3. Se auto-desregistra

    Isso garante que browsers com SW antigo limpem o cache automaticamente
    na próxima vez que o SW verificar atualizações (a cada 24h ou na próxima visita).
    """
    src = os.path.join(WEB_DIR, 'flutter_service_worker.js')
    dst = os.path.join(BUILD_DIR, 'flutter_service_worker.js')

    if not os.path.exists(src):
        print('SKIP: web/flutter_service_worker.js não encontrado — SW suicida não deployado')
        return

    shutil.copy2(src, dst)
    print('OK: flutter_service_worker.js substituído pelo SW suicida (apaga caches + auto-destrói)')


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
    deploy_kill_switch_sw()
    copy_headers()
    print('Patches aplicados com sucesso.')
