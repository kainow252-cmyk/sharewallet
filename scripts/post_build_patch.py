#!/usr/bin/env python3
"""
Post-build patch script para o ShareWallet Flutter Web.

Aplica patches cirúrgicos no main.dart.js compilado para eliminar
warnings inofensivos que não podem ser suprimidos via JS interceptor
(pois são emitidos de dentro do Dart compilado / CanvasKit).

Execute APÓS flutter build web --release:
  python3 scripts/post_build_patch.py

O script é idempotente: pode ser rodado múltiplas vezes sem efeito colateral.
"""

import hashlib
import re
import sys
from pathlib import Path

BUILD_WEB = Path(__file__).parent.parent / "build" / "web"
MAIN_JS   = BUILD_WEB / "main.dart.js"
SW_JS     = BUILD_WEB / "flutter_service_worker.js"

PATCHES = [
    {
        "description": "Suppress Noto fonts console.warn (emitido pelo engine Dart)",
        # O Dart compilado chama $.h4().$1("Could not find a set of Noto fonts...")
        # $.h4() retorna window.console via lazy getter; $1 chama .warn()
        # Substituir pelo no-op (void 0) elimina o warning na fonte.
        "old": (
            '$.h4().$1("Could not find a set of Noto fonts to display all missing characters. '
            'Please add a font asset for the missing characters. '
            'See: https://flutter.dev/docs/cookbook/design/fonts")'
        ),
        "new": '(void 0)/*noto-warn-suppressed*/',
    },
]


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def patch_main_js() -> bool:
    """Aplica todos os patches no main.dart.js. Retorna True se algum patch foi aplicado."""
    if not MAIN_JS.exists():
        print(f"ERROR: {MAIN_JS} not found. Run `flutter build web --release` first.")
        sys.exit(1)

    content = MAIN_JS.read_text(encoding="utf-8")
    changed = False

    for p in PATCHES:
        marker = p["new"].split("*/")[0].lstrip("(void 0)/*") if "/*" in p["new"] else None
        already_applied = marker and f"/*{marker}*/" in content

        if already_applied:
            print(f"  [SKIP - already applied] {p['description']}")
            continue

        if p["old"] not in content:
            print(f"  [WARN - not found] {p['description']}")
            print(f"    Target string not present in {MAIN_JS.name}")
            continue

        count = content.count(p["old"])
        content = content.replace(p["old"], p["new"], 1)
        print(f"  [PATCHED x{count}] {p['description']}")
        changed = True

    if changed:
        MAIN_JS.write_text(content, encoding="utf-8")
        print(f"  Written: {MAIN_JS}")

    return changed


def update_service_worker_hash():
    """Recalcula o hash do main.dart.js patchado e atualiza o flutter_service_worker.js."""
    if not SW_JS.exists():
        print(f"  [SKIP] {SW_JS.name} not found")
        return

    new_hash = md5(MAIN_JS)
    sw_content = SW_JS.read_text(encoding="utf-8")

    pattern = r'("main\.dart\.js"\s*:\s*")([^"]+)(")'
    match = re.search(pattern, sw_content)
    if not match:
        print(f"  [SKIP] main.dart.js hash not found in {SW_JS.name}")
        return

    old_hash = match.group(2)
    if old_hash == new_hash:
        print(f"  [SKIP] Service worker hash already up-to-date ({new_hash[:8]}...)")
        return

    new_sw = sw_content.replace(
        f'"main.dart.js": "{old_hash}"',
        f'"main.dart.js": "{new_hash}"',
    )
    SW_JS.write_text(new_sw, encoding="utf-8")
    print(f"  [UPDATED] Service worker hash: {old_hash[:8]}... -> {new_hash[:8]}...")


def main():
    print("=== Post-build patch ===")
    print(f"Target: {BUILD_WEB}")

    print("\n[1] Patching main.dart.js...")
    patched = patch_main_js()

    print("\n[2] Updating service worker hash...")
    if patched:
        update_service_worker_hash()
    else:
        print("  [SKIP] No patches applied, hash unchanged")

    print("\n=== Done ===")


if __name__ == "__main__":
    main()
