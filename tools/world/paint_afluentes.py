"""Pinta los afluentes del río Sara en la autoría del Valle del Sara (ADR 0014 §4).

Petición del dueño (2026-10-25): 4 afluentes al oeste, que bajan de las Urd Gumnavis, y 3 al este,
que bajan de las Gumnada Gumnavis, siguiendo en lo posible los límites de subregión y las líneas de
río del mapa a mano (docs/design/world/Sur-Lenfi_02.jpg; lectura en docs/design/world/sur-lenfi.md).
Al oeste, los 3 que dibuja el mapa y uno pequeño cerca del sur. "Todos los afluentes son navegables
una vez que salen de la zona montañosa", y se llaman "1ro del Sara", "2do del Sara"... por orden de
confluencia con el Sara de sur a norte, contando las dos orillas.

Modifica las PNG de data/world/regions/valle_del_sara/ (no las regenera desde el generador):
- agua.png: cada afluente es una polilínea de puntos de control (px de la PNG, 1 px = celda gruesa)
  rasterizada con un trazo de 1 px conectado en 4-vecindad, con algún vado. Es río estrecho en la
  zona montañosa y río navegable desde que sale de ella hasta el Sara: es navegable desde el primer
  píxel de nivel 0-1 tras el nacimiento a partir del cual ya no cruza HIGH_RUN px seguidos de nivel
  2 o más (mountain_exit). El
  trazo se para en el primer píxel que era agua del Sara en BASE_REF: el último punto de control puede caer
  dentro o más allá del río, y el afluente queda unido a él por un lado.
- altura.png: en el nacimiento pone una cumbre de 3x3 px (el afluente nace pegado a ella, así que
  el validador lo da por unido: "nacer en una cumbre") rodeada de nivel 3 y nivel 2. Solo sube el
  relieve, nunca lo baja. Excepción: los afluentes con "nacimiento": "borde" (los tres de la
  cordillera occidental, que es transitable; dueño, 2026-10-26) nacen en el borde oeste del mapa
  (vienen del lado de Dorias, y el validador los da por unidos por tocar el borde) y en el
  nacimiento solo tienen colinas de nivel 3 y 2, sin cumbre.
- caminos.png: donde un camino pintado cruza un afluente, ese píxel pasa a puente.
- lugares.csv: una fila de tipo lugar por afluente (id afluente_<n>, nombre "<n> del Sara"), junto
  a su tramo medio, para que la vista previa lo rotule. Sustituye las filas afluente_* que hubiera y
  deja el resto igual.

Es idempotente: volver a ejecutarlo sobre su propia salida no cambia nada. Para ajustar un afluente,
cambia sus puntos y ejecuta con --from-ref <commit> (por defecto la base anterior a los afluentes):
parte de las PNG de ese commit y vuelve a pintar todo, así no quedan restos del trazo viejo. Ojo:
--from-ref descarta también lo que se haya retocado a mano en esas tres PNG después de ese commit.

Uso (desde la raíz del repo; necesita Pillow):
    python tools/world/paint_afluentes.py                    # pinta sobre las PNG actuales
    python tools/world/paint_afluentes.py --from-ref e15e3e1  # rehace desde la base
Después: python tools/world/paint_relieve_autor.py (Larr, cordillera occidental y Azhin; orden en
docs/design/world/autoria.md §1) y bash tools/world/preview_region.sh valle_del_sara 7
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
# va un vado (#a0d8ff). navegable_min (opcional): px finales que son navegables aunque el afluente
# no salga de la montaña (dueño, 2026-10-26: "dales un tramo navegable al 6to y al 7mo antes de
# unirse al Sara").
AFLUENTES: list[dict] = [
    {
        "id": "oeste_1", "lado": "O",
        "sigue": "límite Lean–Tossie (borde norte de Tossie)",
        "nacimiento": "borde",
        "puntos": [(0, 30), (20, 29), (40, 33), (60, 40), (80, 50), (100, 56), (125, 58)],
        "vados": [0.02, 0.35, 0.75],
        "navegable_min": 30,
    },
    {
        "id": "oeste_2", "lado": "O",
        "sigue": "límite Tossie–Ostie (borde sur de Tossie)",
        "nacimiento": "borde",
        "puntos": [(0, 62), (25, 66), (32, 69), (42, 71), (46, 82), (60, 92), (80, 98), (105, 102)],
        "vados": [0.02, 0.3, 0.7],
    },
    {
        "id": "oeste_3", "lado": "O",
        "sigue": "límite Ostie–Cassie (franja occidental de Cassie)",
        "nacimiento": "borde",
        "puntos": [(0, 128), (16, 132), (28, 150), (50, 160), (70, 165), (85, 169), (100, 170)],
        "vados": [0.02, 0.3, 0.7],
    },
    {
        "id": "oeste_4", "lado": "O",
        "sigue": "ninguno: pequeño afluente del sur de Cassie (el mapa no lo dibuja; el dueño lo pidió cerca del sur)",
        "puntos": [(84, 303), (92, 302), (100, 300), (110, 299)],
        "vados": [0.6],
    },
    {
        "id": "este_1", "lado": "E",
        "sigue": "límite Causie–Alss",
        "puntos": [(235, 36), (222, 43), (205, 45), (175, 40), (160, 48), (145, 62), (135, 75), (128, 85), (110, 90)],
        "vados": [0.3, 0.7],
        "navegable_min": 30,
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
HIGH_RUN = 8       # px seguidos de nivel 2 o más que cuentan como zona montañosa
ORDINALES = ["1ro", "2do", "3ro", "4to", "5to", "6to", "7mo", "8vo", "9no", "10mo"]
NOMBRE = "{} del Sara"


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


def mountain_exit(levels_along: list[int]) -> int:
    """Índice del primer píxel navegable: el afluente ya salió de la montaña (dejó la altura de
    nivel 2 o más del nacimiento) y no vuelve a cruzar HIGH_RUN px seguidos de nivel 2 o más."""
    n = len(levels_along)
    high = [lv >= 2 for lv in levels_along]
    exit_at = next((i for i in range(n) if not high[i]), n)
    run = 0
    for i in range(n):
        run = run + 1 if high[i] else 0
        if run >= HIGH_RUN:
            exit_at = max(exit_at, i + 1)
    # Un tramo navegable de menos de HIGH_RUN px al final no se nota: se queda estrecho.
    return n if n - exit_at < HIGH_RUN else exit_at


def label_cell(at: tuple[int, int], agua: Image.Image, altura: Image.Image, caminos: Image.Image,
               levels: list) -> tuple[int, int]:
    """Celda de tierra junto al río para el rótulo: ni agua, ni cumbre, ni camino."""
    w, h = agua.size
    for r in range(2, 8):
        for dx, dy in [(0, -r), (0, r), (-r, 0), (r, 0), (-r, -r), (r, -r), (-r, r), (r, r)]:
            x, y = at[0] + dx, at[1] + dy
            if 0 <= x < w and 0 <= y < h and agua.getpixel((x, y))[3] == 0 \
                    and caminos.getpixel((x, y))[3] == 0 and altura.getpixel((x, y)) != levels[4]:
                return (x, y)
    raise SystemExit(f"No hay sitio para el rótulo junto a {at}")


def write_places(rows: list[str]) -> None:
    path = REGION_DIR / "lugares.csv"
    lines = path.read_text(encoding="utf-8").splitlines()
    kept = [ln for ln in lines if not ln.startswith("afluente_")]
    while kept and kept[-1].strip() == "":
        kept.pop()
    path.write_bytes(("\n".join(kept + rows) + "\n").encode("utf-8"))


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

    # Trazos: cada afluente se para en el primer píxel del Sara.
    rivers: dict[str, list[tuple[int, int]]] = {}
    for af in AFLUENTES:
        river: list[tuple[int, int]] = []
        for p in trace(af["puntos"]):
            if p in base_water:
                break
            river.append(p)
        else:
            print(f"{af['id']}: no llega al Sara; alarga sus puntos.", file=sys.stderr)
            return 1
        rivers[af["id"]] = river
    traced = {p for r in rivers.values() for p in r}

    # 1) Colinas y cumbre de nacimiento (antes del agua: la navegabilidad lee la altura final).
    for af in AFLUENTES:
        sx, sy = rivers[af["id"]][0]
        borde = af.get("nacimiento", "cumbre") == "borde"
        if borde:
            # Nace en el borde del mapa (viene del otro lado de la cordillera): colina de nivel 3
            # centrada en el nacimiento, sin cumbre, para que la cordillera se cruce a pie.
            cx = sx
        else:
            cx = sx - (PEAK_HALF + 1) if af["lado"] == "O" else sx + (PEAK_HALF + 1)
        for y in range(sy - PEAK_HALF - RING_LEVEL_2, sy + PEAK_HALF + RING_LEVEL_2 + 1):
            for x in range(cx - PEAK_HALF - RING_LEVEL_2, cx + PEAK_HALF + RING_LEVEL_2 + 1):
                d = math.hypot(max(0, abs(x - cx) - PEAK_HALF), max(0, abs(y - sy) - PEAK_HALF))
                if d > RING_LEVEL_2 + 0.5:
                    continue
                level = 4 if d == 0 else (3 if d <= RING_LEVEL_3 + 0.5 else 2)
                if borde:
                    level = min(level, 3)
                if (x, y) in base_water or (x, y) in traced:
                    level = min(level, 3)  # nunca una cumbre bajo el agua
                if level == 4 and 0 <= x < w and 0 <= y < h and caminos.getpixel((x, y))[3]:
                    print(f"{af['id']}: la cumbre de nacimiento pisa un camino en {(x, y)}.", file=sys.stderr)
                    return 1
                raise_to(x, y, level)

    def level_at(p: tuple[int, int]) -> int:
        c = altura.getpixel(p)
        return levels.index(c) if c in levels else 0

    # El meandro de RegionPlan mueve el agua ±1 celda y no pinta sobre cumbres: un afluente pegado
    # a una cumbre (salvo la de su nacimiento) se cortaría en la partida. Hay que apartarlo.
    blocked = False
    for af in AFLUENTES:
        river = rivers[af["id"]]
        for p in river[RING_LEVEL_3 + 1:]:
            near = [(p[0] + dx, p[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
            if any(0 <= x < w and 0 <= y < h and level_at((x, y)) == 4 for x, y in near):
                print(f"{af['id']}: pasa junto a una cumbre en {p}; el meandro lo cortaría. Aparta sus puntos.",
                      file=sys.stderr)
                blocked = True
    if blocked:
        return 1

    # 2) Agua: estrecho en la montaña, navegable desde el primer tramo bajo; vados y puentes.
    info: list[dict] = []
    for af in AFLUENTES:
        river = rivers[af["id"]]
        exit_at = mountain_exit([level_at(p) for p in river])
        exit_at = min(exit_at, max(0, len(river) - af.get("navegable_min", 0)))
        fords = {river[min(len(river) - 1, round(f * (len(river) - 1)))] for f in af["vados"]}
        for i, p in enumerate(river):
            if p in fords:
                kind = "ford"
            else:
                kind = "river_narrow" if i < exit_at else "river_navigable"
            agua.putpixel(p, water_c[kind])
            if caminos.getpixel(p)[3] != 0:
                caminos.putpixel(p, road_c["bridge"])
        info.append({"af": af, "river": river, "exit_at": exit_at})

    # 3) Nombres por orden de confluencia de sur a norte (las dos orillas juntas).
    info.sort(key=lambda d: (-d["river"][-1][1], d["river"][-1][0]))
    rows: list[str] = []
    for n, d in enumerate(info):
        af, river = d["af"], d["river"]
        d["nombre"] = NOMBRE.format(ORDINALES[n])
        mid = (d["exit_at"] + len(river)) // 2 if d["exit_at"] < len(river) else len(river) // 2
        lx, ly = label_cell(river[mid], agua, altura, caminos, levels)
        orilla = "oeste, de las Urd Gumnavis" if af["lado"] == "O" else "este, de las Gumnada Gumnavis"
        notas = f"Afluente del Sara (orilla {orilla}). Sigue: {af['sigue']}. Fila escrita por tools/world/paint_afluentes.py."
        rows.append(f"afluente_{n + 1},{d['nombre']},lugar,{lx},{ly},,,\"{notas}\"")
        nav = len(river) - d["exit_at"]
        print(f"{d['nombre']} ({af['id']}, {af['lado']}): {len(river)} px ({len(river) - nav} estrecho, {nav} navegable),"
              f" nace en {river[0]}, llega al Sara junto a {river[-1]}, rótulo en {(lx, ly)} — {af['sigue']}")
    write_places(rows)

    agua.save(REGION_DIR / "agua.png")
    altura.save(REGION_DIR / "altura.png")
    caminos.save(REGION_DIR / "caminos.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
