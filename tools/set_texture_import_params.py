# -*- coding: utf-8 -*-
"""Deja los .import de las texturas de nivel como los necesita el juego.

Las texturas de assets/textures/packs/ se cargan por codigo (TextureCatalog),
asi que el editor nunca las "detecta en 3D" y quedaban importadas lossless y
sin mipmaps: pesadas en el PCK, sin compresion en VRAM y con el filtro
anisotropico pidiendo mipmaps que no existian. Este script fija en cada
.import los parametros de una textura de superficie 3D:

  compress/mode=2         VRAM Compressed (S3TC/BPTC en escritorio y web)
  mipmaps/generate=true   filtrado correcto a distancia
  detect_3d/compress_to=0 ya esta decidido, no hay nada que detectar

Uso (desde la raiz del proyecto):
  python tools/set_texture_import_params.py
  "<godot>" --headless --path . --import      # regenera los .ctex

tests/texture_import_smoke_test.gd comprueba que todas las entradas del
catalogo cumplan estos valores.
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKS = os.path.join(ROOT, "assets", "textures", "packs")
PARAMS = {
    "compress/mode": "2",
    "mipmaps/generate": "true",
    "detect_3d/compress_to": "0",
}


def patch(path):
    text = io.open(path, encoding="utf-8").read()
    changed = False
    for key, value in PARAMS.items():
        pattern = re.compile(r"^%s=.*$" % re.escape(key), re.M)
        if not pattern.search(text):
            raise SystemExit("%s: falta %s" % (path, key))
        new_text = pattern.sub("%s=%s" % (key, value), text)
        if new_text != text:
            text = new_text
            changed = True
    if changed:
        io.open(path, "w", encoding="utf-8", newline="\n").write(text)
    return changed


def main():
    changed = total = 0
    for folder, _dirs, files in os.walk(PACKS):
        for name in files:
            if not name.endswith(".png.import"):
                continue
            total += 1
            if patch(os.path.join(folder, name)):
                changed += 1
    print("%d .import revisados, %d actualizados" % (total, changed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
