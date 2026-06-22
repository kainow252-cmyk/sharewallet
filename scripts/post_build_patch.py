#!/usr/bin/env python3
"""
Post-build patch script para o ShareWallet Flutter Web.

Aplica patches cirúrgicos no build/web após `flutter build web --release`:

1. main.dart.js: remove o call $.h4().$1("Could not find a set of Noto fonts...")
   (warning emitido de dentro do Dart compilado, não suprimível via JS interceptor)

2. flutter_service_worker.js: atualiza o hash do main.dart.js patchado e muda
   o CACHE_NAME com timestamp para forçar invalidação do cache do browser

3. flutter_bootstrap.js: remove serviceWorkerSettings para desabilitar o SW
   (impede que versões antigas de main.dart.js sejam servidas do cache do SW)

Execute APÓS flutter build web --release:
  python3 scripts/post_build_patch.py

O script é idempotente: pode ser rodado múltiplas vezes sem efeito colateral.
"""

import hashlib
import re
import sys
import time
from pathlib import Path

BUILD_WEB     = Path(__file__).parent.parent / "build" / "web"
MAIN_JS       = BUILD_WEB / "main.dart.js"
SW_JS         = BUILD_WEB / "flutter_service_worker.js"
BOOTSTRAP_JS  = BUILD_WEB / "flutter_bootstrap.js"
INDEX_HTML    = BUILD_WEB / "index.html"

# ── Patch 1: remove Noto warning call do main.dart.js ──────────────────────
MAIN_JS_PATCHES = [
    {
        "description": "Suppress Noto fonts console.warn (emitido pelo engine Dart)",
        # O Dart compilado chama $.h4().$1("Could not find a set of Noto fonts...")
        # $.h4() é lazy getter → A.bnf(window.console) → new A.am5(window.console)
        # A.am5.prototype.$1 = function(a){ return this.a.warn(a) }
        # Substituir pelo no-op (void 0) elimina o warning na fonte.
        "old": (
            '$.h4().$1("Could not find a set of Noto fonts to display all missing characters. '
            'Please add a font asset for the missing characters. '
            'See: https://flutter.dev/docs/cookbook/design/fonts")'
        ),
        "new": '(void 0)/*noto-warn-suppressed*/',
        "marker": "noto-warn-suppressed",
    },
]

# ── Patch 2: desabilita Service Worker no flutter_bootstrap.js ─────────────
SW_DISABLE_OLD = '_flutter.loader.load({\n  serviceWorkerSettings: {'
SW_DISABLE_MARKER = "/*sw-disabled*/"

# ── Patch 3: script de desregistro de SW no index.html ─────────────────────
SW_UNREGISTER_SCRIPT = """\
  <script>
    // Desregistra Service Workers antigos que possam estar servindo main.dart.js
    // desatualizado do cache. O SW e desabilitado neste build para garantir que
    // o patch pos-build seja sempre servido diretamente do servidor.
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function(registrations) {
        for (var r of registrations) { r.unregister(); }
      });
      if ('caches' in window) {
        caches.keys().then(function(names) {
          for (var name of names) {
            if (name.indexOf('flutter') !== -1) { caches.delete(name); }
          }
        });
      }
    }
  </script>
"""
SW_UNREGISTER_MARKER = "/*sw-unregister*/"


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


# ── Step 1 ──────────────────────────────────────────────────────────────────
def patch_main_js() -> bool:
    """Aplica patches no main.dart.js. Retorna True se alguma mudança foi feita."""
    if not MAIN_JS.exists():
        print(f"  ERROR: {MAIN_JS} not found. Run `flutter build web --release` first.")
        sys.exit(1)

    content = MAIN_JS.read_text(encoding="utf-8")
    changed = False

    for p in MAIN_JS_PATCHES:
        marker = p.get("marker", "")
        if marker and f"/*{marker}*/" in content:
            print(f"  [SKIP - already applied] {p['description']}")
            continue

        if p["old"] not in content:
            print(f"  [WARN - not found] {p['description']}")
            continue

        count = content.count(p["old"])
        content = content.replace(p["old"], p["new"], 1)
        print(f"  [PATCHED x{count}] {p['description']}")
        changed = True

    if changed:
        MAIN_JS.write_text(content, encoding="utf-8")
        print(f"  Written: {MAIN_JS.name}")

    return changed


# ── Step 2 ──────────────────────────────────────────────────────────────────
def update_service_worker(main_js_changed: bool):
    """Atualiza hash do main.dart.js no SW e muda CACHE_NAME com timestamp."""
    if not SW_JS.exists():
        print(f"  [SKIP] {SW_JS.name} not found")
        return

    sw = SW_JS.read_text(encoding="utf-8")

    # 2a. Atualizar hash do main.dart.js
    new_hash = md5(MAIN_JS)
    hash_pattern = r'("main\.dart\.js"\s*:\s*")([^"]+)(")'
    match = re.search(hash_pattern, sw)
    if match:
        old_hash = match.group(2)
        if old_hash != new_hash:
            sw = sw.replace(f'"main.dart.js": "{old_hash}"', f'"main.dart.js": "{new_hash}"')
            print(f"  [UPDATED] main.dart.js hash: {old_hash[:8]}... → {new_hash[:8]}...")
        else:
            print(f"  [SKIP] main.dart.js hash already up-to-date")

    # 2b. Mudar CACHE_NAME com timestamp para forçar invalidação do cache
    ts = int(time.time())
    cache_name_pattern = r"const CACHE_NAME = 'flutter-app-cache[^']*';"
    cache_name_new = f"const CACHE_NAME = 'flutter-app-cache-{ts}';"
    if re.search(cache_name_pattern, sw):
        sw = re.sub(cache_name_pattern, cache_name_new, sw)
        print(f"  [UPDATED] CACHE_NAME → flutter-app-cache-{ts}")
    else:
        print(f"  [SKIP] CACHE_NAME pattern not found")

    SW_JS.write_text(sw, encoding="utf-8")


# ── Step 3 ──────────────────────────────────────────────────────────────────
def disable_service_worker_in_bootstrap():
    """Remove serviceWorkerSettings do flutter_bootstrap.js para desativar o SW."""
    if not BOOTSTRAP_JS.exists():
        print(f"  [SKIP] {BOOTSTRAP_JS.name} not found")
        return

    content = BOOTSTRAP_JS.read_text(encoding="utf-8")

    if SW_DISABLE_MARKER in content:
        print(f"  [SKIP - already applied] SW disabled in {BOOTSTRAP_JS.name}")
        return

    # O bloco pode ter variações de whitespace; buscar pela abertura
    if SW_DISABLE_OLD not in content:
        print(f"  [SKIP] serviceWorkerSettings block not found in {BOOTSTRAP_JS.name}")
        return

    # Encontrar o bloco completo e substituir
    idx = content.find(SW_DISABLE_OLD)
    # Achar o fechamento do objeto + "})" + ";"
    end_pattern = re.compile(r'\}\s*\}\s*\)\s*;', re.DOTALL)
    m = end_pattern.search(content, idx)
    if not m:
        print(f"  [SKIP] Could not find end of serviceWorkerSettings block")
        return

    old_block = content[idx:m.end()]
    new_block = f"_flutter.loader.load({{{SW_DISABLE_MARKER}}});"
    content = content[:idx] + new_block + content[m.end():]

    BOOTSTRAP_JS.write_text(content, encoding="utf-8")
    print(f"  [PATCHED] serviceWorkerSettings removed from {BOOTSTRAP_JS.name}")


# ── Step 4 ──────────────────────────────────────────────────────────────────
def inject_sw_unregister_in_index():
    """Injeta script de desregistro de SW no index.html logo após <head>."""
    if not INDEX_HTML.exists():
        print(f"  [SKIP] {INDEX_HTML.name} not found")
        return

    content = INDEX_HTML.read_text(encoding="utf-8")

    if SW_UNREGISTER_MARKER in content:
        print(f"  [SKIP - already applied] SW unregister in {INDEX_HTML.name}")
        return

    old = "<head>\n"
    marked_script = SW_UNREGISTER_SCRIPT.replace(
        "if ('serviceWorker' in navigator) {",
        f"if ('serviceWorker' in navigator) {{ {SW_UNREGISTER_MARKER}"
    )
    new = "<head>\n" + marked_script

    if old not in content:
        print(f"  [SKIP] <head> not found in {INDEX_HTML.name}")
        return

    content = content.replace(old, new, 1)
    INDEX_HTML.write_text(content, encoding="utf-8")
    print(f"  [PATCHED] SW unregister script injected into {INDEX_HTML.name}")


# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("=== Post-build patch ===")
    print(f"Target: {BUILD_WEB}\n")

    print("[1] Patching main.dart.js (remove Noto warn call)...")
    patched = patch_main_js()

    print("\n[2] Updating flutter_service_worker.js (hash + CACHE_NAME)...")
    update_service_worker(patched)

    print("\n[3] Disabling Service Worker in flutter_bootstrap.js...")
    disable_service_worker_in_bootstrap()

    print("\n[4] Injecting SW unregister in index.html...")
    inject_sw_unregister_in_index()

    print("\n=== Done ===")


if __name__ == "__main__":
    main()
