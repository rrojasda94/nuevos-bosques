"""Genera el tileset de terreno (docs/art/specs/tileset-terreno.md).

Escribe assets/tilesets/tileset_<grupo>.png, todos de casillas de 16x16 y solo con colores de
assets/palettes/palette_nuevos_bosques.gpl. Los dibujos fijos (árboles, letrero, cueva, casas) son
matrices de caracteres, como en make_sprites.py; las texturas que se repiten (hierba, sendero, agua,
risco) se componen con reglas deterministas: mismas entradas, mismos píxeles.

Uso (desde la raíz del repo):
    python tools/art/make_tiles.py              # escribe assets/tilesets/*.png
    python tools/art/make_tiles.py --preview D  # además, vistas x6 en la carpeta D

Colores clave: el juego (TerrainTileset) cambia por los del Bosque los colores clave de cada grupo
(tabla GROUP_KEYS de la spec). No cambies una clave sin cambiar TerrainTileset a la vez.
"""
import argparse
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import check_palette, load_palette  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "tilesets")
T = 16

# --- Colores -------------------------------------------------------------------------------
OUTLINE = "181425"
# Claves de suelo (se cambian por PlaceholderTileset.GROUNDS del Bosque).
K_GRASS = "3e8948"         # hierba            -> ground[0]
K_GRASS_SPECK = "63c74d"   # brizna clara      -> ground[1]
K_GRASS_SHADOW = "265c42"  # sombra de hierba  -> ground[4]
K_CLEAR = "ead4aa"         # claro             -> ground[2]
K_CLEAR_SPECK = "e4a672"   # mota del claro    -> ground[3]
# Claves de árbol (las mismas que los monstruos, UnicoArt.KEY_*).
K_LEAF_LIGHT = "c0cbdc"    # hoja clara  -> LEAVES[leaf][1]
K_LEAF_DARK = "8b9bb4"     # hoja oscura -> LEAVES[leaf][0]
K_TRUNK = "5a6988"         # tronco      -> TRUNKS[trunk]
K_FRUIT = "e43b44"         # fruto       -> fruit_color()[0]
K_FRUIT_SHADOW = "a22633"  # sombra fruto-> fruit_color()[1]

# Colores fijos.
WHITE = "ffffff"
YELLOW = "fee761"
STONE_L = "c0cbdc"
STONE = "8b9bb4"
STONE_D = "5a6988"
STONE_DD = "3a4466"
NIGHT = "262b44"
DIRT_L = "e4a672"
DIRT = "b86f50"
DIRT_D = "733e39"
DIRT_DD = "3e2731"
EARTH = "c28569"
SAND = "ead4aa"
SKIN_L = "e8b796"
CLAY = "d77643"
CLAY_D = "be4a2f"
WATER_DD = "124e89"
WATER_D = "0099db"
WATER_L = "2ce8f5"

# Mapa de caracteres para las matrices dibujadas a mano.
CHARS = {
    "K": OUTLINE,
    "A": K_LEAF_LIGHT, "B": K_LEAF_DARK, "C": K_TRUNK,
    "F": K_FRUIT, "f": K_FRUIT_SHADOW, "s": DIRT_D,      # fruto y rabillo
    "H": DIRT_DD,                                        # boca del hueco
    "1": STONE_L, "2": STONE, "3": STONE_D, "4": STONE_DD, "5": NIGHT,
    "W": WHITE, "Y": YELLOW,
}


def h(*vals):
    """Hash entero determinista (FNV-1a de 32 bits)."""
    x = 2166136261
    for v in vals:
        for b in int(v).to_bytes(8, "little", signed=True):
            x = ((x ^ b) * 16777619) & 0xFFFFFFFF
    # Mezcla final (murmur3) para que x e y de las motas no salgan en diagonal.
    x ^= x >> 16
    x = (x * 0x85EBCA6B) & 0xFFFFFFFF
    x ^= x >> 13
    x = (x * 0xC2B2AE35) & 0xFFFFFFFF
    x ^= x >> 16
    return x


def blank(color=None):
    return [[color] * T for _ in range(T)]


def copy(g):
    return [row[:] for row in g]


def from_rows(rows):
    if len(rows) != T or any(len(r) != T for r in rows):
        raise ValueError("matriz que no es de 16x16: %r" % rows)
    return [[None if ch == "." else CHARS[ch] for ch in r] for r in rows]


def mirror(g):
    return [row[::-1] for row in g]


def rot90(g):
    """Gira 90 grados en sentido horario (los giros de 90 sí están permitidos)."""
    n = len(g)
    return [[g[n - 1 - x][y] for x in range(n)] for y in range(n)]


def over(dst, src):
    out = copy(dst)
    for y in range(T):
        for x in range(T):
            if src[y][x] is not None:
                out[y][x] = src[y][x]
    return out


def outline(g, color=OUTLINE):
    """Contorno de 1 px alrededor de lo pintado (4 vecinos), dentro de la casilla."""
    out = copy(g)
    for y in range(T):
        for x in range(T):
            if g[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < T and 0 <= yy < T and g[yy][xx] is not None:
                    out[y][x] = color
                    break
    return out


def profile(seed, lo=1, hi=3, end=1):
    """Profundidad de un borde a lo largo de sus 16 píxeles: paseo aleatorio en [lo, hi] que vale
    `end` en los extremos, para que dos casillas vecinas con el mismo borde casen."""
    vals = [end]
    for i in range(1, T):
        r = h(seed, i) % 4
        v = vals[-1] + (1 if r == 0 else -1 if r == 1 else 0)
        vals.append(max(lo, min(hi, v)))
    vals[-1] = end
    vals[-2] = max(lo, min(hi, (vals[-3] + end) // 2 if len(vals) > 2 else end))
    vals[1] = max(lo, min(hi, (vals[2] + end + 1) // 2))
    return vals


# Bits de máscara de borde: lado cuyo vecino es "de fuera" (hierba, tierra...).
N, E, S, W = 1, 2, 4, 8


def fringe_cells(mask, seed, lo=1, hi=3, end=1):
    """Píxeles de la franja de borde y el más interior de cada columna/fila (para el labio)."""
    cells = {}
    if mask & N:
        p = profile(seed * 7 + 1, lo, hi, end)
        for x in range(T):
            for y in range(p[x]):
                cells[(x, y)] = "lip" if y == p[x] - 1 else "in"
    if mask & S:
        p = profile(seed * 7 + 2, lo, hi, end)
        for x in range(T):
            for y in range(T - p[x], T):
                cells.setdefault((x, y), "lip" if y == T - p[x] else "in")
    if mask & W:
        p = profile(seed * 7 + 3, lo, hi, end)
        for y in range(T):
            for x in range(p[y]):
                cells.setdefault((x, y), "lip" if x == p[y] - 1 else "in")
    if mask & E:
        p = profile(seed * 7 + 4, lo, hi, end)
        for y in range(T):
            for x in range(T - p[y], T):
                cells.setdefault((x, y), "lip" if x == T - p[y] else "in")
    return cells


def specks(g, color, count, seed, avoid=None):
    for i in range(count):
        v = h(seed, i)
        x, y = v % T, (v >> 8) % T
        if avoid is None or g[y][x] not in avoid:
            g[y][x] = color


# --- Suelo ---------------------------------------------------------------------------------
def grass(variant):
    """Hierba: base, matas en V con sombra al pie y, en la variante 3, dos florecillas."""
    g = blank(K_GRASS)
    for i in range(4 + variant % 2):
        v = h(11, variant, i)
        x, y = v % T, (v >> 8) % T
        for dx, dy, c in ((0, 0, K_GRASS_SPECK), (2, 0, K_GRASS_SPECK), (1, 1, K_GRASS_SPECK), (1, 2, K_GRASS_SHADOW)):
            g[(y + dy) % T][(x + dx) % T] = c
    specks(g, K_GRASS_SHADOW, 3, 12 + variant)
    specks(g, K_GRASS_SPECK, 3, 13 + variant)
    if variant == 3:
        for i in range(2):
            v = h(14, i)
            x, y = 2 + v % 12, 2 + (v >> 8) % 12
            g[y][x] = YELLOW if i == 0 else WHITE
            g[y + 1][x] = K_GRASS_SHADOW
    return g


def clearing(mask, variant):
    """Claro: tierra clara con motas y, si toca hierba, una franja irregular de hierba."""
    g = blank(K_CLEAR)
    specks(g, K_CLEAR_SPECK, 6, 21 + variant)
    for i in range(2):
        v = h(22, variant, i)
        x, y = v % 15, (v >> 8) % 15
        g[y][x] = K_CLEAR_SPECK
        g[y][x + 1] = K_CLEAR_SPECK
    if variant == 1:
        specks(g, YELLOW, 2, 23)
    for (x, y), kind in fringe_cells(mask, 31 + variant).items():
        g[y][x] = K_GRASS_SPECK if kind == "lip" else K_GRASS
    return g


def rocky(variant):
    """Pedregal: hierba con dos o tres piedras con luz arriba a la izquierda y sombra al pie."""
    g = grass(variant % 3)
    stones = [((2, 3), 4, 3), ((9, 9), 5, 3), ((10, 2), 3, 2), ((3, 11), 3, 2)]
    for k, ((x0, y0), w, hgt) in enumerate(stones):
        if k >= 3 or (k != variant % 3 and h(41, variant, k) % 3 != 0):
            continue
        x0 = (x0 + variant * 3) % 11
        y0 = (y0 + variant * 2) % 12
        for y in range(hgt):
            for x in range(w):
                corner = (x in (0, w - 1)) and (y in (0, hgt - 1)) and w > 3
                if corner and y == 0:
                    continue
                c = STONE
                if y == 0 or (x == 0 and y < hgt - 1):
                    c = STONE_L
                if y == hgt - 1 or x == w - 1:
                    c = STONE_D
                g[y0 + y][x0 + x] = c
        for x in range(w):
            if y0 + hgt < T:
                g[y0 + hgt][x0 + x] = K_GRASS_SHADOW
    specks(g, STONE, 2, 42 + variant, avoid={STONE_L, STONE_D})
    return g


# --- Sendero y camino ----------------------------------------------------------------------
def path(mask, variant):
    """Sendero de tierra marrón. Donde toca hierba, la hierba lo invade un poco y deja sombra."""
    g = blank(DIRT)
    specks(g, DIRT_L, 6, 51 + variant)
    specks(g, DIRT_D, 4, 52 + variant)
    specks(g, EARTH, 5, 53 + variant)
    cells = fringe_cells(mask, 61 + variant)
    for (x, y), kind in cells.items():
        g[y][x] = K_GRASS_SPECK if kind == "lip" else K_GRASS
    # Sombra de la hierba sobre la tierra, al sur del borde norte y al este del oeste.
    for (x, y), kind in cells.items():
        if kind != "lip":
            continue
        for dx, dy in ((0, 1), (1, 0)):
            p = (x + dx, y + dy)
            if p[0] < T and p[1] < T and p not in cells and h(62, x, y) % 3:
                g[p[1]][p[0]] = DIRT_D
    return g


def road(mask, variant):
    """Camino principal: tierra apisonada clara con rodadas y un bordillo de piedras sueltas."""
    g = blank(SAND)
    specks(g, DIRT_L, 9, 71 + variant)
    specks(g, EARTH, 3, 72 + variant)
    specks(g, STONE, 2, 73 + variant)
    vertical = bool(mask & (E | W)) and not mask & (N | S)
    horizontal = bool(mask & (N | S)) and not mask & (E | W)
    ruts = []
    if vertical:
        ruts = [11] if mask & W and not mask & E else [4] if mask & E and not mask & W else [4, 11]
    if horizontal:
        ruts = [11] if mask & N and not mask & S else [4] if mask & S and not mask & N else [4, 11]
    for r in ruts:
        for i in range(T):
            x, y = (r, i) if vertical else (i, r)
            g[y][x] = DIRT_L
            if (i + variant * 3) % 6 == 0:
                g[y][x] = EARTH
    cells = fringe_cells(mask, 81 + variant)
    for (x, y), kind in cells.items():
        g[y][x] = K_GRASS_SPECK if kind == "lip" else K_GRASS
    # Bordillo: piedrecitas justo dentro del borde, cada pocos píxeles.
    for (x, y), kind in cells.items():
        if kind != "lip" or h(82, variant, x, y) % 3 == 0:
            continue
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            p = (x + dx, y + dy)
            if 0 <= p[0] < T and 0 <= p[1] < T and p not in cells:
                g[p[1]][p[0]] = STONE_L if dy < 0 or dx < 0 else STONE
                break
    return g


# --- Agua ----------------------------------------------------------------------------------
WATER_KINDS = {
    # base, cresta, brillo
    "narrow": (WATER_D, WATER_L, WHITE),
    "navigable": (WATER_DD, WATER_D, WATER_L),
    "ford": (WATER_D, WATER_L, WHITE),
}
# Crestas de ola: (x, y, largo). Se desplazan 2 px en el fotograma 1. Posiciones módulo 16: las
# casillas de agua casan entre sí.
WAVES = [(1, 2, 3), (9, 4, 4), (4, 8, 3), (12, 10, 3), (7, 13, 4)]
FORD_STONES = [(1, 5, 4), (6, 7, 4), (11, 5, 4), (3, 11, 3), (10, 11, 3)]


def water(kind, mask, frame):
    base, crest, shine = WATER_KINDS[kind]
    g = blank(base)
    for i, (x, y, n) in enumerate(WAVES):
        sx = (x + frame * 2) % T
        sy = (y + (frame if i % 2 else 0)) % T
        for k in range(n):
            g[sy][(sx + k) % T] = crest
        if i % 2 == frame:
            g[sy][(sx + n // 2) % T] = shine
    if kind == "ford":
        for i, (x, y, w) in enumerate(FORD_STONES):
            for k in range(w):
                g[y][x + k] = STONE_L if k < w - 1 else STONE
                g[y + 1][x + k] = STONE_D
            g[y][x - 1 if x > 0 else x] = WHITE if (i + frame) % 2 else crest
            g[y + 1][min(T - 1, x + w)] = WHITE if (i + frame + 1) % 2 else crest
    # Orillas: tierra húmeda con la línea del agua oscura y espuma intermitente.
    cells = fringe_cells(mask, 91 + {"narrow": 0, "navigable": 1, "ford": 2}[kind], 1, 3, 2)
    for (x, y), c in cells.items():
        g[y][x] = DIRT_D if c == "lip" else (EARTH if h(92, x, y) % 5 else DIRT_L)
    for (x, y), c in cells.items():
        if c != "lip":
            continue
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            p = (x + dx, y + dy)
            if 0 <= p[0] < T and 0 <= p[1] < T and p not in cells and (h(93, x, y) + frame) % 3 == 0:
                g[p[1]][p[0]] = shine if kind == "navigable" else WHITE
    return g


def bridge(orient, variant):
    """Puente de tablones sobre agua en sombra. orient 0: el paso va norte-sur (tablones
    horizontales); 1: este-oeste (el dibujo girado)."""
    rows = [
        "5K21212121212K5.",
        "5K33333333333K5.",
        "5K12121121212K5.",
        "5K33333333333K5.",
        "5K21212121221K5.",
        "5K33333333333K5.",
        "5K12112121212K5.",
        "5K33333333333K5.",
        "5K21212121212K5.",
        "5K33333333333K5.",
        "5K12121212112K5.",
        "5K33333333333K5.",
        "5K21221212121K5.",
        "5K33333333333K5.",
        "5K12121212121K5.",
        "5K33333333333K5.",
    ]
    # Tablones: 1/2 = madera clara/media, 3 = junta; K = pretil; 5 = agua en sombra.
    wood = {"1": DIRT_L, "2": DIRT, "3": DIRT_D, "K": DIRT_DD, "5": WATER_DD, ".": WATER_DD}
    g = [[wood[ch] for ch in r] for r in rows]
    # Postes del pretil cada 8 px (más oscuros) y reflejos del agua.
    for y in range(variant * 4, T, 8):
        g[y][1] = OUTLINE
        g[y][13] = OUTLINE
    for y in (3 + variant, 11 - variant):
        g[y][0] = WATER_D
        g[y][15] = WATER_D
    g[7][14] = WATER_D
    if orient == 1:
        g = rot90(g)
    return g


# --- Risco ---------------------------------------------------------------------------------
# Superficie de la roca (vista desde arriba): bloques fracturados (celdas de Voronoi en mosaico)
# con luz arriba a la izquierda de cada bloque y grieta oscura abajo a la derecha.
ROCK_CENTERS = [
    [(4, 4), (12, 3), (8, 11), (1, 12)],
    [(6, 2), (14, 8), (3, 9), (10, 14)],
]


def rock_top(variant):
    centers = ROCK_CENTERS[variant]

    def cell(x, y):
        best, best_d = 0, 1 << 30
        for i, (cx, cy) in enumerate(centers):
            dx = min(abs(x - cx), T - abs(x - cx))
            dy = min(abs(y - cy), T - abs(y - cy))
            d = dx * dx + dy * dy * 2
            if d < best_d:
                best, best_d = i, d
        return best

    ids = [[cell(x, y) for x in range(T)] for y in range(T)]
    g = blank(STONE)
    for y in range(T):
        for x in range(T):
            me = ids[y][x]
            if ids[(y + 1) % T][x] != me or ids[y][(x + 1) % T] != me:
                g[y][x] = STONE_D if h(152, variant, x, y) % 2 else STONE
            elif ids[(y - 1) % T][x] != me or ids[y][(x - 1) % T] != me:
                g[y][x] = STONE_L if h(153, variant, x, y) % 3 else STONE
    # Alguna brizna en las grietas.
    for i in range(2):
        v = h(154, variant, i)
        x, y = v % T, (v >> 8) % T
        if g[y][x] == STONE_D:
            g[y][x] = K_GRASS_SPECK
    for i in range(3):
        v = h(151, variant, i)
        x, y = v % T, (v >> 8) % T
        if g[y][x] == STONE:
            g[y][x] = STONE_DD
    return g


def cliff(mask, variant):
    """Afloramiento de roca. Bits de mask: lado sin roca. Al norte, oeste y este la roca acaba en
    un borde irregular con contorno; al sur cae en una cara de sombra corta y dentada, con una
    franja de sombra sobre la hierba al pie: se lee como un escalón del terreno, no como un muro."""
    top = rock_top(variant)
    ground = grass(variant)
    seed = 101 + variant
    pn = profile(seed * 5 + 1, 1, 3, 2)
    pw = profile(seed * 5 + 2, 1, 3, 2)
    pe = profile(seed * 5 + 3, 1, 3, 2)
    ft = profile(seed * 5 + 4, 4, 7, 6)    # fila del labio de la cara sur
    fb = profile(seed * 5 + 5, 12, 13, 13)  # última fila de la cara
    # Lajas de la cara sur: anchos que suman 16 (l = canto con luz, m = medio, r = grieta).
    pillar = ""
    for wdt in ([4, 3, 5, 4] if variant == 0 else [3, 5, 4, 4]):
        pillar += "l" + "m" * (wdt - 2) + "r"
    kind = [[None] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            k = "top"
            if mask & S:
                if y > fb[x] + 1:
                    k = "shadow"
                elif y == fb[x] + 1:
                    k = "base"
                elif y > ft[x]:
                    k = "face"
                elif y == ft[x]:
                    k = "lip"
            if (mask & N and y < pn[x]) or (mask & W and x < pw[y]) or (mask & E and x >= T - pe[y]):
                k = "grass"
            kind[y][x] = k
    g = blank()
    for y in range(T):
        for x in range(T):
            k = kind[y][x]
            if k == "grass":
                g[y][x] = ground[y][x]
            elif k == "shadow":
                g[y][x] = K_GRASS_SHADOW
            elif k == "base":
                g[y][x] = OUTLINE
            elif k == "face":
                # Cara: lajas verticales (luz a la izquierda, grieta a la derecha) que se oscurecen
                # hacia el pie.
                col = pillar[x]
                c = STONE_D
                if col == "l":
                    c = STONE
                elif col == "r":
                    c = STONE_DD
                if y >= fb[x] - 1 and c != STONE_DD:
                    c = STONE_DD if col == "r" or y == fb[x] else STONE_D
                if y == ft[x] + 1 and col != "r":
                    c = STONE
                g[y][x] = c
            elif k == "lip":
                g[y][x] = STONE_L
            else:
                g[y][x] = top[y][x]
    # Contorno entre roca y hierba (no en la base, que ya es contorno).
    rock = {"top", "lip", "face"}
    for y in range(T):
        for x in range(T):
            if kind[y][x] not in rock:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < T and 0 <= yy < T and kind[yy][xx] == "grass":
                    g[y][x] = OUTLINE
                    break
    # Luz en el borde norte y oeste, sombra en el este.
    for y in range(T):
        for x in range(T):
            if kind[y][x] != "top" or g[y][x] == OUTLINE:
                continue
            up = g[y - 1][x] if y > 0 else None
            left = g[y][x - 1] if x > 0 else None
            right = g[y][x + 1] if x < T - 1 else None
            if up == OUTLINE or left == OUTLINE:
                g[y][x] = STONE_L
            elif right == OUTLINE:
                g[y][x] = STONE_D
    # Sombra de la cara sur sobre la hierba: más oscura pegada a la roca.
    if mask & S:
        for x in range(T):
            y = fb[x] + 2
            if y < T and kind[y][x] == "shadow":
                g[y][x] = K_GRASS_SHADOW
    return g


CAVE = [
    "................",
    "................",
    "......1122......",
    "....11222223....",
    "...1122222223...",
    "..112222222233..",
    "..12224KK42233..",
    ".1222KKKKKK4233.",
    ".122KKKKKKKK433.",
    ".124KKKKKKKKK33.",
    ".23KKKKKKKKKK43.",
    ".23KKKKKKKKKK43.",
    "233KKKKKKKKKK433",
    "334KKKKKKKKKK433",
    "3344KKKKKKKK4333",
    "................",
]


def cave():
    """Cueva: roca redondeada con boca negra en arco (fondo transparente)."""
    return outline(from_rows(CAVE))


# --- Plaza ---------------------------------------------------------------------------------
# Losas irregulares de la plaza: 1 = losa clara, 2 = losa media, 3 = junta. Mosaico.
PLAZA = [
    [
        "1111311111131111",
        "1111311111132222",
        "1111311111132222",
        "3333333113332222",
        "2222223113111113",
        "2222223333111113",
        "2222223111111113",
        "3333333111111113",
        "1111113333333333",
        "1111113222311111",
        "1111113222311111",
        "3333333222311111",
        "1113111222333333",
        "1113111222311111",
        "1113333333311111",
        "1113111111311111",
    ],
    [
        "2222311113111111",
        "2222311113111111",
        "3333311113111111",
        "1111133333333333",
        "1111131111112222",
        "1111131111112222",
        "3333331111112222",
        "1113333333333333",
        "1113222223111111",
        "1113222223111111",
        "1113222223111111",
        "3333333333333111",
        "1111111131113111",
        "1111111131113333",
        "1111111131112222",
        "3333333331112222",
    ],
]


def plaza(mask, variant):
    """Plaza de losas de piedra. Donde acaba, un bordillo de piedras oscuras y tierra del claro."""
    tex = {"1": STONE_L, "2": STONE_L, "3": STONE}
    g = [[tex[ch] for ch in r] for r in PLAZA[variant]]
    for i in range(3):
        v = h(121, variant, i)
        x, y = v % T, (v >> 8) % T
        if g[y][x] == STONE_L:
            g[y][x] = WHITE
    cells = fringe_cells(mask, 131 + variant, 1, 2, 1)
    for (x, y), kind in cells.items():
        g[y][x] = K_CLEAR if kind == "in" else STONE_DD
    for (x, y), kind in cells.items():
        if kind == "in" and h(132, x, y) % 4 == 0:
            g[y][x] = K_CLEAR_SPECK
    return g


# --- Villa ---------------------------------------------------------------------------------
# Material: 0 = barro (adobe y techo de cañizo), 1 = piedra (mampostería y losas de pizarra).
MATERIALS = [
    # techo claro, techo medio, techo oscuro, muro claro, muro sombra, junta
    (CLAY, DIRT, DIRT_D, SKIN_L, EARTH, DIRT),
    (STONE, STONE_D, STONE_DD, STONE_L, STONE, STONE_D),
]


def roof(material, mask):
    """Techo. mask: 1 = borde norte, 2 = este, 4 = oeste. El alero proyecta sombra abajo."""
    light, mid, dark, _, _, _ = MATERIALS[material]
    g = blank(mid)
    for y in range(T):
        for x in range(T):
            if material == 0:
                # Cañizo: hileras de 3 px con haces oscuros desplazados.
                if y % 3 == 0:
                    g[y][x] = light
                elif y % 3 == 2 and (x + y) % 4 == 0:
                    g[y][x] = dark
            else:
                # Pizarra: losas de 4x3 al tresbolillo.
                if y % 3 == 2:
                    g[y][x] = dark
                elif (x + (y // 3) * 2) % 4 == 0:
                    g[y][x] = dark
                elif y % 3 == 0:
                    g[y][x] = light
    for x in range(T):
        g[15][x] = DIRT_DD if material == 0 else NIGHT  # alero
    if mask & 1:
        for x in range(T):
            g[0][x] = K_CLEAR
            g[1][x] = OUTLINE
            g[2][x] = light
    if mask & 4:
        for y in range(T):
            if g[y][0] != K_CLEAR:
                g[y][0] = OUTLINE
            if g[y][1] not in (K_CLEAR, OUTLINE):
                g[y][1] = light
    if mask & 2:
        for y in range(T):
            if g[y][15] != K_CLEAR:
                g[y][15] = OUTLINE
            if g[y][14] not in (K_CLEAR, OUTLINE, light) or y > 2:
                g[y][14] = dark if g[y][14] != OUTLINE else OUTLINE
    if mask & 1 and mask & 4:
        g[1][0] = K_CLEAR
    if mask & 1 and mask & 2:
        g[1][15] = K_CLEAR
    return g


def facade(material, mask, doorway):
    """Fachada al sur. mask: 1 = borde este, 2 = oeste. Ventanitas o un vano sin puerta."""
    _, _, dark, wall, shade, joint = MATERIALS[material]
    g = blank(wall)
    for y in range(T):
        for x in range(T):
            if material == 0:
                if (x * 3 + y * 5) % 13 == 0:
                    g[y][x] = shade
            else:
                if y % 4 == 3 or (x + (y // 4) * 3) % 6 == 0:
                    g[y][x] = joint
                elif y % 4 == 0 and (x + (y // 4) * 3) % 6 == 1:
                    g[y][x] = WHITE if h(141, x, y) % 5 == 0 else wall
    # Sombra del alero arriba y zócalo abajo.
    for x in range(T):
        g[0][x] = DIRT_DD if material == 0 else NIGHT
        g[1][x] = shade
        g[14][x] = shade
        g[15][x] = OUTLINE
    if doorway:
        # Vano en arco, abierto: sin puerta.
        for y in range(5, 15):
            for x in range(5, 11):
                arch = y >= 7 or (y == 6 and 6 <= x <= 9) or (y == 5 and 7 <= x <= 8)
                if arch:
                    g[y][x] = OUTLINE if 6 <= x <= 9 and y >= 7 else DIRT_DD
        g[6][6] = DIRT_DD
        g[6][9] = DIRT_DD
        g[5][7] = DIRT_DD
        g[5][8] = DIRT_DD
        for y in range(7, 15):
            g[y][5] = dark
            g[y][10] = dark
    else:
        # Ventanita de 2x3 con dintel y alféizar.
        for x0 in (4, 10):
            for y in range(5, 8):
                g[y][x0] = NIGHT
                g[y][x0 + 1] = OUTLINE
            g[4][x0 - 1] = dark
            g[4][x0] = dark
            g[4][x0 + 1] = dark
            g[4][x0 + 2] = dark
            g[8][x0] = WHITE if material == 1 else SAND
            g[8][x0 + 1] = WHITE if material == 1 else SAND
    if mask & 2:
        for y in range(T):
            g[y][0] = OUTLINE
    if mask & 1:
        for y in range(T):
            g[y][15] = OUTLINE
            if 1 < y < 15:
                g[y][14] = shade
    return g


# --- Letrero -------------------------------------------------------------------------------
SIGN_STONE = [
    "................",
    "................",
    "......1112......",
    ".....111222.....",
    "....11222223....",
    "....12222223....",
    "....12222223....",
    "....12222223....",
    "....12222223....",
    "....12222233....",
    "....12222233....",
    "....12222233....",
    "....22222233....",
    "...3322223333...",
    "................",
    "................",
]
# Flechas de 5x5 talladas. Este y sureste; el resto son giros de 90 grados.
ARROW_E = [
    "..x..",
    "...x.",
    "xxxxx",
    "...x.",
    "..x..",
]
ARROW_SE = [
    "x....",
    ".x...",
    "..x.x",
    "...xx",
    "..xxx",
]


def rot_small(rows):
    n = len(rows)
    return ["".join(rows[n - 1 - x][y] for x in range(n)) for y in range(n)]


def sign(direction):
    """Piedra con flecha tallada. direction: 0 = este y sentido horario (ChunkGenerator)."""
    base = ARROW_E if direction % 2 == 0 else ARROW_SE
    arrow = base
    for _ in range(direction // 2):
        arrow = rot_small(arrow)
    g = from_rows(SIGN_STONE)
    ox, oy = 5, 5
    for y in range(5):
        for x in range(5):
            if arrow[y][x] == "x":
                g[oy + y][ox + x] = STONE_DD
    # Luz del tallado: borde inferior derecho del surco.
    for y in range(5):
        for x in range(5):
            if arrow[y][x] == "x":
                xx, yy = ox + x + 1, oy + y + 1
                if (x + 1 >= 5 or y + 1 >= 5 or arrow[y + 1][x + 1] != "x") and g[yy][xx] in (STONE, STONE_D):
                    g[yy][xx] = STONE_L
    return outline(g)


# --- Árboles -------------------------------------------------------------------------------
# Una silueta por forma (PlaceholderTileset.Shape), dos dibujos por forma. A/B = hoja clara/oscura,
# C = tronco, K = contorno interior. El contorno de fuera se añade solo.
TREES = {
    "round": [
        [
            "................",
            "......BBBB......",
            "....BBAAABBB....",
            "...BAAAAABBBB...",
            "..BAAAABBBBBBB..",
            "..BAABBBBBABBB..",
            ".BBABBBBBAABBBB.",
            ".BBBBBBBBBBBBKB.",
            ".BBBBABBBBBBKBB.",
            "..BBBBBBBBBKBB..",
            "..BBKBBBBKKBBB..",
            "...BBKKCKBBBB...",
            ".....BBCCKB.....",
            "......CCCK......",
            ".....CCCCCK.....",
            "................",
        ],
        [
            "................",
            ".....BBB.BBB....",
            "...BBAABBAABB...",
            "..BAAABBAAABBB..",
            "..BAABBBBBBBBB..",
            ".BAABBBBBBBBBBB.",
            ".BABBBABBBBBBKB.",
            ".BBBBAABBBBBKBB.",
            ".BBBBBBBBBBKBBB.",
            "..BBKBBBBBKBBB..",
            "..BBBKBBBKBBBB..",
            "....BBKCCKBB....",
            "......CCCK......",
            "......CCCK......",
            ".....CCCCCC.....",
            "................",
        ],
    ],
    "conifer": [
        [
            "................",
            ".......BB.......",
            "......ABBB......",
            ".....AABBBB.....",
            "......ABBB......",
            ".....AABBBB.....",
            "....AAABBBBB....",
            "...AAABBBBBBK...",
            ".....AABBBB.....",
            "....AAABBBBBB...",
            "...AAABBBBBBBB..",
            "..AAABBBBBBBBKK.",
            "......KCCK......",
            ".......CCK......",
            "......CCCCK.....",
            "................",
        ],
        [
            "................",
            "................",
            ".......AB.......",
            "......AABB......",
            ".....AABBBB.....",
            "......ABBB......",
            ".....AABBBBB....",
            "....AABBBBBBK...",
            "...AAABBBBBBBB..",
            ".....AABBBBB....",
            "....AABBBBBBBB..",
            "..AAABBBBBBBBBKK",
            "......KCCKK.....",
            ".......CCK......",
            "......CCCCK.....",
            "................",
        ],
    ],
    "palm": [
        [
            "................",
            "...BBB....BBB...",
            "..BAAAB..BAAAB..",
            ".BA...BBBB...BB.",
            ".B...AABBAA...B.",
            "....BA.CCBBA....",
            "...BA..CC..BA...",
            "...B...CC...B...",
            "........CC......",
            "........CC......",
            ".........CC.....",
            ".........CC.....",
            ".........CC.....",
            "........CCC.....",
            ".......CCCCC....",
            "................",
        ],
        [
            "................",
            "....BBB..BBB....",
            "..BBAAABBAAABB..",
            ".BA..ABBBBA..AB.",
            ".B..BAABBAAB..B.",
            "...BA..CC..AB...",
            "..BA...CC...AB..",
            "..B...CC.....B..",
            "......CC........",
            ".....CC.........",
            ".....CC.........",
            ".....CC.........",
            ".....CC.........",
            ".....CCC........",
            "....CCCCC.......",
            "................",
        ],
    ],
    "cactus": [
        [
            "................",
            "......CCC.......",
            "......BAB.......",
            ".....BAABB......",
            ".....BAABB...B..",
            "..B..BCABB..BAB.",
            ".BAB.BAABB..BCB.",
            ".BCB.BAABBBBBAB.",
            ".BAB.BAACBBBBB..",
            ".BABBBAABB......",
            "..BBBBAABB......",
            ".....BAACB......",
            ".....BAABB......",
            ".....BAABB......",
            ".....BAABB......",
            "................",
        ],
        [
            "................",
            "................",
            ".......CC.......",
            "......BABB......",
            "..B...BAABB.....",
            ".BAB..BCABB.....",
            ".BCB..BAABB..B..",
            ".BAB..BAABB.BAB.",
            ".BABBBBAACB.BCB.",
            "..BBBBBAABBBBAB.",
            "......BAABBBBB..",
            "......BCABB.....",
            "......BAABB.....",
            "......BAABB.....",
            "......BAABB.....",
            "................",
        ],
    ],
    "thorny": [
        [
            "................",
            ".......A........",
            "..A....A....B...",
            "...A..AAB..B....",
            "....AAAABBB.....",
            "..AAAAABBBBBB...",
            ".AAAABBBBBBBBBB.",
            "...BABBBBBBBB...",
            "....BBBCBBBK....",
            "...B.BBKBKBB.B..",
            "..B...KCCK...B..",
            ".B.....CC.....B.",
            ".......CC.......",
            ".......CC.......",
            "......CCCC......",
            "................",
        ],
        [
            "................",
            "....A......B....",
            ".....A....B.....",
            "..A..AAABBB..B..",
            "...AAAAABBBBB...",
            ".AAAAABBBBBBBBB.",
            "...AABBBCBBBB...",
            "..BABBBBBBBBBB..",
            ".B..BBBBBBBK..B.",
            "...B.BBKBKBB.B..",
            "..B...KCCK......",
            ".......CC.......",
            ".......CC.......",
            ".......CC.......",
            "......CCCC......",
            "................",
        ],
    ],
    "willow": [
        [
            "................",
            ".....BBBBBB.....",
            "...BBAAAABBBB...",
            "..BAAAAABBBBBB..",
            ".BAABBBBBBBBBBB.",
            ".BABBABBBABBBBB.",
            ".BBABBABCBABBAB.",
            ".B.AB.ABCB.BBA..",
            ".B.A..A.CC.B.A..",
            ".B.B..B.CC.B.B..",
            "...B..B.CC...B..",
            "...B....CC......",
            "........CC......",
            "........CC......",
            ".......CCCC.....",
            "................",
        ],
        [
            "................",
            "......BBBBB.....",
            "....BBAAABBBB...",
            "..BBAAAABBBBBB..",
            ".BAABBBBBBBBBBB.",
            ".BABBBBABBBBBBB.",
            ".BBABBABCBBABAB.",
            "..BAB.ABCB.BBAB.",
            "..B.B.A.CC.B.AB.",
            "..B.B...CC.B..B.",
            "..B.....CC.B....",
            "........CC......",
            "........CC......",
            "........CC......",
            ".......CCCC.....",
            "................",
        ],
    ],
}
SHAPES = ["round", "conifer", "palm", "cactus", "thorny", "willow"]
# Frutos (esquina superior izquierda del 2x2) por forma y dibujo. Sobre hoja; el rabillo va encima.
FRUIT_SPOTS = {
    "round": [[(4, 4), (9, 6), (5, 8), (10, 9)], [(4, 4), (9, 3), (6, 7), (10, 8)]],
    "conifer": [[(7, 5), (5, 9), (9, 10)], [(7, 4), (6, 8), (10, 10)]],
    "palm": [[(6, 4), (9, 4)], [(6, 4), (9, 4)]],
    "cactus": [[(6, 4), (7, 10), (13, 6)], [(7, 4), (8, 11), (1, 6)]],
    "thorny": [[(6, 4), (10, 5), (4, 7), (9, 7)], [(5, 4), (9, 4), (4, 6), (10, 6)]],
    "willow": [[(4, 3), (9, 4), (12, 5)], [(5, 3), (10, 3), (3, 5)]],
}
# Tronco hueco del refugio, bajo la copa de la forma (filas 0-6 del dibujo 0).
HOLLOW_TRUNK = [
    "....CCCCCCCC....",
    "....CCCHHCCC....",
    "....CCHKKHCC....",
    "...CCHKKKKHCC...",
    "...CCHKKKKHCC...",
    "...CCHKKKKHCC...",
    "..CCCHKKKKHCCC..",
    ".CCC.HKKKKH.CCC.",
    "................",
]
HOLLOW_CACTUS = [
    "....BBAABBBB....",
    "....BAABBBBB....",
    "....BAHHHHBB....",
    "...BBHKKKKHBB...",
    "...BAHKKKKHBB...",
    "...BAHKKKKHBB...",
    "...BBHKKKKHBB...",
    "..BBBHKKKKHBBB..",
    "................",
]


def tree(shape, variant):
    return outline(from_rows(TREES[shape][variant % 2]))


def fruit_tree(shape, variant, ripe):
    g = tree(shape, variant)
    for x, y in FRUIT_SPOTS[shape][variant % 2]:
        rows = TREES[shape][variant % 2]
        for px, py in ((x, y - 1), (x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)):
            # La palmera cuelga los cocos bajo las hojas: solo se exige que toquen la copa.
            if rows[py][px] not in "ABCK" and shape != "palm":
                raise ValueError("fruto de %s/%d fuera de la copa en %s" % (shape, variant, (x, y)))
        g[y - 1][x] = DIRT_D
        if ripe:
            g[y][x] = K_FRUIT
            g[y][x + 1] = K_FRUIT
            g[y + 1][x] = K_FRUIT
            g[y + 1][x + 1] = K_FRUIT_SHADOW
    return g


def hollow_tree(shape):
    rows = TREES[shape][0][:7] + (HOLLOW_CACTUS if shape == "cactus" else HOLLOW_TRUNK)
    return outline(from_rows(rows))


# --- Hojas ---------------------------------------------------------------------------------
def build():
    """Devuelve {archivo: (columnas, filas, {(col, fila): casilla})}."""
    sheets = {}
    cells = {}
    for v in range(4):
        cells[(v, 0)] = grass(v)
        cells[(v, 1)] = rocky(v)
    for m in range(16):
        for v in range(2):
            cells[(m, 2 + v)] = clearing(m, v)
    sheets["tileset_suelo.png"] = (16, 4, cells)
    sheets["tileset_sendero.png"] = (16, 2, {(m, v): path(m, v) for m in range(16) for v in range(2)})
    sheets["tileset_camino.png"] = (16, 2, {(m, v): road(m, v) for m in range(16) for v in range(2)})
    cells = {}
    for k, kind in enumerate(["narrow", "navigable", "ford"]):
        for f in range(2):
            for m in range(16):
                cells[(m, k * 2 + f)] = water(kind, m, f)
    sheets["tileset_agua.png"] = (16, 6, cells)
    sheets["tileset_puente.png"] = (2, 2, {(o, v): bridge(o, v) for o in range(2) for v in range(2)})
    cells = {(m, v): cliff(m, v) for m in range(16) for v in range(2)}
    cells[(0, 2)] = cave()
    sheets["tileset_risco.png"] = (16, 3, cells)
    sheets["tileset_plaza.png"] = (16, 2, {(m, v): plaza(m, v) for m in range(16) for v in range(2)})
    cells = {}
    for mat in range(2):
        for m in range(8):
            cells[(m, mat)] = roof(mat, m)
        for m in range(4):
            cells[(8 + m, mat)] = facade(mat, m, False)
            cells[(12 + m, mat)] = facade(mat, m, True)
    sheets["tileset_villa.png"] = (16, 2, cells)
    sheets["tileset_letrero.png"] = (8, 1, {(d, 0): sign(d) for d in range(8)})
    cells = {}
    for r, shape in enumerate(SHAPES):
        for v in range(4):
            g = tree(shape, v)
            cells[(v, r)] = mirror(g) if v >= 2 else g
        for v in range(2):
            cells[(4 + v, r)] = fruit_tree(shape, v, True)
            cells[(6 + v, r)] = fruit_tree(shape, v, False)
        cells[(8, r)] = hollow_tree(shape)
    sheets["tileset_arboles.png"] = (9, 6, cells)
    return sheets


def to_image(cols, rows, cells):
    img = Image.new("RGBA", (cols * T, rows * T), (0, 0, 0, 0))
    for (cx, cy), g in cells.items():
        for y in range(T):
            for x in range(T):
                c = g[y][x]
                if c is not None:
                    img.putpixel((cx * T + x, cy * T + y), (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255))
    return img


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="carpeta para vistas ampliadas x6")
    args = parser.parse_args()
    palette = load_palette()
    for name, c in list(CHARS.items()):
        if c not in palette:
            sys.exit("color %s (%s) fuera de paleta" % (name, c))
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, (cols, rows, cells) in build().items():
        img = to_image(cols, rows, cells)
        check_palette(img, palette, name)
        img.save(os.path.join(OUT_DIR, name))
        print("%s %dx%d" % (name, img.width, img.height))
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            bg = Image.new("RGBA", img.size, (255, 0, 68, 255))
            bg.alpha_composite(img)
            bg.resize((img.width * 6, img.height * 6), Image.NEAREST).save(os.path.join(args.preview, name))


if __name__ == "__main__":
    main()
