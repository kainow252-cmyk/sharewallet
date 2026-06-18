#!/usr/bin/env python3
"""
post_build.py — Pós-processamento do build Flutter web.

Problema resolvido:
  O Cloudflare CDN cacheia MaterialIcons-Regular.otf com Cache-Control: immutable
  (ou stale) e fica servindo a versão antiga mesmo após novo deploy, porque o
  nome do arquivo nunca muda (tree-shaking altera o conteúdo mas não o nome).

Solução:
  Renomeia MaterialIcons-Regular.otf (e CupertinoIcons.ttf) para incluir hash
  MD5 curto no nome — ex: MaterialIcons-Regular.e20afb18.otf
  Atualiza FontManifest.json para apontar para o novo nome.
  Cada build com ícones diferentes → URL diferente → CDN nunca confunde versões.

Uso:
  python3 scripts/post_build.py
  (executar após: flutter build web --release --base-href /app/)
"""

import hashlib
import json
import os
import shutil
import sys

BUILD_WEB = os.path.join(os.path.dirname(__file__), "..", "build", "web")
FONTS_DIR = os.path.join(BUILD_WEB, "assets", "fonts")
FONT_MANIFEST = os.path.join(BUILD_WEB, "assets", "FontManifest.json")

FONTS_TO_VERSION = [
    "MaterialIcons-Regular.otf",
    "CupertinoIcons.ttf",
]


def md5_short(path: str, length: int = 8) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:length]


def rename_with_hash(fonts_dir: str) -> dict[str, str]:
    """Renomeia fontes com hash MD5. Retorna mapa {nome_original: novo_nome}."""
    renames = {}
    for fname in FONTS_TO_VERSION:
        src = os.path.join(fonts_dir, fname)
        if not os.path.exists(src):
            print(f"  [skip] {fname} não encontrado")
            continue
        base, ext = os.path.splitext(fname)
        h = md5_short(src)
        new_name = f"{base}.{h}{ext}"
        dst = os.path.join(fonts_dir, new_name)
        shutil.copy2(src, dst)
        os.remove(src)
        renames[fname] = new_name
        size_kb = os.path.getsize(dst) / 1024
        print(f"  [ok] {fname} → {new_name} ({size_kb:.1f} KB)")
    return renames


def update_font_manifest(manifest_path: str, renames: dict[str, str]) -> None:
    """Atualiza FontManifest.json com os novos nomes das fontes."""
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    changed = 0
    for family in manifest:
        for font_entry in family.get("fonts", []):
            asset = font_entry.get("asset", "")
            # asset é relativo: "fonts/MaterialIcons-Regular.otf"
            basename = os.path.basename(asset)
            if basename in renames:
                new_basename = renames[basename]
                new_asset = asset.replace(basename, new_basename)
                print(f"  [manifest] {asset} → {new_asset}")
                font_entry["asset"] = new_asset
                changed += 1

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, separators=(",", ":"))

    print(f"  [manifest] {changed} entrada(s) atualizada(s) em FontManifest.json")


def main() -> int:
    print("=== post_build.py: versionamento de fontes ===")

    if not os.path.isdir(BUILD_WEB):
        print(f"ERRO: build/web não encontrado em {BUILD_WEB}")
        print("Execute antes: flutter build web --release --base-href /app/")
        return 1

    if not os.path.isfile(FONT_MANIFEST):
        print(f"ERRO: FontManifest.json não encontrado em {FONT_MANIFEST}")
        return 1

    print(f"Diretório: {os.path.abspath(BUILD_WEB)}")
    print("")

    print("1. Renomeando fontes com hash MD5...")
    renames = rename_with_hash(FONTS_DIR)

    if not renames:
        print("  Nenhuma fonte para renomear.")
        return 0

    print("")
    print("2. Atualizando FontManifest.json...")
    update_font_manifest(FONT_MANIFEST, renames)

    print("")
    print("✅ Pós-build concluído. Fontes versionadas:")
    for orig, new in renames.items():
        print(f"   {orig} → {new}")
    print("")
    print("Próximo passo: deploy com wrangler pages deploy")
    return 0


if __name__ == "__main__":
    sys.exit(main())
