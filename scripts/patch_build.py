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
  4. Copia web/pwa_install.js para build/web/pwa_install.js
  5. Copia web/sw_version.js para build/web/sw_version.js (com APP_VERSION injetada)
     → O SW de versão detecta novos deploys e exibe banner "Atualizar app"
"""

import re
import shutil
import os
import hashlib
import datetime

BUILD_DIR = os.path.join(os.path.dirname(__file__), '..', 'build', 'web')
WEB_DIR   = os.path.join(os.path.dirname(__file__), '..', 'web')


def _app_version():
    """
    Gera uma versão única para este build combinando:
      - timestamp UTC (YYYYMMDD-HHMM)
      - hash curto do main.dart.js (se existir) para garantir unicidade real
    Exemplo: "20250115-1430-a3f9b2"
    """
    ts = datetime.datetime.utcnow().strftime('%Y%m%d-%H%M')
    main_js = os.path.join(BUILD_DIR, 'main.dart.js')
    if os.path.exists(main_js):
        with open(main_js, 'rb') as f:
            h = hashlib.sha256(f.read(65536)).hexdigest()[:6]  # primeiros 64KB
        return f'{ts}-{h}'
    return ts


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


def copy_pwa_install():
    """Copia pwa_install.js (banner instalar/atualizar PWA) para o build."""
    src = os.path.join(WEB_DIR, 'pwa_install.js')
    dst = os.path.join(BUILD_DIR, 'pwa_install.js')
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print('OK: pwa_install.js copiado para build/web/')
    else:
        print('SKIP: web/pwa_install.js não encontrado')


def deploy_version_sw():
    """
    Copia sw_version.js para build/web/ e injeta a APP_VERSION real.
    O placeholder __APP_VERSION__ é substituído por um hash único do build.
    """
    src = os.path.join(WEB_DIR, 'sw_version.js')
    dst = os.path.join(BUILD_DIR, 'sw_version.js')

    if not os.path.exists(src):
        print('SKIP: web/sw_version.js não encontrado')
        return

    version = _app_version()

    with open(src, 'r') as f:
        content = f.read()

    content = content.replace("'__APP_VERSION__'", f"'{version}'")

    with open(dst, 'w') as f:
        f.write(content)

    print(f'OK: sw_version.js deployado — APP_VERSION={version}')


if __name__ == '__main__':
    patch_bootstrap()
    deploy_kill_switch_sw()
    copy_headers()
    copy_pwa_install()
    deploy_version_sw()
    print('Patches aplicados com sucesso.')
