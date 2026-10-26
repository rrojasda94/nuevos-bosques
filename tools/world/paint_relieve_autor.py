"""Relieve del dueño en la autoría del Valle del Sara: Larr, cordillera occidental y Azhin (ADR 0014 §4).

Datos del dueño (2026-10-26; docs/design/world/sur-lenfi.md, "Lugares con nombre"):
- Larr: "La cordillera norte de todo el Sur Lenfi es Larr y es una pared impenetrable." Borde norte
  de la región: franja de cumbre continua de lado a lado, LARR_ROWS px de grosor (1 px = 4 casillas),
  sin huecos. El agua que llegaba al borde norte (el Sara) se corta al pie de Larr: el río nace ahí
  (el validador da por unido un río que toca una cumbre). Debajo, FOOT_ROWS px de nivel 2 como
  mínimo (bajo Larr el relieve es de montaña; mapa de biomas del dueño).
- Cordillera occidental (Urd Gumnavis, a caballo con Dorias): "colinas y montañas bastante
  transitables". No es barrera: en la franja x < STRIP_W, desde el pie de Larr hasta y < STRIP_END
  (casi la costa), no hay cumbres (pasan a nivel 3) y el nivel 0 sube a 1. Así la franja queda en
  niveles 1-3. Los nacimientos de sus afluentes ya no son cumbres (paint_afluentes.py, "manantial": nacen dentro de la franja).
- Azhin: villa pequeña, la más septentrional, en el extremo norte de la cordillera occidental,
  pegada a Larr, en Lean. Fila villa_azhin de lugares.csv en AZHIN, y un camino (AZHIN_ROAD) hasta
  la red pintada más cercana.
- Tarca de Azhin (dueño, 2026-10-26: "es un lugar mencionado en algunas partes de la historia
  cuando te encuentras con ledai de Estrellazul"; "a 20 o más casillas, pero más al oeste, en las
  montañas, en lo alto de una montaña"): fila tarca_azhin, tipo tarca, en TARCA, en nivel 3 (lo
  más alto que se pisa) y sin nada más alto alrededor.

Modifica las PNG de data/world/regions/valle_del_sara/ y lugares.csv. Hay que ejecutarlo DESPUÉS de
tools/world/paint_afluentes.py (que con --from-ref rehace altura, agua y caminos desde la base y
borraría esto). Es idempotente: volver a ejecutarlo sobre su salida no cambia nada.

Uso (desde la raíz del repo; necesita Pillow):
    python tools/world/paint_afluentes.py --from-ref
    python tools/world/paint_relieve_autor.py
    bash tools/world/preview_region.sh valle_del_sara 7
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REGION_DIR = ROOT / "data" / "world" / "regions" / "valle_del_sara"
PALETTE = ROOT / "data" / "world" / "authoring_palette.json"

LARR_ROWS = 3      # px de cumbre en el borde norte (12 casillas)
FOOT_ROWS = 3      # px bajo Larr con nivel 2 como mínimo
STRIP_W = 40       # px de ancho de la cordillera occidental (2 chunks)
STRIP_END = 260    # la franja llega hasta esta fila (excluida): casi la costa
# Tests que leen estas constantes: tests/unit/world/test_region_authoring.gd (LARR_ROWS, STRIP_*).

AZHIN = (16, 4)
AZHIN_ROW = ("villa_azhin,Azhin,villa,{x},{y},,,\"Villa pequeña, la más septentrional del Valle del Sara: "
             "extremo norte de la cordillera occidental (Urd Gumnavis), al pie de Larr, en Lean (dueño, #182). "
             "De aquí salió la expansión de los Nuevos Bosques (los ledai de la Tarca de Trastas, en el lado de Dorias). "
             "Tiene una tarca (templo garelino). Fila escrita por tools/world/paint_relieve_autor.py.\"")
# Camino de Azhin a la red pintada: puntos de control (x, y) en px, trazo 4-conectado. El último
# punto toca un camino que ya existe (el de Lean, al norte del 7mo del Sara).
AZHIN_ROAD = [(16, 5), (16, 12), (44, 12), (51, 29)]
# En lo alto de la montaña al oeste de Azhin (dueño, 2026-10-26: "a 20 o más casillas, pero más al
# oeste, en las montañas, en lo alto de una montaña"): nivel 3, sin cumbre, a unos 9 px (36 casillas).
TARCA = (8, 8)
TARCA_MIN_PX = 5  # 20 casillas
TARCA_ROW = ("tarca_azhin,Tarca de Azhin,tarca,{x},{y},,,\"Tarca (templo garelino) de Azhin, en lo alto de la montaña al oeste de la villa. "
             "Aparece en la historia en el encuentro con los ledai de Estrellazul (dueño, 2026-10-26). "
             "Fila escrita por tools/world/paint_relieve_autor.py.\"")


def hex_rgba(h: str) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def line4(a: tuple[int, int], b: tuple[int, int]) -> list[tuple[int, int]]:
    """Bresenham de a a b (sin a), 4-conectado (como en paint_afluentes.py)."""
    x0, y0 = a
    x1, y1 = b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x1 > x0 else -1
    sy = 1 if y1 > y0 else -1
    err = dx + dy
    out: list[tuple[int, int]] = []
    x, y = x0, y0
    while (x, y) != (x1, y1):
        e2 = 2 * err
        step_x = e2 >= dy
        step_y = e2 <= dx
        if step_x and step_y:
            err += dy + dx
            x += sx
            out.append((x, y))
            y += sy
        elif step_x:
            err += dy
            x += sx
        else:
            err += dx
            y += sy
        out.append((x, y))
    return out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    pal = json.loads(PALETTE.read_text(encoding="utf-8"))["layers"]
    height_c = {k: hex_rgba(v) for k, v in pal["height"]["colors"].items()}
    road_c = {k: hex_rgba(v) for k, v in pal["roads"]["colors"].items()}
    levels = [height_c["level_0"], height_c["level_1"], height_c["level_2"], height_c["level_3"],
              height_c["peak"]]
    clear = (0, 0, 0, 0)

    altura = Image.open(REGION_DIR / "altura.png").convert("RGBA")
    agua = Image.open(REGION_DIR / "agua.png").convert("RGBA")
    caminos = Image.open(REGION_DIR / "caminos.png").convert("RGBA")
    w, h = altura.size

    def level_at(x: int, y: int) -> int:
        c = altura.getpixel((x, y))
        return levels.index(c) if c in levels else -1

    # 1) Larr: cumbre de lado a lado; sin agua ni caminos encima.
    cut_water = 0
    for y in range(LARR_ROWS):
        for x in range(w):
            altura.putpixel((x, y), levels[4])
            if agua.getpixel((x, y))[3]:
                agua.putpixel((x, y), clear)
                cut_water += 1
            if caminos.getpixel((x, y))[3]:
                caminos.putpixel((x, y), clear)
    for y in range(LARR_ROWS, LARR_ROWS + FOOT_ROWS):
        for x in range(w):
            if 0 <= level_at(x, y) < 2:
                altura.putpixel((x, y), levels[2])

    # 2) Cordillera occidental: niveles 1-3, sin cumbres.
    lowered = raised = 0
    for y in range(LARR_ROWS, min(STRIP_END, h)):
        for x in range(min(STRIP_W, w)):
            lv = level_at(x, y)
            if lv == 4:
                altura.putpixel((x, y), levels[3])
                lowered += 1
            elif lv == 0:
                altura.putpixel((x, y), levels[1])
                raised += 1

    # 3) Camino de Azhin: se para al tocar la red; puente sobre el agua.
    road: list[tuple[int, int]] = [AZHIN_ROAD[0]]
    for a, b in zip(AZHIN_ROAD, AZHIN_ROAD[1:]):
        road += line4(a, b)
    for x, y in road:
        if level_at(x, y) == 4:
            print(f"El camino de Azhin pisa una cumbre en {(x, y)}: mueve AZHIN_ROAD.", file=sys.stderr)
            return 1
    joined = False
    for x, y in road:
        if caminos.getpixel((x, y))[3] and caminos.getpixel((x, y)) not in (road_c["road"], road_c["bridge"]):
            print(f"Color raro en caminos.png en {(x, y)}.", file=sys.stderr)
            return 1
        caminos.putpixel((x, y), road_c["bridge"] if agua.getpixel((x, y))[3] else road_c["road"])
    last = road[-1]
    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        n = (last[0] + dx, last[1] + dy)
        if 0 <= n[0] < w and 0 <= n[1] < h and n not in road and caminos.getpixel(n)[3]:
            joined = True
    if not joined:
        print(f"El camino de Azhin acaba en {last} sin tocar otro camino: alarga AZHIN_ROAD.", file=sys.stderr)
        return 1

    # 4) Azhin y su tarca en lugares.csv (sustituye sus filas si las había).
    path = REGION_DIR / "lugares.csv"
    out: list[str] = path.read_text(encoding="utf-8").splitlines()
    for pid, cell, template in [("villa_azhin", AZHIN, AZHIN_ROW), ("tarca_azhin", TARCA, TARCA_ROW)]:
        if agua.getpixel(cell)[3] or level_at(*cell) == 4:
            print(f"{pid} cae en el agua o en una cumbre en {cell}.", file=sys.stderr)
            return 1
        if pid == "tarca_azhin" and (level_at(*cell) != 3 or cell[0] > AZHIN[0] - TARCA_MIN_PX
                                     or any(level_at(x, y) > 3 for y in range(cell[1] - 2, cell[1] + 3)
                                            for x in range(max(0, cell[0] - 2), cell[0] + 3))):
            print(f"La tarca de Azhin en {cell} no está en lo alto de una montaña al oeste de Azhin.", file=sys.stderr)
            return 1
        row = template.format(x=cell[0], y=cell[1])
        idx = next((i for i, ln in enumerate(out) if ln.startswith(pid + ",")), -1)
        if idx >= 0:
            out[idx] = row
        else:
            # Detrás de la última villa (y de Azhin), antes de los afluentes.
            idx = max(i for i, ln in enumerate(out) if ln.startswith(("villa", "tarca_azhin")))
            out.insert(idx + 1, row)
    path.write_bytes(("\n".join(out) + "\n").encode("utf-8"))

    altura.save(REGION_DIR / "altura.png")
    agua.save(REGION_DIR / "agua.png")
    caminos.save(REGION_DIR / "caminos.png")
    print(f"Larr: filas 0-{LARR_ROWS - 1} de cumbre ({cut_water} px de agua cortados al pie). "
          f"Cordillera occidental (x < {STRIP_W}, y {LARR_ROWS}-{STRIP_END - 1}): {lowered} cumbres a nivel 3, "
          f"{raised} px de nivel 0 a 1. Azhin en {AZHIN}, su tarca en {TARCA}; camino de {len(road)} px hasta {last}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
