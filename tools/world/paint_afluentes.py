"""Pinta los afluentes del río Sara en la autoría del Valle del Sara (ADR 0014 §4).

Petición del dueño (2026-10-25): 4 afluentes al oeste, que bajan de las Urd Gumnavis, y 3 al este,
que bajan de las Gumnada Gumnavis, siguiendo en lo posible los límites de subregión y las líneas de
río del mapa a mano (docs/design/world/Sur-Lenfi_02.jpg; lectura en docs/design/world/sur-lenfi.md).

Modifica las PNG de data/world/regions/valle_del_sara/ (no las regenera desde el generador):
- agua.png: cada afluente es una polilínea de puntos de control (px de la PNG, 1 px = celda gruesa)
  rasterizada con un trazo de 1 px conectado en 4-vecindad, en río estrecho, con algún vado. El
  trazo se para en el primer píxel que era agua del Sara en BASE_REF: el último punto de control puede caer
  dentro o más allá del río, y el afluente queda unido a él por un lado.
- altura.png: en el nacimiento pone una cumbre de 3x3 px (el afluente nace pegado a ella, así que
  el validador lo da por unido: "nacer en una cumbre") rodeada de nivel 3 y nivel 2. Solo sube el
  relieve, nunca lo baja.
- caminos.png: donde un camino pintado cruza un afluente, ese píxel pasa a puente.

Es idempotente: volver a ejecutarlo sobre su propia salida no cambia nada. Para ajustar un afluente,
cambia sus puntos y ejecuta con --from-ref <commit> (por defecto la base anterior a los afluentes):
parte de las PNG de ese commit y vuelve a pintar todo, así no quedan restos del trazo viejo. Ojo:
--from-ref descarta también lo que se haya retocado a mano en esas tres PNG después de ese commit.

Uso (desde la raíz del repo; necesita Pillow):
    python tools/world/paint_afluentes.py                    # pinta sobre las PNG actuales
    python tools/world/paint_afluentes.py --from-ref e15e3e1  # rehace desde la base
Después: bash tools/world/preview_region.sh valle_del_sara 7
"""
from __future__ import annotations

import argparse
import io
import json
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REGION_DIR = ROOT / "data" / "world" / "regions" / "valle_del_sara"
PALETTE = ROOT / "data" / "world" / "authoring_palette.json"
# Commit de main anterior a los afluentes (agua.png solo con el Sara).
BASE_REF = "e15e3e1"

# Cada afluente: id, lado, límite de subregión que sigue (mapa a mano) y puntos de control (x, y)
# en px de la PNG, del nacimiento a la desembocadura. vados: fracciones del recorrido (0..1) donde
# va un vado (#a0d8ff).
AFLUENTES: list[dict] = [
    {
        "id": "oeste_1", "lado": "O",
        "sigue": "límite Lean–Tossie (borde norte de Tossie)",
        "puntos": [(4, 30), (20, 29), (40, 33), (60, 40), (80, 50), (100, 56), (125, 58)],
        "vados": [0.35, 0.75],
    },
    {
        "id": "oeste_2", "lado": "O",
        "sigue": "límite Tossie–Ostie (borde sur de Tossie)",
        "puntos": [(4, 62), (25, 64), (42, 70), (46, 82), (60, 92), (80, 98), (105, 102)],
        "vados": [0.3, 0.7],
    },
    {
        "id": "oeste_3", "lado": "O",
        "sigue": "límite Ostie–Cassie (franja occidental de Cassie)",
        "puntos": [(4, 128), (16, 132), (28, 150), (50, 160), (70, 165), (85, 169), (100, 170)],
        "vados": [0.3, 0.7],
    },
    {
        "id": "oeste_4", "lado": "O",
        "sigue": "sin línea en el mapa: cruza el sur de Cassie (añadido para llegar a 4)",
        "puntos": [(4, 232), (25, 236), (45, 242), (65, 246), (90, 250)],
        "vados": [0.5],
    },
    {
        "id": "este_1", "lado": "E",
        "sigue": "límite Causie–Alss",
        "puntos": [(235, 36), (205, 42), (175, 40), (160, 48), (145, 62), (135, 75), (128, 85), (110, 90)],
        "vados": [0.3, 0.7],
    },
    {
        "id": "este_2", "lado": "E",
        "sigue": "límite Alss–Vastie",
        "puntos": [(235, 104), (215, 106), (195, 111), (170, 110), (150, 105), (141, 110), (136, 118), (124, 124), (110, 128)],
        "vados": [0.3, 0.7],
    },
    {
        "id": "este_3", "lado": "E",
        "sigue": "límite Vastie–Cassie",
        "puntos": [(235, 160), (212, 163), (190, 165), (175, 166), (172, 176), (150, 178), (130, 184), (114, 190), (85, 196)],
        "vados": [0.3, 0.7],
    },
]

WIGGLE_STEP = 6   # px entre ondulaciones
WIGGLE_AMP = 2.0  # px de desplazamiento máximo
PEAK_HALF = 1      # cumbre de 3x3 px
RING_LEVEL_3 = 2   # px alrededor de la cumbre con nivel 3 como mínimo
RING_LEVEL_2 = 6   # px con nivel 2 como mínimo (corona redondeada: distancia euclídea)


def hex_rgba(h: str) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def load_png(name: str, ref: str | None) -> Image.Image:
    if ref is None:
        return Image.open(REGION_DIR / name).convert("RGBA")
    rel = (REGION_DIR / name).relative_to(ROOT).as_posix()
    blob = subprocess.run(["git", "-C", str(ROOT), "show", f"{ref}:{rel}"], check=True,
                          capture_output=True).stdout
    if blob.startswith(b"version https://git-lfs"):
        blob = subprocess.run(["git", "-C", str(ROOT), "lfs", "smudge"], input=blob, check=True,
                              capture_output=True).stdout
    return Image.open(io.BytesIO(blob)).convert("RGBA")


def line4(a: tuple[int, int], b: tuple[int, int]) -> list[tuple[int, int]]:
    """Bresenham de a a b (sin a) con un píxel extra en cada paso diagonal: 4-conectado."""
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
            # Diagonal: primero en x, luego en y.
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


def wiggle(puntos: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """Ondula cada tramo: un punto cada WIGGLE_STEP px, desplazado en perpendicular por un seno de
    amplitud WIGGLE_AMP (determinista, sin azar). Los puntos de control no se mueven."""
    out = [puntos[0]]
    phase = 0.0
    for (x0, y0), (x1, y1) in zip(puntos, puntos[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        n = int(length // WIGGLE_STEP)
        if n >= 2:
            px, py = -(y1 - y0) / length, (x1 - x0) / length
            for i in range(1, n):
                t = i / n
                off = WIGGLE_AMP * math.sin(phase + math.pi * i * 2 / 3) * math.sin(math.pi * t)
                out.append((round(x0 + (x1 - x0) * t + px * off), round(y0 + (y1 - y0) * t + py * off)))
        phase += 1.0
        out.append((x1, y1))
    return out


def trace(puntos: list[tuple[int, int]]) -> list[tuple[int, int]]:
    puntos = wiggle(puntos)
    path = [puntos[0]]
    for a, b in zip(puntos, puntos[1:]):
        path += line4(a, b)
    return path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--from-ref", nargs="?", const=BASE_REF, default=None,
                    help=f"parte de las PNG de este commit (sin valor: {BASE_REF})")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

    pal = json.loads(PALETTE.read_text(encoding="utf-8"))["layers"]
    water_c = {k: hex_rgba(v) for k, v in pal["water"]["colors"].items()}
    height_c = {k: hex_rgba(v) for k, v in pal["height"]["colors"].items()}
    road_c = {k: hex_rgba(v) for k, v in pal["roads"]["colors"].items()}
    levels = [height_c["level_0"], height_c["level_1"], height_c["level_2"], height_c["level_3"],
              height_c["peak"]]

    agua = load_png("agua.png", args.from_ref)
    altura = load_png("altura.png", args.from_ref)
    caminos = load_png("caminos.png", args.from_ref)
    w, h = agua.size
    # El agua de la base (el Sara): ahí se para cada trazo. Se lee siempre de BASE_REF para que
    # volver a ejecutar sobre la salida (que ya tiene los afluentes) dé lo mismo.
    sara = load_png("agua.png", BASE_REF)
    base_water = {(x, y) for y in range(h) for x in range(w) if sara.getpixel((x, y))[3] != 0}

    def raise_to(x: int, y: int, level: int) -> None:
        if 0 <= x < w and 0 <= y < h:
            cur = levels.index(altura.getpixel((x, y))) if altura.getpixel((x, y)) in levels else 0
            if level > cur:
                altura.putpixel((x, y), levels[level])

    for af in AFLUENTES:
        path = trace(af["puntos"])
        river: list[tuple[int, int]] = []
        for p in path:
            if p in base_water:
                break
            river.append(p)
        else:
            print(f"{af['id']}: no llega al Sara; alarga sus puntos.", file=sys.stderr)
            return 1
        fords = {river[min(len(river) - 1, round(f * (len(river) - 1)))] for f in af["vados"]}
        for p in river:
            agua.putpixel(p, water_c["ford"] if p in fords else water_c["river_narrow"])
            if caminos.getpixel(p)[3] != 0:
                caminos.putpixel(p, road_c["bridge"])
        # Cumbre de nacimiento, hacia fuera del mapa: el primer píxel del trazo la toca por un lado.
        sx, sy = river[0]
        cx = sx - (PEAK_HALF + 1) if af["lado"] == "O" else sx + (PEAK_HALF + 1)
        for y in range(sy - PEAK_HALF - RING_LEVEL_2, sy + PEAK_HALF + RING_LEVEL_2 + 1):
            for x in range(cx - PEAK_HALF - RING_LEVEL_2, cx + PEAK_HALF + RING_LEVEL_2 + 1):
                dx = max(0, abs(x - cx) - PEAK_HALF)
                dy = max(0, abs(y - sy) - PEAK_HALF)
                d = math.hypot(dx, dy)
                if d > RING_LEVEL_2 + 0.5:
                    continue
                if d == 0:
                    level = 4
                elif d <= RING_LEVEL_3 + 0.5:
                    level = 3
                else:
                    level = 2
                if (x, y) in base_water or (0 <= x < w and 0 <= y < h and agua.getpixel((x, y))[3]):
                    level = min(level, 3)  # nunca una cumbre bajo el agua
                if level == 4 and 0 <= x < w and 0 <= y < h and caminos.getpixel((x, y))[3]:
                    print(f"{af['id']}: la cumbre de nacimiento pisa un camino en {(x, y)}.", file=sys.stderr)
                    return 1
                raise_to(x, y, level)
        print(f"{af['id']} ({af['lado']}): {len(river)} px, nace en {river[0]}, llega al Sara junto a {river[-1]}"
              f" — {af['sigue']}")

    agua.save(REGION_DIR / "agua.png")
    altura.save(REGION_DIR / "altura.png")
    caminos.save(REGION_DIR / "caminos.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
