"""Genera el arte del Mundo 2.0, primera pasada (hito M13; spec docs/art/specs/mundo-2.md).

Escribe en assets/tilesets/ los atlas de la tabla de piezas con prioridad M13:
    tileset_hierba.png        hierba, 4 variantes
    tileset_relieve.png       caras de risco, bordes, esquinas, uniones, escaleras, rampas y cueva
    tileset_cascada.png       cascada y espuma, 4 fotogramas
    tileset_sombras.png       sombra al pie, sombra este y sombra de objeto
    tileset_decoracion.png    flores, matas, helechos, hojarasca, setas y raíces
    tileset_piedras.png       piedrecitas y grieta seca
    tileset_puente_ancho.png  puente de 3 (norte-sur dibujado, este-oeste girado)
    sprite_arboles.png        árboles 2x2: 4 variantes, frutal, vaciado, hueco y seco por silueta
    sprite_arbol_joven.png    árbol joven 1x1, 2 variantes por silueta
    sprite_arbol_grande.png   árbol grande 3x3 por silueta
    sprite_rocas.png          rocas 2x2, 3 variantes
    sprite_rocas_pequenas.png rocas 1x1, 2 variantes
    sprite_madera.png         tocones 1x1 y troncos caídos 2x1
    sprite_casas.png          casas 4x3, 2 materiales x 2 variantes
    sprite_nujio.png          Nujio 64x80 por silueta, 2 fotogramas

Todo con los 32 colores de assets/palettes/palette_nuevos_bosques.gpl, alfa 0 o 255. Cada atlas solo
usa sus claves de color (spec §2.5, tabla ATLASES) y sus colores fijos; el script lo comprueba y
para si no. Las claves las cambia el juego por los colores del Bosque (TerrainTileset). No cambies
una clave sin cambiar a la vez TerrainTileset, la spec y tests/unit/world/test_world2_art.gd.

Todo es determinista: mismas entradas, mismos píxeles (hash FNV de make_tiles.h, sin random).

Uso (desde la raíz del repo):
    python tools/art/make_world2.py                  # escribe los PNG
    python tools/art/make_world2.py --preview D      # además, cada atlas x3 en la carpeta D
    python tools/art/make_world2.py --sheet F.png    # además, hoja de contacto x3 (atlas y
                                                     # recoloreado de muestra por Bosque)
"""
import argparse
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import load_palette  # noqa: E402
from make_tiles import h  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "tilesets")
T = 16

# --- Colores ---------------------------------------------------------------------------------
OUTLINE = "181425"
# Claves (spec §2.1).
K_GRASS = "3e8948"
K_GRASS_SPECK = "63c74d"
K_GRASS_SHADOW = "265c42"
K_CLEAR = "ead4aa"
K_CLEAR_SPECK = "e4a672"
K_LEAF_LIGHT = "c0cbdc"
K_LEAF_DARK = "8b9bb4"
K_TRUNK = "5a6988"
K_FRUIT = "e43b44"
K_FRUIT_SHADOW = "a22633"
K_LEAF_SHADOW = "3a4466"
K_FLOWER = ["e43b44", "f6757a", "ff0044"]
# Fijos.
WHITE = "ffffff"
YELLOW = "fee761"
ROCK_L = "c0cbdc"
ROCK = "8b9bb4"
ROCK_D = "5a6988"
ROCK_DD = "3a4466"
NIGHT = "262b44"
DIRT_L = "e4a672"
DIRT = "b86f50"
DIRT_D = "733e39"
DIRT_DD = "3e2731"
SAND = "ead4aa"
EARTH = "c28569"
SKIN = "e8b796"
CLAY = "d77643"
CLAY_D = "be4a2f"
WATER_DD = "124e89"
WATER_D = "0099db"
WATER_L = "2ce8f5"

GRASS_KEYS = {K_GRASS, K_GRASS_SPECK, K_GRASS_SHADOW}
CLEAR_KEYS = {K_CLEAR, K_CLEAR_SPECK}
TREE_KEYS = {K_LEAF_LIGHT, K_LEAF_DARK, K_TRUNK, K_LEAF_SHADOW}
FRUIT_KEYS = {K_FRUIT, K_FRUIT_SHADOW}
FLOWER_KEYS = set(K_FLOWER)
LEAF = (K_LEAF_LIGHT, K_LEAF_DARK, K_LEAF_SHADOW)
GREYS = {ROCK_L, ROCK, ROCK_D, ROCK_DD, NIGHT}
WATER = {WATER_DD, WATER_D, WATER_L, WHITE}

SHAPES = ["round", "conifer", "palm", "cactus", "thorny", "willow"]  # orden de PlaceholderTileset.Shape

# Atlas: tamaño, claves (se recolorean) y colores fijos permitidos (spec §2.5 y §8).
ATLASES = {
    "tileset_hierba.png": ((64, 16), GRASS_KEYS, set()),
    "tileset_relieve.png": ((256, 192), GRASS_KEYS, {OUTLINE, DIRT_L, DIRT, DIRT_D, SAND} | GREYS),
    "tileset_cascada.png": ((192, 64), GRASS_KEYS, {OUTLINE} | GREYS | WATER),
    "tileset_sombras.png": ((128, 48), GRASS_KEYS, {DIRT_D, DIRT_L, WATER_DD}),
    "tileset_decoracion.png": ((256, 48), GRASS_KEYS | TREE_KEYS | FLOWER_KEYS, {WHITE, CLAY_D, SKIN, DIRT_D}),
    "tileset_piedras.png": ((64, 16), GRASS_KEYS, GREYS),
    "tileset_puente_ancho.png": ((96, 48), set(), {OUTLINE, DIRT_L, DIRT, DIRT_D, DIRT_DD, WATER_DD, WATER_D}),
    "sprite_arboles.png": ((320, 192), GRASS_KEYS | TREE_KEYS | FRUIT_KEYS, {OUTLINE, DIRT_DD}),
    "sprite_arbol_joven.png": ((32, 96), GRASS_KEYS | TREE_KEYS | FRUIT_KEYS, {OUTLINE, DIRT_DD}),
    "sprite_arbol_grande.png": ((48, 288), GRASS_KEYS | TREE_KEYS | FRUIT_KEYS, {OUTLINE, DIRT_DD}),
    "sprite_rocas.png": ((96, 32), GRASS_KEYS, {OUTLINE} | GREYS),
    "sprite_rocas_pequenas.png": ((32, 16), GRASS_KEYS, {OUTLINE} | GREYS),
    "sprite_madera.png": ((96, 16), GRASS_KEYS | TREE_KEYS, {OUTLINE, DIRT_L, DIRT}),
    "sprite_casas.png": ((128, 96), CLEAR_KEYS,
                         {OUTLINE, SKIN, EARTH, CLAY, DIRT, DIRT_D, DIRT_DD, ROCK_L, ROCK, ROCK_D, ROCK_DD, NIGHT}),
    "sprite_nujio.png": ((128, 480), GRASS_KEYS | TREE_KEYS, {OUTLINE, WATER_L, WHITE}),
}


def rgba(c):
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)


class Canvas:
    def __init__(self, w, hgt, fill=None):
        self.w, self.h = w, hgt
        self.px = [[fill] * w for _ in range(hgt)]

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                self.set(x, y, c)

    def copy(self):
        out = Canvas(self.w, self.h)
        out.px = [row[:] for row in self.px]
        return out

    def outline(self, color=OUTLINE):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    v = self.get(x + dx, y + dy)
                    if v is not None and v != color:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y][x] = color

    def under(self, other):
        """Pinta `other` solo donde este lienzo está vacío."""
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is None and other.px[y][x] is not None:
                    self.px[y][x] = other.px[y][x]

    def paste(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                if other.px[y][x] is not None:
                    self.set(ox + x, oy + y, other.px[y][x])

    def mirror(self):
        out = Canvas(self.w, self.h)
        out.px = [row[::-1] for row in self.px]
        return out

    def rot_ccw(self):
        """Giro de 90 grados antihorario (el norte pasa al oeste)."""
        out = Canvas(self.h, self.w)
        for y in range(self.h):
            for x in range(self.w):
                out.px[self.w - 1 - x][y] = self.px[y][x]
        return out

    def count(self, colors):
        return sum(1 for row in self.px for c in row if c in colors)

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = img.load()
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    px[x, y] = rgba(self.px[y][x])
        return img


def clean_singletons(cv, colors):
    """Quita los píxeles sueltos (sin vecino del mismo color) de `colors`: las copas van en grumos,
    nunca en ruido de 1 px (spec §4)."""
    changes = []
    for y in range(cv.h):
        for x in range(cv.w):
            c = cv.px[y][x]
            if c not in colors:
                continue
            nb = [cv.get(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if c in nb:
                continue
            cand = [n for n in nb if n in colors]
            if cand:
                changes.append((x, y, max(set(cand), key=cand.count)))
    for x, y, c in changes:
        cv.px[y][x] = c


def ellipse(cv, cx, cy, rx, ry, c, only_empty=True):
    for y in range(cv.h):
        for x in range(cv.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                if not only_empty or cv.px[y][x] is None:
                    cv.px[y][x] = c


def line(cv, x0, y0, x1, y1, c, width=1):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for k in range(width):
            cv.set(math.floor(x) + k, math.floor(y), c)


# =============================================================================================
# Hierba (spec §6.1)
# =============================================================================================
def grass(variant):
    """Base de hierba sin detalle en el píxel del borde: cualquier variante casa con cualquiera."""
    cv = Canvas(T, T, K_GRASS)

    def blade(x, y):  # brizna: claro arriba, sombra al pie
        cv.set(x, y, K_GRASS_SPECK)
        cv.set(x, y + 1, K_GRASS_SHADOW)

    def tuft(x, y, tall=False):  # mata en V
        cv.set(x - 1, y, K_GRASS_SPECK)
        cv.set(x + 1, y, K_GRASS_SPECK)
        cv.set(x, y + 1, K_GRASS_SPECK)
        if tall:
            cv.set(x - 2, y - 1, K_GRASS_SPECK)
            cv.set(x + 2, y - 1, K_GRASS_SPECK)
        cv.set(x, y + 2, K_GRASS_SHADOW)

    if variant == 0:  # A: rasa
        for x, y in ((4, 5), (11, 9), (6, 12)):
            blade(x, y)
    elif variant == 1:  # B: matas en V
        for x, y, tall in ((4, 3, False), (11, 6, True), (5, 10, True), (12, 12, False)):
            tuft(x, y, tall)
    elif variant == 2:  # C: densa
        for x, y, tall in ((3, 3, True), (9, 2, False), (12, 6, True), (6, 7, False), (3, 11, False),
                           (10, 11, True)):
            tuft(x, y, tall)
        for x, y in ((7, 4), (13, 10), (7, 13), (2, 7)):
            cv.set(x, y, K_GRASS_SHADOW)
    else:  # D: briznas claras sueltas
        for x, y in ((3, 3), (8, 2), (12, 4), (5, 8), (10, 8), (2, 12), (8, 12), (13, 13)):
            cv.set(x, y, K_GRASS_SPECK)
        blade(11, 11)
    # Garantía: el borde de 1 px queda liso.
    for i in range(T):
        for x, y in ((i, 0), (i, T - 1), (0, i), (T - 1, i)):
            cv.set(x, y, K_GRASS)
    return cv


# =============================================================================================
# Relieve (spec §3)
# =============================================================================================
# Lajas por columna: anchos que suman 16, con un corte en x = 0 (los medios casan en cualquier
# orden y la columna sigue igual en el labio, las intermedias y la base).
LAJAS = {"A": (6, 4, 6), "B": (5, 7, 4), "C": (4, 5, 7)}
LIP_DENTS = {"A": (5, 11), "B": (3, 8, 13), "C": (6, 12)}  # x con labio de 2 px (dentado)
FACE_COLS = ["left", "A", "B", "C", "right", "single"]
WALL = 10    # profundidad de la pared este/oeste
NORTH = 5    # profundidad del labio norte


def lip_depth(laja, x):
    return 2 if x in LIP_DENTS[laja] else 3


def face_rock(laja, part, x, y, seed):
    """Color de la roca de una cara. part: 'lip', 'mid' o 'base'; (x, y) en la casilla."""
    widths = LAJAS[laja]
    acc = 0
    for i, w in enumerate(widths):
        if x < acc + w:
            k, rel, wid = i, x - acc, w
            break
        acc += w
    upper = y < 8
    if part == "lip":
        body = ROCK_L if y < 7 else ROCK
        left, right = ROCK_L, ROCK_D
    elif part == "mid":
        body = ROCK if upper else ROCK_D
        left, right = (ROCK_L if upper else ROCK), (ROCK_D if upper else ROCK_DD)
    else:
        body = ROCK_D if y < 7 else ROCK_DD
        left, right = ROCK, ROCK_DD
    c = left if rel == 0 else (right if rel == wid - 1 else body)
    # Grietas horizontales cortas.
    v = h(seed, ord(laja), k, ord(part[0]))
    cy = 5 + v % 7
    cx0 = acc + 1 + (v >> 8) % max(1, wid - 2)
    if y == cy and cx0 <= x < cx0 + 2 + (v >> 12) % 2 and rel not in (0, wid - 1) and v % 3:
        c = ROCK_DD
    if part == "base":
        if y >= T - 3:
            c = NIGHT
        if y == T - 1:
            c = OUTLINE
    return c


def face_tile(col, part, seed=21):
    """Cara de risco hacia el sur: col en FACE_COLS; part 'lip', 'mid' o 'base'."""
    laja = col if col in LAJAS else "A"
    cv = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            cv.set(x, y, face_rock(laja, part, x, y, seed))
    if part == "lip":
        for x in range(T):
            d = lip_depth(laja, x)
            for y in range(d):
                cv.set(x, y, K_GRASS if y < d - 1 else K_GRASS_SHADOW)
            cv.set(x, d, OUTLINE)
    if part == "base":
        # 1-3 lajas caídas de 2x2 al pie.
        for i in range(1 + h(seed, ord(col[0]), 7) % 3):
            x = 2 + h(seed, ord(col[0]), i) % 11
            cv.set(x, T - 4, ROCK_L)
            cv.set(x + 1, T - 4, ROCK)
            cv.set(x, T - 3, ROCK)
            cv.set(x + 1, T - 3, ROCK_D)
    sides = {"left": (True, False), "right": (False, True), "single": (True, True)}.get(col, (False, False))
    for side_left, on in ((True, sides[0]), (False, sides[1])):
        if on:
            face_end(cv, part, side_left)
    return cv


def wall_pixel(xx, depth, lit):
    """Píxel de una pared lateral a xx px del canto (0 = canto exterior)."""
    if xx == 0 or xx == depth - 1:
        return OUTLINE
    if xx < 3:
        return ROCK_L if lit else ROCK
    if lit:
        return ROCK if (xx // 2) % 2 else ROCK_D
    return ROCK_D if (xx // 2) % 2 else ROCK_DD


def face_end(cv, part, left):
    """Extremo redondeado de la cara: en el labio enlaza con la pared lateral de encima; en la base
    se retira 4 px con el contorno siguiendo la curva y hierba de abajo fuera."""
    def X(x):
        return x if left else T - 1 - x
    for y in range(T):
        inset = round(4 * (y / (T - 1)) ** 2) if part == "base" else 0
        for x in range(inset):
            cv.set(X(x), y, K_GRASS)
        if part == "base" and inset:
            cv.set(X(inset - 1), y, K_GRASS_SHADOW if y > 2 else K_GRASS)
        cv.set(X(inset), y, OUTLINE)
        if y < T - 3:
            cv.set(X(inset + 1), y, (ROCK_L if part != "base" else ROCK) if left else ROCK_DD)
    if part == "lip":
        # La pared lateral de la casilla de encima (10 px) baja por el labio hasta el contorno.
        for y in range(4):
            for xx in range(WALL):
                cv.set(X(xx), y, wall_pixel(xx, WALL, left))
        for xx in range(WALL):
            cv.set(X(xx), 4, ROCK_L if left and 0 < xx < WALL - 1 else (OUTLINE if xx in (0, WALL - 1) else ROCK))


def plain_grass():
    cv = Canvas(T, T, K_GRASS)
    for x, y in ((6, 9), (11, 12), (4, 13)):
        cv.set(x, y, K_GRASS_SPECK)
        cv.set(x, y + 1, K_GRASS_SHADOW)
    return cv


def north_depth(x, seed=31):
    if x in (0, 1, T - 2, T - 1):
        return NORTH
    return NORTH + (1 if h(seed, x // 4) % 3 == 0 else 0)


def side_depth(y, bit, seed=33):
    if y in (0, 1, T - 2, T - 1):
        return WALL
    return WALL + (1 if h(seed, bit, y // 5) % 3 == 0 else 0)


def border(mask):
    """Borde de meseta: 1 = norte, 2 = este, 8 = oeste. Opaco, sobre la hierba de la meseta."""
    cv = plain_grass()
    both = mask & 2 and mask & 8
    dn = {x: north_depth(x) for x in range(T)}
    rock = {}
    # Paredes laterales.
    for bit, lit in ((8, True), (2, False)):
        if not mask & bit:
            continue
        for y in range(T):
            d = 8 if both else side_depth(y, bit)
            for xx in range(d):
                x = xx if lit else T - 1 - xx
                if mask & 1 and y < dn[x] and 0 < xx < d - 1:
                    continue  # el labio norte manda en el cruce
                rock[(x, y)] = wall_pixel(xx, d, lit)
    # Labio norte.
    if mask & 1:
        for x in range(T):
            d = dn[x]
            inside_wall = (mask & 8 and x < WALL - 1) or (mask & 2 and x > T - WALL)
            for y in range(d + 1):
                if y == 0:
                    c = OUTLINE
                elif y == 1:
                    c = ROCK_L
                elif y < d - 1:
                    c = ROCK_D if (x + 2 * y) % 6 == 0 else ROCK
                elif y == d - 1:
                    c = OUTLINE if not inside_wall else ROCK
                else:
                    c = K_GRASS_SHADOW if not inside_wall else None
                if c is not None and (x, y) not in rock or c in (OUTLINE, ROCK_L) and y < 2:
                    rock[(x, y)] = c
        # Esquinas exteriores redondeadas (radio 4) en 9 (NO) y 3 (NE).
        r = 4
        for bit, lit in ((8, True), (2, False)):
            if not mask & bit:
                continue
            for y in range(r):
                for xx in range(r):
                    x = xx if lit else T - 1 - xx
                    d = math.hypot(xx + 0.5 - r, y + 0.5 - r)
                    if d > r:
                        rock[(x, y)] = K_GRASS
                    elif d > r - 1:
                        rock[(x, y)] = OUTLINE
                    elif d > r - 2:
                        rock[(x, y)] = ROCK_L if lit else ROCK
    for (x, y), c in rock.items():
        cv.set(x, y, c)
    return cv


def inner_join(left):
    """Unión interior NO (left) o NE: muesca diagonal donde el labio norte de la casilla vecina se
    encuentra con la pared lateral de la casilla de encima."""
    cv = plain_grass()
    for y in range(NORTH + 1):
        w = WALL - 2 * y
        for xx in range(max(w, 0)):
            if y == 0:
                c = wall_pixel(xx, WALL, left)
            elif xx >= w - 2:
                c = OUTLINE
            elif xx == 0:
                c = (ROCK_L if y == 1 else (ROCK if y < NORTH - 1 else OUTLINE)) if left else \
                    (ROCK if y == 1 else (ROCK_D if y < NORTH - 1 else OUTLINE))
            else:
                c = (ROCK_L if y == 1 or xx < 3 else ROCK) if left else (ROCK if y == 1 else ROCK_DD)
            cv.set(xx if left else T - 1 - xx, y, c)
        if w >= 0:
            cv.set(w if left else T - 1 - w, y, K_GRASS_SHADOW)
    return cv


def wall_join(left):
    """Remate de cara contra pared: la cara (labio) acaba recta contra la pared de la vecina."""
    cv = face_tile("B", "lip")
    x0, x1 = (0, 1) if left else (T - 1, T - 2)
    for y in range(T):
        cv.set(x0, y, OUTLINE)
        if y > 3:
            cv.set(x1, y, ROCK_DD)
    return cv


def stairs(col, part):
    """Escalera: peldaños de 4 px (huella, tabica, junta) con mejillas de roca de 3 px."""
    cv = Canvas(T, T)
    for y in range(T):
        k = y % 4
        c = DIRT_L if k < 2 else (DIRT if k == 2 else DIRT_D)
        if part == "base" and y >= T - 4:
            c = DIRT_L if y < T - 1 else DIRT
        for x in range(T):
            cv.set(x, y, c)
    if col in ("left", "right"):
        left = col == "left"
        for y in range(T):
            for xx in range(3):
                x = xx if left else T - 1 - xx
                if xx == 2:
                    c = OUTLINE
                else:
                    c = face_rock("A", part, (14 + xx) if left else xx, y, 21)
                    if part == "lip" and y < 4:
                        c = K_GRASS if y < 2 else (K_GRASS_SHADOW if y == 2 else OUTLINE)
                cv.set(x, y, c)
            # Sombra de la mejilla sobre el peldaño.
            if not left and cv.get(T - 4, y) in (DIRT_L, SAND):
                cv.set(T - 4, y, DIRT)
    return cv


def path_base(material, seed):
    cv = Canvas(T, T, DIRT if material == "sendero" else SAND)
    for i in range(5):
        v = h(seed, i)
        x, y = 1 + v % 14, 1 + (v >> 8) % 14
        cv.set(x, y, (DIRT_L if i % 2 else DIRT_D) if material == "sendero" else DIRT_L)
    return cv


SLOPE = [1, 3, 5, 8, 11, 14]  # marcas de pendiente, más juntas cuesta abajo


def slope_dash(seed, k, i):
    """Marca de pendiente a trozos: rayas de 3-5 px con huecos de 2, desfasadas por marca."""
    period = 6 + h(seed, k) % 2
    return (i + h(seed, k, 1) % period) % period < period - 2


def ramp_n(material, col):
    """Rampa norte (cuesta abajo hacia el norte): marcas horizontales, hierba en los lados."""
    cv = path_base(material, 50 + FACE_COLS.index(col) if col in FACE_COLS else 53)
    mark = DIRT_D if material == "sendero" else DIRT_L
    for y in SLOPE:
        for x in range(T):
            if slope_dash(60, y, x):
                cv.set(x, y, mark)
    if col in ("left", "right"):
        left = col == "left"
        for y in range(T):
            for xx in range(3):
                x = xx if left else T - 1 - xx
                cv.set(x, y, K_GRASS if xx < 2 else K_GRASS_SHADOW)
        # El labio norte de la vecina baja hasta desaparecer.
        for xx in range(5):
            d = NORTH - xx
            x = xx if left else T - 1 - xx
            for y in range(d):
                cv.set(x, y, OUTLINE if y == 0 or y == d - 1 else ROCK_L if y == 1 else ROCK)
    return cv


def ramp_side(material, part, east):
    """Rampa oeste (o este si `east`): marcas verticales, hierba arriba o abajo; la pared de la
    casilla de encima (o de debajo) baja hasta desaparecer."""
    cv = path_base(material, 70 + ("arriba", "medio", "abajo").index(part))
    mark = DIRT_D if material == "sendero" else DIRT_L
    for x in SLOPE:
        for y in range(T):
            if slope_dash(61, x, y):
                cv.set(x, y, mark)
    if part == "arriba":
        for y in range(3):
            for x in range(T):
                cv.set(x, y, K_GRASS if y < 2 else K_GRASS_SHADOW)
    if part == "abajo":
        for y in range(T - 3, T):
            for x in range(T):
                cv.set(x, y, K_GRASS)
    if east:
        cv = cv.mirror()
    lit = not east
    for y in range(T):
        if part == "arriba":
            d = WALL - int(2.5 * y)
        elif part == "abajo":
            d = int(2.5 * (y - (T - 5)))
        else:
            d = 0
        for xx in range(max(0, min(d, WALL))):
            x = xx if lit else T - 1 - xx
            cv.set(x, y, OUTLINE if xx in (0, d - 1) else wall_pixel(xx, WALL, lit))
    return cv


def cave(with_lip):
    """Cueva 2x2 en una cara: boca en arco de 19x17 apoyada en la base."""
    top = "lip" if with_lip else "mid"
    cv = Canvas(2 * T, 2 * T)
    for i, laja in enumerate(("A", "B")):
        cv.paste(face_tile(laja, top), i * T, 0)
        cv.paste(face_tile(laja, "base"), i * T, T)
    cx, r, y_top = 15.5, 9.5, 14
    cy = y_top + 9.0
    mouth = set()
    for y in range(y_top, 2 * T):
        for x in range(2 * T):
            dx = (x + 0.5 - cx) / r
            if y + 0.5 >= cy:
                inside = abs(dx) <= 1
            else:
                inside = dx * dx + ((y + 0.5 - cy) / 9.0) ** 2 <= 1
            if inside:
                mouth.add((x, y))
    for (x, y) in mouth:
        cv.set(x, y, OUTLINE)
    # Franja interior de arriba (más clara) y canto iluminado alrededor del arco.
    for (x, y) in mouth:
        if (x, y - 1) not in mouth or (x, y - 2) not in mouth:
            if y < 2 * T - 1:
                cv.set(x, y, NIGHT)
    for (x, y) in list(mouth):
        for dx, dy in ((0, -1), (-1, 0), (1, 0)):
            p = (x + dx, y + dy)
            if p not in mouth and 0 <= p[0] < 2 * T and y + dy < 2 * T - 3:
                cv.set(p[0], p[1], ROCK_L if p[0] < cx else ROCK_DD)
    # Rocas caídas junto a la boca.
    for (x0, y0) in ((2, 27), (26, 28)):
        cv.rect(x0, y0, x0 + 3, y0 + 2, ROCK)
        cv.set(x0, y0, ROCK_L)
        cv.set(x0 + 2, y0 + 1, ROCK_DD)
        for x in range(x0, x0 + 3):
            cv.set(x, y0 + 2, OUTLINE)
        cv.set(x0 - 1, y0 + 1, OUTLINE)
        cv.set(x0 + 3, y0 + 1, OUTLINE)
    return cv


def build_relieve():
    atlas = Canvas(256, 192)
    for r, part in enumerate(("lip", "mid", "base")):
        for c, col in enumerate(FACE_COLS):
            atlas.paste(face_tile(col, part), c * T, r * T)
        for c, col in enumerate(("left", "mid", "right")):
            atlas.paste(stairs(col, part), (6 + c) * T, r * T)
    atlas.paste(cave(True), 9 * T, 0)
    atlas.paste(cave(False), 11 * T, 0)
    for mask in (1, 2, 3, 8, 9, 10, 11):
        atlas.paste(border(mask), mask * T, 3 * T)
    atlas.paste(inner_join(True), 0, 4 * T)
    atlas.paste(inner_join(False), T, 4 * T)
    atlas.paste(wall_join(True), 2 * T, 4 * T)
    atlas.paste(wall_join(False), 3 * T, 4 * T)
    for m, material in enumerate(("sendero", "camino")):
        for c, col in enumerate(("left", "mid", "right")):
            atlas.paste(ramp_n(material, col), (3 * m + c) * T, 5 * T)
        for r, part in enumerate(("arriba", "medio", "abajo")):
            atlas.paste(ramp_side(material, part, False), (6 + m) * T, (5 + r) * T)
            atlas.paste(ramp_side(material, part, True), (8 + m) * T, (5 + r) * T)
    return atlas


# =============================================================================================
# Cascada (spec §3.5)
# =============================================================================================
THREADS = [(1, WATER_D, 9, 0), (4, WATER_L, 6, 5), (8, WATER_D, 10, 11), (11, WATER_L, 7, 3),
           (14, WATER_D, 8, 8)]  # (x, color, largo, desfase); periodo 16 en x y en y


def falling_water(x, y, frame):
    for tx, c, ln, off in THREADS:
        if x == tx and (y - 4 * frame + off) % 16 < ln:
            return c
    return WATER_DD


def cascade(col, part, frame):
    cv = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            cv.set(x, y, falling_water(x, y, frame))
    if part == "lip":
        for x in range(T):
            cv.set(x, 0, WATER_D)
            cv.set(x, 1, WATER_D)
            cv.set(x, 2, WATER_L)
            cv.set(x, 3, WATER_L)
    if col in ("left", "right"):
        left = col == "left"
        for y in range(T):
            for xx in range(3):
                x = xx if left else T - 1 - xx
                if xx == 2:
                    c = OUTLINE
                else:
                    c = face_rock("A", part, (14 + xx) if left else xx, y, 21)
                    if part == "lip" and y < 4:
                        c = K_GRASS if y < 2 else (K_GRASS_SHADOW if y == 2 else OUTLINE)
                cv.set(x, y, c)
    return cv


FOAM_OFFSETS = [0, 1, 2, 1]  # vaivén de 1 px por fotograma


def foam(col, frame):
    cv = Canvas(T, T, WATER_D)
    off = FOAM_OFFSETS[frame]
    for x in range(T):
        gx = (x + off) % 16
        d = 3 + (h(80, gx // 3) % 3)  # 3-5 px
        if col == "left" and x < 3 or col == "right" and x > T - 4:
            d = 2
        for y in range(d):
            c = WATER_L if y == d - 1 or h(81, gx // 2, y) % 5 == 0 else WHITE
            cv.set(x, y, c)
    for y, x0 in ((9, 3), (12, 9), (14, 2)):
        for x in range(x0, x0 + 4):
            cv.set((x + off) % T, y, WATER_L)
    cv.set((6 + off) % T, 7, WATER_DD)
    cv.set((13 + off) % T, 10, WATER_DD)
    return cv


def build_cascada():
    atlas = Canvas(192, 64)
    for c, col in enumerate(("left", "mid", "right")):
        for f in range(4):
            x = (c * 4 + f) * T
            for r, part in enumerate(("lip", "mid", "base")):
                atlas.paste(cascade(col, part, f), x, r * T)
            atlas.paste(foam(col, f), x, 3 * T)
    return atlas


# =============================================================================================
# Sombras (spec §3.6)
# =============================================================================================
SHADOW_COLORS = [K_GRASS_SHADOW, K_GRASS_SHADOW, DIRT_D, DIRT_L, WATER_DD]  # hierba A/B, sendero, camino, agua


def foot_shadow(i):
    cv = Canvas(T, T)
    for x in range(T):
        d = (4 if x % 2 == 0 else 3) if i != 1 else (4 if (x // 2) % 2 == 0 else 3)
        for y in range(d):
            cv.set(x, y, SHADOW_COLORS[i])
    return cv


def east_shadow(i):
    cv = Canvas(T, T)
    for y in range(T):
        d = (3 if y % 2 == 0 else 2) if i != 1 else (3 if (y // 2) % 2 == 0 else 2)
        for x in range(d):
            cv.set(x, y, SHADOW_COLORS[i])
    return cv


def object_shadow(kind):
    x0, x1 = {"left": (1, T), "mid": (0, T), "right": (0, T - 2), "se": (0, T - 1)}[kind]
    cv = Canvas(T, T)
    cv.rect(x0, 0, x1, 2, K_GRASS_SHADOW)
    return cv


def build_sombras():
    atlas = Canvas(128, 48)
    for i in range(5):
        atlas.paste(foot_shadow(i), i * T, 0)
        atlas.paste(east_shadow(i), i * T, T)
    for i, kind in enumerate(("left", "mid", "right", "se")):
        atlas.paste(object_shadow(kind), i * T, 2 * T)
    return atlas


# =============================================================================================
# Decoración (spec §6.2): apoyada en la mitad de abajo, fondo transparente, se voltea
# =============================================================================================
def flower(cv, x, y, color):
    cv.set(x, y, WHITE)
    cv.set(x - 1, y, color)
    cv.set(x + 1, y, color)
    cv.set(x, y - 1, color)


def decor_bouquet(color):
    cv = Canvas(T, T)
    heads = [(5, 9), (9, 8), (12, 10), (7, 11), (10, 12)]
    for x, y in heads:
        line(cv, x, y + 1, 8 + (x > 8), 14, K_GRASS_SPECK)
    cv.set(5, 13, K_GRASS_SPECK)
    cv.set(11, 13, K_GRASS_SPECK)
    for x, y in heads:
        flower(cv, x, y, color)
    for x in range(6, 12):
        cv.set(x, 15, K_GRASS_SHADOW)
    return cv


def decor_tall(color):
    cv = Canvas(T, T)
    for x, top in ((4, 8), (8, 6), (12, 9)):
        for y in range(top + 1, 15):
            cv.set(x, y, K_GRASS_SPECK)
        cv.set(x + 1, top + 4, K_GRASS_SPECK)
        flower(cv, x, top, color)
        cv.set(x, 15, K_GRASS_SHADOW)
        cv.set(x - 1, 15, K_GRASS_SHADOW)
    return cv


def decor_carpet(color):
    cv = Canvas(T, T)
    spots = [(3, 8), (7, 7), (11, 8), (5, 11), (9, 10), (13, 11), (2, 13), (8, 13), (12, 14)]
    for i, (x, y) in enumerate(spots):
        cv.set(x, y, color)
        if i % 3 == 0:
            cv.set(x + 1, y, WHITE)
        cv.set(x, y + 1, K_GRASS_SHADOW)
    return cv


def decor_tuft(kind):
    cv = Canvas(T, T)
    if kind == 0:  # baja
        for x, y in ((5, 12), (10, 13)):
            for dx, dy in ((-2, -1), (-1, -2), (0, -2), (1, -2), (2, -1)):
                cv.set(x + dx, y + dy, K_GRASS_SPECK)
            for dx in (-1, 0, 1):
                cv.set(x + dx, y - 1, K_GRASS)
                cv.set(x + dx, y, K_GRASS_SHADOW)
    elif kind == 1:  # alta en V
        for x in (6, 10):
            for i in range(6):
                cv.set(x - 1 - i // 2, 14 - i, K_GRASS_SPECK if i > 1 else K_GRASS)
                cv.set(x + 1 + i // 2, 14 - i, K_GRASS_SPECK if i > 1 else K_GRASS)
            for i in range(7):
                cv.set(x, 14 - i, K_GRASS if i < 4 else K_GRASS_SPECK)
            cv.set(x - 1, 15, K_GRASS_SHADOW)
            cv.set(x, 15, K_GRASS_SHADOW)
            cv.set(x + 1, 15, K_GRASS_SHADOW)
    else:  # con espiga
        for x, top in ((5, 6), (8, 5), (11, 7)):
            for y in range(top + 3, 15):
                cv.set(x, y, K_GRASS)
            for y in range(top, top + 3):
                cv.set(x, y, K_GRASS_SPECK)
                cv.set(x + (1 if y % 2 else -1), y, K_GRASS_SPECK)
            cv.set(x, 15, K_GRASS_SHADOW)
        for dx in (-1, 0, 1):
            cv.set(8 + dx * 3, 14, K_GRASS_SPECK)
    return cv


def decor_fern(kind):
    cv = Canvas(T, T)
    if kind == 0:  # abierto, 6 frondas
        base = (8, 14)
        for ang, ln in ((-160, 6), (-130, 7), (-100, 7), (-80, 7), (-50, 7), (-20, 6)):
            a = math.radians(ang)
            for i in range(1, ln):
                x = base[0] + math.cos(a) * i
                y = base[1] + math.sin(a) * i * 0.8 + (i * i) * 0.06
                cv.set(round(x), round(y), K_LEAF_LIGHT if i > ln - 3 else K_LEAF_DARK)
                if i > 2 and i % 2 == 0:
                    cv.set(round(x), round(y) + 1, K_LEAF_DARK)
        for x in range(6, 11):
            cv.set(x, 15, K_GRASS_SHADOW)
    else:  # joven, enrollado
        for x, y0 in ((6, 9), (10, 10)):
            for y in range(y0 + 2, 15):
                cv.set(x, y, K_LEAF_DARK)
            for dx, dy in ((0, 0), (1, 0), (2, 1), (2, 2), (1, 2), (1, 1)):
                cv.set(x + dx - 1, y0 + dy, K_LEAF_LIGHT if dy == 0 else K_LEAF_DARK)
            cv.set(x - 1, y0 + 4, K_LEAF_DARK)
            cv.set(x + 1, y0 + 6, K_LEAF_DARK)
            cv.set(x, 15, K_GRASS_SHADOW)
    return cv


def decor_leaves(kind):
    cv = Canvas(T, T)
    if kind == 0:  # hojas sueltas
        for i, (x, y) in enumerate(((3, 9), (9, 8), (12, 11), (6, 12), (10, 14), (2, 14))):
            a, b = (K_LEAF_LIGHT, K_LEAF_DARK) if i % 2 else (K_LEAF_DARK, K_LEAF_SHADOW)
            cv.set(x, y, a)
            cv.set(x + 1, y, b)
    else:  # montoncito
        rows = ["..AB.B..", ".BABBAB.", "BBSBABSB", ".SBSSBS."]
        cmap = {"A": K_LEAF_LIGHT, "B": K_LEAF_DARK, "S": K_LEAF_SHADOW}
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch in cmap:
                    cv.set(4 + i, 11 + j, cmap[ch])
        for x in range(5, 11):
            cv.set(x, 15, K_GRASS_SHADOW)
    return cv


def mushroom(cv, x, y, big):
    """Seta: sombrero be4a2f con motas blancas, pie e8b796. (x, y) = arriba del sombrero."""
    if big:
        rows = [".RRR.", "RWRRR", "RRRWR", "DDDDD"]
        stem = [(1, 4), (2, 4), (3, 4), (1, 5), (2, 5), (3, 5)]
        ox = -2
    else:
        rows = ["RW.", "RRR"]
        rows = [".R.", "RWR", "DDD"]
        stem = [(1, 3)]
        ox = -1
    cmap = {"R": CLAY_D, "W": WHITE, "D": DIRT_D}
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch in cmap:
                cv.set(x + ox + i, y + j, cmap[ch])
    for i, j in stem:
        cv.set(x + ox + i, y + j, SKIN)
    by = y + max(j for _, j in stem) + 1
    for i, _ in stem:
        cv.set(x + ox + i, by, K_GRASS_SHADOW)


def decor_mushroom(kind):
    cv = Canvas(T, T)
    if kind == 0:
        mushroom(cv, 8, 8, True)
    else:
        for x, y in ((4, 10), (8, 9), (11, 11), (7, 12)):
            mushroom(cv, x, y, False)
    return cv


def decor_root(kind):
    cv = Canvas(T, T)
    if kind == 0:  # raíz que asoma
        pts = [(2, 14), (4, 12), (7, 11), (10, 12), (12, 14)]
        for a, b in zip(pts, pts[1:]):
            line(cv, a[0], a[1], b[0], b[1], K_TRUNK, 2)
        for x in range(4, 11):
            if cv.get(x, 13) is K_TRUNK:
                cv.set(x, 13, K_LEAF_SHADOW)
        for x in range(1, 14):
            if cv.get(x, 15) is None:
                cv.set(x, 15, K_GRASS_SHADOW)
    else:  # raíz en arco
        for i in range(19):
            t = i / 18
            x = 3 + t * 10
            y = 14 - math.sin(t * math.pi) * 4
            cv.set(round(x), round(y), K_TRUNK)
            cv.set(round(x), round(y) + 1, K_LEAF_SHADOW)
        for x in range(6, 11):
            cv.set(x, 14, K_GRASS_SHADOW)
        for x in (2, 3, 13, 14):
            cv.set(x, 15, K_GRASS_SHADOW)
    return cv


def build_decoracion():
    atlas = Canvas(256, 48)
    for i, fn in enumerate((decor_bouquet, decor_tall, decor_carpet)):
        for c in range(3):
            atlas.paste(fn(K_FLOWER[c]), (3 * i + c) * T, 0)
    for k in range(3):
        atlas.paste(decor_tuft(k), (9 + k) * T, 0)
    for k in range(2):
        atlas.paste(decor_fern(k), (12 + k) * T, 0)
        atlas.paste(decor_leaves(k), (14 + k) * T, 0)
        atlas.paste(decor_mushroom(k), k * T, T)
        atlas.paste(decor_root(k), (2 + k) * T, T)
    return atlas


def stone(cv, x, y, rx, ry):
    for yy in range(int(y - ry) - 1, int(y + ry) + 2):
        for xx in range(int(x - rx) - 1, int(x + rx) + 2):
            dx, dy = (xx + 0.5 - x) / rx, (yy + 0.5 - y) / ry
            if dx * dx + dy * dy <= 1:
                s = dx * 0.7 + dy
                cv.set(xx, yy, ROCK_L if s < -0.35 else (ROCK if s < 0.45 else ROCK_D))
    for xx in range(int(x - rx), int(x + rx) + 1):
        for yy in range(int(y + ry) + 1, int(y - ry) - 2, -1):
            if cv.get(xx, yy) in (ROCK_L, ROCK, ROCK_D):
                cv.set(xx, yy, ROCK_DD)
                cv.set(xx, yy + 1, K_GRASS_SHADOW)
                break


def build_piedras():
    atlas = Canvas(64, 16)
    trio = Canvas(T, T)
    for x, y, rx, ry in ((5, 10, 3, 2.2), (11, 11, 2.2, 1.8), (7, 13, 1.8, 1.3)):
        stone(trio, x, y, rx, ry)
    flat = Canvas(T, T)
    stone(flat, 8, 12, 5.5, 2.2)
    flat.set(6, 11, ROCK_DD)
    flat.set(7, 11, ROCK_DD)
    pebbles = Canvas(T, T)
    for x, y in ((3, 9), (8, 8), (12, 10), (5, 12), (10, 13), (2, 14)):
        pebbles.set(x, y, ROCK_L)
        pebbles.set(x + 1, y, ROCK)
        pebbles.set(x + 1, y + 1, ROCK_DD)
        pebbles.set(x, y + 1, ROCK_D)
    crack = Canvas(T, T)
    pts = [(1, 9), (4, 10), (6, 9), (9, 11), (12, 10), (14, 12)]
    for a, b in zip(pts, pts[1:]):
        line(crack, a[0], a[1], b[0], b[1], ROCK_DD)
    for a, b in (((6, 9), (7, 6)), ((9, 11), (10, 14)), ((4, 10), (3, 13))):
        line(crack, a[0], a[1], b[0], b[1], ROCK_D)
    for i, cv in enumerate((trio, flat, pebbles, crack)):
        atlas.paste(cv, i * T, 0)
    return atlas


# =============================================================================================
# Puente de 3 (spec §5)
# =============================================================================================
def bridge_block():
    """Bloque 48x48 norte-sur: columnas izq./medio/der. x filas cabeza norte, tramo, cabeza sur."""
    W = 3 * T
    cv = Canvas(W, W)
    for y in range(W):
        k = y % 4
        for x in range(W):
            if k == 3:
                c = DIRT_D
            else:
                plank = (y // 4 + x // 12) % 2
                c = DIRT_L if plank == 0 else DIRT
                if k == 1 and h(90, x // 3, y // 4) % 5 == 0:
                    c = DIRT if c == DIRT_L else DIRT_L  # veta
            cv.set(x, y, c)
    # Cabezas: viga de apoyo que casa con la orilla.
    for x in range(W):
        cv.set(x, 0, DIRT_DD)
        cv.set(x, 1, DIRT_D)
        cv.set(x, W - 2, DIRT_D)
        cv.set(x, W - 1, DIRT_DD)
    # Costados: agua en sombra y pretil con postes cada 8 px.
    for left in (True, False):
        for y in range(W):
            for xx in range(4):
                x = xx if left else W - 1 - xx
                if xx < 2:
                    c = WATER_DD if y not in (0, 1, W - 2, W - 1) else DIRT_DD
                else:
                    c = DIRT_DD
                cv.set(x, y, c)
            if y % 8 in (3, 4) and 2 < y < W - 3:
                cv.set(1 if left else W - 2, y, DIRT_DD)
                cv.set(2 if left else W - 3, y, DIRT_D if y % 8 == 3 else DIRT_DD)
        if left:
            for y in range(2, W - 2):
                if y % 5 == 2:
                    cv.set(0, y, WATER_D)
    return cv


def build_puente():
    atlas = Canvas(96, 48)
    ns = bridge_block()
    atlas.paste(ns, 0, 0)
    atlas.paste(ns.rot_ccw(), 3 * T, 0)  # este-oeste girado en M13; dibujado aparte en M18
    return atlas


# =============================================================================================
# Árboles (spec §4)
# =============================================================================================
class Box:
    """Coordenadas normalizadas de un árbol de 32x32 escaladas al lienzo."""

    def __init__(self, w, hgt, sx=None, sy=None):
        self.w, self.h = w, hgt
        self.sx = sx if sx is not None else w / 32.0
        self.sy = sy if sy is not None else hgt / 32.0

    def X(self, x):
        return x * self.sx

    def Y(self, y):
        return y * self.sy


def crown(cv, box, clumps, seed, spread=1.0):
    """Copa de grumos: cada píxel toma la luz del grumo de delante (el más bajo). Luz casi cenital:
    brillo arriba, sombra abajo y solo 1-2 px más oscuros a la derecha."""
    cxs = [c[0] for c in clumps]
    mid = sum(cxs) / len(cxs)
    pts = [(box.X(mid + (cx - mid) * spread), box.Y(cy), r * box.sx * (spread ** 0.5), r * box.sy)
           for cx, cy, r in clumps]
    for y in range(cv.h):
        for x in range(cv.w):
            best = None
            for i, (cx, cy, rx, ry) in enumerate(pts):
                d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
                if d <= 1 and (best is None or cy > best[0]):
                    best = (cy, i, cx, rx, ry, d)
            if best is None:
                continue
            cy, i, cx, rx, ry, d = best
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            lum = -(0.3 * dx + 0.95 * dy) + ((h(seed, i) % 100) / 100.0 - 0.5) * 0.3
            if lum > 0.42:
                c = K_LEAF_LIGHT
            elif lum < -0.5 or (dx > 0.8 and d > 0.82):
                c = K_LEAF_SHADOW
            else:
                c = K_LEAF_DARK
            cv.set(x, y, c)


def trunk(cv, box, x0, x1, y0, y1, roots=1):
    X0, X1 = round(box.X(x0)), round(box.X(x1))
    Y0, Y1 = round(box.Y(y0)), round(box.Y(y1))
    for y in range(Y0, Y1):
        for x in range(X0, X1):
            cv.set(x, y, K_TRUNK)
        cv.set(X1 - 1, y, K_LEAF_SHADOW)
        if X1 - X0 > 4:
            cv.set(X1 - 2, y, K_LEAF_SHADOW)
    for k in range(roots):
        cv.set(X0 - 1 - k, Y1 - 1, K_TRUNK)
        cv.set(X1 + k, Y1 - 1, K_LEAF_SHADOW if k == roots - 1 else K_TRUNK)
    return X0, X1, Y0, Y1


ROUND = [
    [(16, 8, 7.5), (9, 12, 6), (23, 12, 6), (11, 17, 6), (21, 17, 6), (16, 15, 7)],
    [(13, 8, 7), (22, 10, 6), (8, 14, 5.5), (24, 16, 5), (13, 17, 6.5), (19, 17, 6)],
    [(16, 6, 6.5), (10, 11, 6), (22, 10, 6.5), (16, 13, 7), (9, 17, 5), (23, 17, 5), (16, 18, 6)],
    [(17, 9, 8), (9, 13, 6.5), (24, 14, 5.5), (14, 18, 6.5), (21, 18, 5)],
]
THORNY = [
    [(16, 10, 7), (10, 14, 5.5), (22, 14, 5.5), (16, 17, 5.5)],
    [(14, 10, 6.5), (21, 11, 5.5), (10, 16, 5), (19, 17, 5.5)],
    [(16, 9, 6), (9, 13, 5), (23, 13, 5), (13, 17, 5), (20, 17, 5)],
    [(15, 11, 7.5), (23, 12, 5), (11, 17, 5), (20, 18, 5)],
]
WILLOW = [
    [(16, 9, 9), (8, 12, 6), (24, 12, 6)],
    [(14, 9, 8.5), (23, 10, 7), (7, 13, 5)],
    [(16, 8, 8), (9, 11, 6.5), (24, 13, 6), (16, 13, 6)],
    [(17, 10, 9.5), (7, 13, 5.5), (26, 13, 4.5)],
]
CONIFER = [
    [(1, 8, 4), (4, 12, 7), (8, 17, 10), (12, 22, 12)],
    [(2, 8, 3.5), (5, 13, 6.5), (9, 18, 9), (13, 23, 11)],
    [(0, 7, 4), (3, 11, 7), (6, 15, 9), (10, 19, 11), (14, 23, 13)],
    [(2, 9, 5), (6, 14, 8), (11, 22, 12)],
]
PALM = [
    (-172, -140, -108, -74, -42, -8, 150, 30),
    (-165, -130, -98, -66, -30, 0, 160),
    (-178, -146, -115, -82, -50, -18, 140, 40),
    (-170, -135, -100, -62, -25, 165, 15),
]
CACTUS = [
    [("L", 6, 10, 16), ("R", 25, 7, 13)],
    [("L", 7, 8, 18)],
    [("R", 24, 9, 15), ("L", 7, 13, 18)],
    [("L", 5, 6, 14), ("R", 26, 11, 17)],
]
TRUNK_DY = [0, 2, -1, 1]  # altura del tronco por variante (±2 px)


def face_hint(cv, x, y):
    """Dos huecos y un nudo que casi son una cara (variante 3, spec §4). Sutil a 1x."""
    for dx in (0, 4):
        cv.set(x + dx, y, OUTLINE)
        cv.set(x + dx + 1, y, K_LEAF_SHADOW)
    cv.set(x + 2, y + 3, K_LEAF_SHADOW)
    cv.set(x + 3, y + 3, OUTLINE)


def tree_body(shape, variant, box, seed, kind="normal"):
    """Tronco y copa (sin contorno ni sombra en el suelo). kind: normal, young, big, nujio."""
    cv = Canvas(box.w, box.h)
    v = variant % 4
    dy = TRUNK_DY[v] if kind in ("normal", "big") else 0
    thin = kind == "young"
    spread = 1.18 if kind == "big" else 1.0
    if shape in ("round", "thorny", "willow"):
        layout = {"round": ROUND, "thorny": THORNY, "willow": WILLOW}[shape][v]
        tw = 2 if thin else 3
        tx0, tx1 = 16 - tw / 2 - (0 if thin else 0.5), 16 + tw / 2 + (0 if thin else 1.5)
        if kind in ("big", "nujio"):
            tx0, tx1 = 12.5, 19.5
        trunk(cv, box, tx0, tx1, 18 + dy, 29, roots=1 if kind in ("normal", "young") else 0)
        crown(cv, box, layout, seed + v, spread)
        if shape == "willow":
            # Cortinas colgantes hasta la fila 26: tiras de 2 px con 1 px de hueco.
            x0, x1 = round(box.X(5 - 2 * (spread - 1) * 10)), round(box.X(27 + 2 * (spread - 1) * 10))
            top = round(box.Y(13))
            for x in range(x0, x1):
                if x % 3 == 2:
                    continue
                ln = round(box.Y(8 + h(seed, v, x // 3) % 6))
                for y in range(top, min(top + ln, round(box.Y(26)))):
                    if cv.get(x, y) not in LEAF or y > box.Y(17):
                        cv.set(x, y, K_LEAF_DARK if (x // 3 + y // 4) % 3 else K_LEAF_SHADOW)
                cv.set(x, min(top + ln, round(box.Y(26))) - 1, K_LEAF_SHADOW)
    elif shape == "conifer":
        tiers = CONIFER[v]
        trunk(cv, box, 15 - (1 if kind in ("big", "nujio") else 0), 18 + (1 if kind in ("big", "nujio") else 0),
              21 + dy, 29, roots=0)
        cxn = box.X(16)
        for ti, (ya, yb, hw) in enumerate(tiers):
            hw = hw * spread
            for y in range(round(box.Y(ya)), round(box.Y(yb))):
                t = (y - box.Y(ya)) / max(1, box.Y(yb) - box.Y(ya))
                half = box.sx * hw * (0.25 + 0.75 * t)
                for x in range(cv.w):
                    ddx = x + 0.5 - cxn
                    if abs(ddx) > half:
                        continue
                    # Borde de abajo dentado (puntas de las ramas).
                    if y >= round(box.Y(yb)) - 1 and (x // max(1, round(box.sx * 2))) % 2:
                        continue
                    side = ddx / max(half, 1)
                    lum = -side * 0.3 - (t - 0.35) * 1.6
                    c = K_LEAF_LIGHT if lum > 0.3 else (K_LEAF_SHADOW if lum < -0.75 or side > 0.82 else K_LEAF_DARK)
                    cv.set(x, y, c)
    elif shape == "palm":
        angles = PALM[v]
        cx, cy = 16 + (v - 1.5) * 0.8, 9 + (0 if kind == "normal" else 0)
        bend = (1 if v % 2 == 0 else -1) * (2.5 if not thin else 1.5)
        tw = 1.2 if thin else (2 if kind == "normal" else 3)
        for y in range(round(box.Y(cy)), round(box.Y(29))):
            t = (y - box.Y(cy)) / (box.Y(29) - box.Y(cy))
            xc = box.X(cx + math.sin((1 - t) * 2.0) * bend - bend * math.sin(2.0) * (1 - t) * 0 + (16 - cx) * t)
            for x in range(round(xc - box.sx * tw), round(xc + box.sx * tw) + 1):
                ring = (y // max(2, round(box.sy * 3))) % 2 == 1 and (y % max(2, round(box.sy * 3)) == 0)
                right = x >= round(xc + box.sx * tw) - (1 if box.sx > 1.2 else 0)
                cv.set(x, y, K_LEAF_SHADOW if ring or right else K_TRUNK)
        ln = 12.5
        for ang in angles:
            a = math.radians(ang)
            steps = round(ln * max(box.sx, box.sy) * 1.5)
            droop = 2.5 + 5.0 * abs(math.cos(a))
            for i in range(steps):
                t = i / steps
                px_ = box.X(cx) + math.cos(a) * t * box.sx * ln
                py_ = box.Y(cy) + math.sin(a) * t * box.sy * ln * 0.7 + (t * t) * droop * box.sy
                wdt = max(0.5, (1.5 - 1.1 * t) * box.sy)
                for k in range(-round(wdt), round(wdt) + 1):
                    c = K_LEAF_LIGHT if k < 0 else (K_LEAF_DARK if k == 0 or t > 0.75 else K_LEAF_SHADOW)
                    if cv.get(px_, py_ + k) not in LEAF or k <= 0:
                        cv.set(px_, py_ + k, c)
        ellipse(cv, box.X(cx), box.Y(cy) + box.sy, box.sx * 2.5, box.sy * 2, K_LEAF_DARK, only_empty=False)
        ellipse(cv, box.X(cx) + box.sx * 0.6, box.Y(cy) + box.sy * 2, box.sx * 1.6, box.sy * 1, K_LEAF_SHADOW,
                only_empty=False)
    elif shape == "cactus":
        arms = CACTUS[v]

        def col(x0, x1, y0, y1):
            X0, X1 = round(box.X(x0)), round(box.X(x1))
            for y in range(round(box.Y(y0)), round(box.Y(y1))):
                for x in range(X0, X1):
                    rx = (x - X0) / max(1, X1 - X0)
                    top = y < round(box.Y(y0)) + max(1, round(box.sy * 2))
                    c = K_LEAF_LIGHT if rx < 0.3 or (top and rx < 0.7) else K_LEAF_DARK
                    if x >= X1 - max(1, round(box.sx)):
                        c = K_LEAF_SHADOW
                    if c == K_LEAF_DARK and (x - X0) % 3 == 2 and X1 - X0 > 5:
                        c = K_LEAF_SHADOW  # costillas
                    cv.set(x, y, c)
            cv.set(X0, round(box.Y(y0)), None)
            cv.set(X1 - 1, round(box.Y(y0)), None)

        w0, w1 = (13, 19) if not thin else (13.5, 18.5)
        if kind in ("big", "nujio"):
            w0, w1 = 12, 20
        for side, ax, ay0, ay1 in arms:
            aw = 4 if not thin else 3
            if side == "L":
                col(ax, ax + aw, ay0, ay1)
                col(ax, w0 + 1, ay1 - 3, ay1)
            else:
                col(ax - aw, ax, ay0, ay1)
                col(w1 - 1, ax, ay1 - 3, ay1)
        col(w0, w1, 3 + dy * 0.5, 29)
        # Flor de color tronco en la punta.
        fx, fy = round(box.X(16)), round(box.Y(3 + dy * 0.5))
        for ddx, ddy in ((-1, 0), (0, -1), (1, 0), (0, 0)):
            cv.set(fx + ddx, fy + ddy, K_TRUNK)
    if shape in ("round", "thorny", "willow", "conifer"):
        pass
    clean_singletons(cv, set(LEAF))
    return cv


def thorns(cv, seed):
    """Púas de 1-2 px en el contorno (espinoso): se pintan después del contorno, en contorno."""
    pts = []
    for y in range(cv.h):
        for x in range(cv.w):
            if cv.px[y][x] == OUTLINE and h(seed, x, y) % 3 == 0:
                for dx, dy in ((0, -1), (-1, 0), (1, 0)):
                    if cv.get(x + dx, y + dy) is None and cv.get(x - dx, y - dy) in LEAF:
                        pts.append((x + dx, y + dy, dx, dy))
                        break
    for x, y, dx, dy in pts:
        if y < cv.h * 0.75:
            cv.set(x, y, OUTLINE)
            if h(seed, 3, x, y) % 2 and cv.get(x + dx, y + dy) is None:
                cv.set(x + dx, y + dy, OUTLINE)


def finish(cv, box, shape, seed, shadow=True):
    """Contorno, púas del espinoso y sombra elíptica en el suelo (clave de sombra de hierba)."""
    cv.outline()
    if shape == "thorny":
        thorns(cv, seed)
    if shadow:
        ground = Canvas(cv.w, cv.h)
        rx = {"round": 11, "conifer": 9, "palm": 8, "cactus": 8, "thorny": 10, "willow": 12}[shape]
        ellipse(ground, box.X(16), box.Y(29), box.sx * rx, max(1.6, box.sy * 2.4), K_GRASS_SHADOW)
        cv.under(ground)
    return cv


def tree(shape, variant, box=None, kind="normal"):
    box = box or Box(32, 32)
    seed = 100 + SHAPES.index(shape) * 10 + variant
    cv = tree_body(shape, variant, box, seed, kind)
    if variant == 3 and kind == "normal":
        if shape == "palm":
            face_hint(cv, 13, 20)
        elif shape == "cactus":
            face_hint(cv, 13, 12)
        elif shape == "conifer":
            face_hint(cv, 12, 16)
        else:
            face_hint(cv, 12, 13)
    return finish(cv, box, shape, seed)


def fruit_spots(cv, shape, box, seed, count=5):
    """Sitios de fruto de 2x2 con rabillo encima, siempre sobre hoja (palmera: bajo las hojas,
    también sobre el tronco; cactus: en los brazos), separados al menos 4 px."""
    allowed = set(LEAF) | ({K_TRUNK} if shape == "palm" else set())
    cand = []
    for y in range(2, cv.h - 4):
        for x in range(1, cv.w - 2):
            cells = [(x, y - 1), (x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
            if all(cv.get(a, b) in allowed for a, b in cells):
                # que no toque el borde de la copa (se vería pegado al contorno)
                if shape == "cactus" or all(cv.get(a, b) is not None
                                            for a, b in ((x - 1, y), (x + 2, y), (x, y + 2), (x + 1, y + 2))):
                    cand.append((x, y))
    if shape == "palm":
        cy = box.Y(9)
        cand = [p for p in cand if cy - 2 <= p[1] <= cy + 6 and abs(p[0] - box.X(16)) < 9]
    elif shape == "cactus":
        cand.sort(key=lambda p: (abs(p[0] + 1 - box.X(16)) <= 3.5 * box.sx, h(seed, p[0], p[1])))  # brazos antes
    else:
        cand = [p for p in cand if p[1] < box.Y(21)]
    if shape != "cactus":
        cand.sort(key=lambda p: h(seed, p[0], p[1]))
    out = []
    for p in cand:
        if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) >= 5 and max(abs(p[0] - q[0]), abs(p[1] - q[1])) >= 4 for q in out):
            out.append(p)
        if len(out) == count:
            break
    return out


def fruit_tree(shape, variant, ripe):
    box = Box(32, 32)
    seed = 100 + SHAPES.index(shape) * 10 + variant
    cv = tree_body(shape, variant, box, seed)
    spots = fruit_spots(cv, shape, box, seed + 7, 5 if shape != "palm" else 4)
    if len(spots) < 4:
        raise SystemExit("frutal %s %d: solo %d sitios de fruto sobre hoja" % (shape, variant, len(spots)))
    for x, y in spots:
        cv.set(x, y - 1, K_TRUNK)
        if ripe:
            cv.set(x, y, K_FRUIT)
            cv.set(x + 1, y, K_FRUIT)
            cv.set(x, y + 1, K_FRUIT)
            cv.set(x + 1, y + 1, K_FRUIT_SHADOW)
    return finish(cv, box, shape, seed)


def hollow_tree(shape):
    """Árbol hueco (refugio): tronco ancho con una boca en arco de 8x9 en la base."""
    box = Box(32, 32)
    seed = 100 + SHAPES.index(shape) * 10 + 5
    cv = tree_body(shape, 0, box, seed)
    if shape == "cactus":
        for y in range(14, 29):
            for x in range(10, 22):
                c = K_LEAF_LIGHT if x < 13 else (K_LEAF_SHADOW if x > 19 or (x % 3 == 2) else K_LEAF_DARK)
                cv.set(x, y, c)
        cv.set(10, 14, None)
        cv.set(21, 14, None)
    else:
        for y in range(18, 29):
            w = 6 + (y - 18) // 4
            for x in range(16 - w, 16 + w):
                cv.set(x, y, K_TRUNK if x < 16 + w - 2 else K_LEAF_SHADOW)
        for k in (1, 2):
            cv.set(16 - 7 - k, 28, K_TRUNK)
            cv.set(16 + 6 + k, 28, K_LEAF_SHADOW)
    # Boca: 8 de ancho, 9 de alto (filas 20-28), en arco.
    for y in range(20, 29):
        for x in range(12, 20):
            if y == 20 and x in (12, 13, 18, 19) or y == 21 and x in (12, 19):
                continue
            cv.set(x, y, OUTLINE if (y < 22 or x in (12, 19)) else DIRT_DD)
    return finish(cv, box, shape, seed)


def dead_tree(shape):
    """Árbol seco: ramas desnudas en tronco y sombra de hoja, sin hoja clara."""
    box = Box(32, 32)
    cv = Canvas(32, 32)
    seed = 100 + SHAPES.index(shape) * 10 + 9
    Tk, S = K_TRUNK, K_LEAF_SHADOW

    def branch(pts, w=1):
        for a, b in zip(pts, pts[1:]):
            line(cv, a[0], a[1], b[0], b[1], Tk, w)

    if shape == "conifer":
        cv.rect(15, 3, 17, 29, Tk)
        for y in range(29):
            cv.set(16, y, S if y > 2 else Tk)
        for i, y in enumerate(range(6, 23, 4)):
            ln = 2 + i
            line(cv, 14, y, 14 - ln, y + 2, Tk)
            line(cv, 17, y + 1, 17 + ln, y + 3, Tk)
    elif shape == "palm":
        for y in range(9, 29):
            t = (y - 9) / 20
            xc = 16 + math.sin((1 - t) * 2) * 2.5
            for x in range(round(xc - 1), round(xc + 2)):
                cv.set(x, y, S if x == round(xc + 1) or y % 3 == 0 else Tk)
        for ang in (-150, -110, -40, 200, 160):
            a = math.radians(ang)
            pts = [(17 + math.cos(a) * i, 9 + math.sin(a) * i * 0.4 + i * i * 0.07) for i in range(0, 11, 2)]
            branch(pts)
            for x, y in pts[2:]:
                cv.set(x, y + 1, S)
    elif shape == "cactus":
        cv.rect(13, 6, 19, 29, Tk)
        for y in range(6, 29):
            cv.set(18, y, S)
            if y % 2:
                cv.set(15, y, S)
        cv.rect(7, 12, 11, 20, Tk)
        cv.rect(7, 17, 14, 20, Tk)
        for y in range(12, 20):
            cv.set(10, y, S)
        cv.rect(21, 15, 24, 21, Tk)
        cv.rect(18, 19, 24, 21, Tk)
        cv.set(13, 6, None)
        cv.set(14, 5, Tk)
        cv.set(18, 6, None)
    else:
        cv.rect(15, 15, 18, 29, Tk)
        for y in range(15, 29):
            cv.set(17, y, S)
        cv.set(14, 28, Tk)
        cv.set(18, 28, S)
        branch([(16, 16), (12, 11), (8, 6)], 2)
        branch([(12, 11), (10, 12)])
        branch([(16, 15), (19, 10), (24, 6)], 2)
        branch([(19, 10), (22, 11), (26, 10)])
        branch([(16, 15), (16, 8), (15, 3)])
        branch([(8, 6), (6, 5)])
        branch([(24, 6), (25, 3)])
        if shape == "willow":
            for x0, y0 in ((7, 6), (11, 11), (24, 6), (26, 10), (21, 11)):
                for y in range(y0 + 1, y0 + 8 + h(seed, x0) % 4):
                    cv.set(x0, y, S)
    clean_singletons(cv, {Tk})
    finish(cv, box, shape, seed)
    if shape == "thorny":
        pass  # las púas ya las pone finish()
    return cv


# --- Árbol joven, grande y Nujio -------------------------------------------------------------
def young_tree(shape, variant):
    box = Box(16, 16)
    seed = 300 + SHAPES.index(shape) * 10 + variant
    cv = tree_body(shape, variant * 2, box, seed, "young")
    return finish(cv, box, shape, seed)


def big_tree(shape):
    """Árbol grande 3x3: copa más ancha que alta, raíces hasta el borde de la huella y musgo."""
    box = Box(48, 48, 1.5, 1.42)
    seed = 400 + SHAPES.index(shape) * 10
    cv = tree_body(shape, 2 if shape != "round" else 0, box, seed, "big")
    roots(cv, 48, 48, 18, 30, 44)
    moss(cv, seed, 3)
    return finish(cv, box, shape, seed)


def roots(cv, w, hgt, x0, x1, y_base):
    """Raíces que salen del tronco (x0..x1) hasta los bordes del sprite, a la altura y_base."""
    if cv.get((x0 + x1) // 2, y_base - 2) not in (K_TRUNK, K_LEAF_SHADOW):
        return
    for side in (-1, 1):
        sx = x0 if side < 0 else x1 - 1
        ex = 1 if side < 0 else w - 2
        line(cv, sx, y_base - 3, (sx + ex) / 2, y_base, K_TRUNK, 2)
        line(cv, (sx + ex) / 2, y_base, ex, y_base + 1, K_TRUNK)
        line(cv, sx, y_base - 1, sx + side * 4, y_base + 1, K_LEAF_SHADOW)


def moss(cv, seed, n):
    trunk_px = [(x, y) for y in range(cv.h) for x in range(cv.w) if cv.px[y][x] == K_TRUNK]
    trunk_px.sort(key=lambda p: h(seed, p[0], p[1]))
    done = 0
    for x, y in trunk_px:
        if cv.get(x + 1, y) == K_TRUNK and cv.get(x, y + 1) == K_TRUNK:
            cv.set(x, y, K_LEAF_SHADOW)
            cv.set(x + 1, y, K_LEAF_SHADOW)
            cv.set(x, y + 1, K_LEAF_DARK)
            done += 1
            if done == n:
                break


def nujio(shape, frame):
    """Nujio 64x80 (huella 4x4, copa que sobresale 16 px). Fotograma 1: las motas de Luz cambian
    de sitio en la copa; nada más se mueve."""
    box = Box(64, 80, 2.0, 2.5)
    seed = 500 + SHAPES.index(shape) * 10
    cv = tree_body(shape, 0 if shape != "conifer" else 2, box, seed, "nujio")
    # Tronco ancho y raíces hasta el borde de la huella.
    for y in range(round(box.Y(20)), 74):
        w = 7 + max(0, y - 64) // 2
        for x in range(32 - w, 32 + w):
            if cv.get(x, y) is None or y > box.Y(24):
                cv.set(x, y, K_TRUNK if x < 32 + w - 3 else K_LEAF_SHADOW)
    for side in (-1, 1):
        for k, (ex, ey) in enumerate(((2 if side < 0 else 61, 76), (10 if side < 0 else 53, 78))):
            sx = 32 + side * 6
            line(cv, sx, 68, ex, ey, K_TRUNK, 2)
            line(cv, sx, 70, ex, ey + 1, K_LEAF_SHADOW)
    moss(cv, seed, 3)
    clean_singletons(cv, set(LEAF) | {K_TRUNK})
    cv.outline()
    if shape == "thorny":
        thorns(cv, seed)
    ground = Canvas(64, 80)
    ellipse(ground, 32, 77, 30, 2.6, K_GRASS_SHADOW)
    cv.under(ground)
    # Motas de Luz (acento místico) en la copa.
    leaf = [(x, y) for y in range(2, 56) for x in range(2, 62) if cv.px[y][x] in LEAF
            and all(cv.get(x + dx, y + dy) in LEAF for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    leaf.sort(key=lambda p: h(seed, frame, p[0], p[1]))
    motes = []
    for p in leaf:
        if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) > 10 for q in motes):
            motes.append(p)
        if len(motes) == 4:
            break
    for i, (x, y) in enumerate(motes):
        cv.set(x, y, WHITE if i % 2 == 0 else WATER_L)
        if i % 2 == 0:
            cv.set(x + 1, y, WATER_L)
    return cv


def build_trees():
    sheets = {}
    arb = Canvas(320, 192)
    for r, shape in enumerate(SHAPES):
        for v in range(4):
            arb.paste(tree(shape, v), v * 32, r * 32)
        for v in range(2):
            arb.paste(fruit_tree(shape, v, True), (4 + v) * 32, r * 32)
            arb.paste(fruit_tree(shape, v, False), (6 + v) * 32, r * 32)
        arb.paste(hollow_tree(shape), 8 * 32, r * 32)
        arb.paste(dead_tree(shape), 9 * 32, r * 32)
    sheets["sprite_arboles.png"] = arb
    young = Canvas(32, 96)
    big = Canvas(48, 288)
    nuj = Canvas(128, 480)
    for r, shape in enumerate(SHAPES):
        for v in range(2):
            young.paste(young_tree(shape, v), v * 16, r * 16)
        big.paste(big_tree(shape), 0, r * 48)
        for f in range(2):
            nuj.paste(nujio(shape, f), f * 64, r * 80)
    sheets["sprite_arbol_joven.png"] = young
    sheets["sprite_arbol_grande.png"] = big
    sheets["sprite_nujio.png"] = nuj
    return sheets


# =============================================================================================
# Rocas, madera y casas (spec §5)
# =============================================================================================
ROCK_LOBES = [
    [(16, 17, 12), (9, 21, 7), (23, 20, 8)],
    [(14, 18, 11), (22, 15, 8), (24, 22, 6)],
    [(11, 19, 9), (21, 17, 10)],
]


def boulder(variant, size=32):
    s = size / 32.0
    cv = Canvas(size, size)
    lobes = ROCK_LOBES[variant] if size == 32 else [[(16, 18, 11), (24, 21, 6)], [(14, 18, 10), (21, 20, 8)]][variant]
    seed = 40 + variant + size
    for y in range(size):
        for x in range(size):
            best = None
            for i, (cx, cy, r) in enumerate(lobes):
                dx, dy = (x + 0.5 - cx * s) / (r * s), (y + 0.5 - cy * s) / (r * s * 0.8)
                d = math.hypot(dx, dy)
                if d <= 1 and (best is None or cy > best[0]):
                    best = (cy, i, dx, dy)
            if best is None:
                continue
            _, i, dx, dy = best
            lum = -(dx * 0.7 + dy * 0.9) + ((h(seed, i, x // 3, y // 3) % 100) / 100 - 0.5) * 0.25
            c = ROCK_L if lum > 0.45 else (ROCK if lum > -0.15 else (ROCK_D if lum > -0.75 else ROCK_DD))
            cv.set(x, y, c)
    # Junta entre bloques (contorno interior) y grietas.
    for y in range(size):
        for x in range(size):
            if cv.px[y][x] is None:
                continue
            own = None
            for i, (cx, cy, r) in enumerate(lobes):
                dx, dy = (x + 0.5 - cx * s) / (r * s), (y + 0.5 - cy * s) / (r * s * 0.8)
                if math.hypot(dx, dy) <= 1 and (own is None or cy > lobes[own][1]):
                    own = i
            up = None
            if y > 0:
                for i, (cx, cy, r) in enumerate(lobes):
                    dx, dy = (x + 0.5 - cx * s) / (r * s), (y - 0.5 - cy * s) / (r * s * 0.8)
                    if math.hypot(dx, dy) <= 1 and (up is None or cy > lobes[up][1]):
                        up = i
            if up is not None and own != up:
                cv.set(x, y - 1, ROCK_DD)
    for k in range(2):
        v = h(seed, k)
        x, y = round((10 + v % 12) * s), round((13 + (v >> 8) % 5) * s)
        for i in range(round(5 * s)):
            if cv.get(x, y) in (ROCK_L, ROCK, ROCK_D):
                cv.set(x, y, ROCK_DD)
            x += 1 if h(seed, k, i) % 2 else 0
            y += 1
    # Musgo (claves de hierba) arriba, en grumos de 2 px.
    for y in range(size):
        for x in range(size - 1):
            if cv.get(x, y) == ROCK_L and cv.get(x, y - 1) is None and h(seed, 5, x // 2) % 3 == 0:
                cv.set(x, y, K_GRASS_SPECK)
                if cv.get(x + 1, y) is not None:
                    cv.set(x + 1, y, K_GRASS)
    clean_singletons(cv, {ROCK_L, ROCK, ROCK_D, ROCK_DD})
    cv.outline()
    ground = Canvas(size, size)
    ellipse(ground, size * 0.52, size * 0.9, size * 0.42, max(1.5, size * 0.09), K_GRASS_SHADOW)
    cv.under(ground)
    return cv


def stump(variant):
    cv = Canvas(T, T)
    x0, x1 = (4, 12) if variant == 0 else (3, 13)
    top_h = 3
    for y in range(7, 14):
        for x in range(x0, x1):
            cv.set(x, y, K_LEAF_SHADOW if x >= x1 - 2 else K_TRUNK)
    for x in range(x0, x1, 3):
        cv.set(x + 1, 9 + (x % 2), K_LEAF_SHADOW)
    # Corte con 2 anillos.
    cx, cy, rx, ry = (x0 + x1) / 2, 7, (x1 - x0) / 2, top_h - 0.5
    for y in range(4, 10):
        for x in range(x0, x1):
            d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            if d <= 1:
                cv.set(x, y, DIRT_L if d < 0.35 or 0.65 <= d < 0.85 else DIRT)
    # Raíces cortas y musgo.
    cv.set(x0 - 1, 13, K_TRUNK)
    cv.set(x0 - 2, 13, K_TRUNK)
    cv.set(x1, 13, K_LEAF_SHADOW)
    if variant == 1:
        cv.set(x1 + 1, 13, K_LEAF_SHADOW)
    for x in range(x0, x0 + 3):
        cv.set(x, 8, K_LEAF_DARK)
    cv.set(x0, 9, K_LEAF_DARK)
    cv.outline()
    for x in range(1, 15):
        if cv.get(x, 15) is None and (cv.get(x, 14) is not None or cv.get(x - 1, 14) is not None):
            cv.set(x, 15, K_GRASS_SHADOW)
    return cv


def log(variant):
    cv = Canvas(32, 16)
    x0, x1 = (2, 26) if variant == 0 else (4, 27)
    y0, y1 = 7, 13
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = K_TRUNK
            if y >= y1 - 2:
                c = K_LEAF_SHADOW
            elif (x + (y % 2) * 2) % 5 == 0 and y > y0:
                c = K_LEAF_SHADOW
            cv.set(x, y, c)
    # Cara del corte (derecha) con 2 anillos.
    cx, cy = x1, (y0 + y1) / 2
    for y in range(y0, y1):
        for x in range(x1 - 2, x1 + 3):
            d = math.hypot((x + 0.5 - cx) / 2.6, (y + 0.5 - cy) / 3.0)
            if d <= 1:
                cv.set(x, y, DIRT_L if d < 0.4 or 0.7 <= d < 0.9 else DIRT)
    # Musgo encima.
    for x in range(x0 + 2, x1 - 3):
        if h(70, variant, x // 3) % 3 == 0:
            cv.set(x, y0, K_LEAF_DARK)
            cv.set(x, y0 - 1, K_LEAF_SHADOW if x % 2 else K_LEAF_DARK)
    if variant == 1:  # muñón de rama
        cv.rect(10, 4, 12, 7, K_TRUNK)
        cv.set(11, 4, K_LEAF_SHADOW)
    cv.outline()
    for x in range(x0, x1 + 3):
        if cv.get(x, y1 + 1) is None:
            cv.set(x, y1 + 1, K_GRASS_SHADOW)
    return cv


def build_rocks_wood():
    rocks = Canvas(96, 32)
    for v in range(3):
        rocks.paste(boulder(v), v * 32, 0)
    small = Canvas(32, 16)
    for v in range(2):
        small.paste(boulder(v, 16), v * 16, 0)
    wood = Canvas(96, 16)
    for v in range(2):
        wood.paste(stump(v), v * 16, 0)
        wood.paste(log(v), 32 + v * 32, 0)
    return {"sprite_rocas.png": rocks, "sprite_rocas_pequenas.png": small, "sprite_madera.png": wood}


HOUSE_MATERIALS = {
    # techo claro, techo oscuro, juntas del techo, muro claro, muro oscuro
    0: (CLAY, DIRT, DIRT_D, SKIN, EARTH),           # barro y cañizo
    1: (ROCK_D, ROCK_DD, ROCK_DD, ROCK_L, ROCK),    # piedra y pizarra
}


def house(material, variant):
    """Casa 4x3 en 3/4: techo de 29 px arriba y fachada de 19 px al sur. Sin puerta: vano en arco."""
    W, H = 64, 48
    cv = Canvas(W, H)
    rl, rd, rj, wl, wd = HOUSE_MATERIALS[material]
    roof_h = 29
    # Techo: cumbrera arriba, filas de cañizo o pizarra, alero de 1 px que sobresale.
    for y in range(1, roof_h):
        inset = max(0, 3 - y) if y < 3 else 0
        for x in range(inset, W - inset):
            row = (y - 3) // 4
            c = rl
            if y < 3:
                c = rd  # cumbrera
            elif (y - 3) % 4 == 3:
                c = rj
            elif material == 0:
                if (x + row * 2) % 3 == 0:
                    c = rd  # cañizo: trazos verticales
            else:
                if (x + (row % 2) * 3) % 6 == 0:
                    c = rj  # juntas de las pizarras
                elif (y - 3) % 4 == 0:
                    c = ROCK  # canto de la fila de pizarras, al sol
            if x > W - 6 and y >= 3 and c == rl:
                c = rd  # el lado derecho del techo en sombra
            cv.set(x, y, c)
    # Muro.
    for y in range(roof_h, H - 1):
        for x in range(2, W - 2):
            c = wl
            if material == 0:
                if y >= H - 4 or x >= W - 6:
                    c = wd
                elif h(81, variant, x // 3, y // 2) % 11 == 0:
                    c = wd
            else:
                course = (y - roof_h) // 3
                if (y - roof_h) % 3 == 2 or (x + (course % 2) * 3) % 6 == 0:
                    c = ROCK
                if x >= W - 6:
                    c = ROCK if c == ROCK_L else ROCK_D
            cv.set(x, y, c)
    # Sombra del alero sobre la fachada.
    for x in range(2, W - 2):
        cv.set(x, roof_h, rj)
    # Vano en arco (sin puerta) y ventanas de 2x3 con alféizar.
    door_x = 28 if variant == 0 else 14
    for y in range(roof_h + 6, H - 1):
        for x in range(door_x, door_x + 8):
            if y == roof_h + 6 and x in (door_x, door_x + 1, door_x + 6, door_x + 7):
                continue
            if y == roof_h + 7 and x in (door_x, door_x + 7):
                continue
            cv.set(x, y, OUTLINE)
    windows = (12, 48) if variant == 0 else (33, 44)
    for wx in windows:
        for y in range(roof_h + 6, roof_h + 9):
            for x in range(wx, wx + 2):
                cv.set(x, y, NIGHT)
        for x in range(wx - 1, wx + 3):
            cv.set(x, roof_h + 9, DIRT_D)
    cv.outline()
    return cv


def build_casas():
    atlas = Canvas(128, 96)
    for m in range(2):
        for v in range(2):
            atlas.paste(house(m, v), v * 64, m * 48)
    return atlas


# =============================================================================================
# Salida, validación y vistas
# =============================================================================================
def build():
    out = {}
    hierba = Canvas(64, 16)
    for v in range(4):
        hierba.paste(grass(v), v * T, 0)
    out["tileset_hierba.png"] = hierba
    out["tileset_relieve.png"] = build_relieve()
    out["tileset_cascada.png"] = build_cascada()
    out["tileset_sombras.png"] = build_sombras()
    out["tileset_decoracion.png"] = build_decoracion()
    out["tileset_piedras.png"] = build_piedras()
    out["tileset_puente_ancho.png"] = build_puente()
    out.update(build_trees())
    out.update(build_rocks_wood())
    out["sprite_casas.png"] = build_casas()
    return out


def validate(name, cv, palette):
    size, keys, fixed = ATLASES[name]
    if (cv.w, cv.h) != size:
        raise SystemExit("%s: mide %dx%d, la spec pide %dx%d" % (name, cv.w, cv.h, size[0], size[1]))
    if keys & fixed:
        raise SystemExit("%s: colores fijos que son claves del grupo: %s" % (name, sorted(keys & fixed)))
    allowed = keys | fixed
    for y in range(cv.h):
        for x in range(cv.w):
            c = cv.px[y][x]
            if c is None:
                continue
            if c not in palette:
                raise SystemExit("%s: %s fuera de paleta en (%d, %d)" % (name, c, x, y))
            if c not in allowed:
                raise SystemExit("%s: %s no es clave ni color fijo del grupo, en (%d, %d)" % (name, c, x, y))


# --- Recoloreado de muestra para la hoja de contacto (refleja TerrainTileset y la spec §2) ----
LEAVES = [("265c42", "3e8948"), ("3e8948", "63c74d"), ("124e89", "0099db"), ("0099db", "2ce8f5"),
          ("68386c", "b55088"), ("b55088", "f6757a"), ("a22633", "e43b44"), ("be4a2f", "f77622"),
          ("feae34", "fee761"), ("8b9bb4", "ffffff"), ("3a4466", "5a6988"), ("733e39", "b86f50")]
LEAF_SHADOW = ["193c3e", "265c42", "262b44", "124e89", "3e2731", "68386c", "3e2731", "733e39", "d77643",
               "5a6988", "262b44", "3e2731"]
TRUNKS = ["733e39", "3e2731", "ffffff", "f77622", "c0cbdc", "262b44", "e8b796", "a22633"]
GROUNDS = [("3e8948", "63c74d", "63c74d", "3e8948", "265c42"), ("265c42", "3e8948", "3e8948", "63c74d", "193c3e"),
           ("e4a672", "ead4aa", "ead4aa", "e4a672", "c28569"), ("c28569", "e8b796", "e8b796", "c28569", "b86f50")]
GROUNDS_HIGH = [("63c74d", "3e8948", "3e8948"), ("3e8948", "63c74d", "265c42"), ("ead4aa", "e4a672", "e4a672"),
                ("e8b796", "c28569", "c28569")]
FRUITS = [("e43b44", "a22633"), ("fee761", "feae34"), ("f77622", "be4a2f"), ("b55088", "68386c"),
          ("ffffff", "c0cbdc"), ("0099db", "124e89")]
FLOWER_PREF = ["fee761", "ffffff", "f6757a", "b55088", "feae34", "f77622", "0099db", "e43b44"]


def _dist(a, b):
    ra, rb = rgba(a), rgba(b)
    return math.sqrt(sum(((ra[i] - rb[i]) / 255.0) ** 2 for i in range(3)))


def fruit_color(leaf):
    best, best_d = FRUITS[0], -1
    for pair in FRUITS:
        d = min(_dist(pair[0], LEAVES[leaf][0]), _dist(pair[0], LEAVES[leaf][1]))
        if d >= 0.5:
            return pair
        if d > best_d:
            best, best_d = pair, d
    return best


def flower_colors(leaf, ground):
    first = fruit_color(leaf)[0]
    out = [first]
    for c in FLOWER_PREF:
        if c not in out and _dist(c, GROUNDS[ground][0]) >= 0.5:
            out.append(c)
        if len(out) == 3:
            break
    return out


def recolor_map(name, style, high=False):
    keys = ATLASES[name][1]
    leaf, trunk_i, ground = style
    g = GROUNDS[ground]
    grass_cols = GROUNDS_HIGH[ground] if high else (g[0], g[1], g[4])
    m = {}
    if keys & GRASS_KEYS:
        m.update({K_GRASS: grass_cols[0], K_GRASS_SPECK: grass_cols[1], K_GRASS_SHADOW: grass_cols[2]})
    if keys & CLEAR_KEYS:
        m.update({K_CLEAR: g[2], K_CLEAR_SPECK: g[3]})
    if keys & TREE_KEYS:
        m.update({K_LEAF_LIGHT: LEAVES[leaf][1], K_LEAF_DARK: LEAVES[leaf][0], K_TRUNK: TRUNKS[trunk_i],
                  K_LEAF_SHADOW: LEAF_SHADOW[leaf]})
    if keys & FRUIT_KEYS:
        f = fruit_color(leaf)
        m.update({K_FRUIT: f[0], K_FRUIT_SHADOW: f[1]})
    if keys & FLOWER_KEYS:
        fl = flower_colors(leaf, ground)
        m.update({K_FLOWER[i]: fl[i] for i in range(3)})
    return m


def recolor(cv, mapping):
    out = cv.copy()
    for y in range(cv.h):
        for x in range(cv.w):
            c = cv.px[y][x]
            if c in mapping:
                out.px[y][x] = mapping[c]
    return out


BG = (96, 96, 104, 255)
INK = (235, 235, 235, 255)


def contact_sheet(atlases, path, scale=3, width=2100):
    """Todas las piezas a x3 sobre fondo neutro, con el nombre de cada atlas; después, muestras
    recoloreadas por Bosque (normal y meseta alta) para juzgar el tono y la sombra de nivel."""
    blocks = [(name, atlases[name]) for name in ATLASES]
    styles = [("verde, copa redonda", (1, 0, 0)), ("verde oscuro, sauce", (2, 1, 1)),
              ("arena, palmera", (8, 6, 2))]
    for label, st in styles:
        for high in (False, True):
            for name in ("tileset_relieve.png", "tileset_hierba.png", "tileset_decoracion.png",
                         "tileset_sombras.png", "tileset_cascada.png"):
                if high and name in ("tileset_decoracion.png", "tileset_cascada.png"):
                    continue
                cv = recolor(atlases[name], recolor_map(name, st, high and name != "tileset_cascada.png"))
                blocks.append(("%s (%s%s)" % (name[:-4], label, ", meseta alta" if high else ""), cv))
        for name in ("sprite_arboles.png", "sprite_arbol_joven.png", "sprite_arbol_grande.png", "sprite_rocas.png",
                     "sprite_madera.png", "sprite_nujio.png"):
            blocks.append(("%s (%s)" % (name[:-4], label), recolor(atlases[name], recolor_map(name, st))))
    blocks.append(("sprite_casas (claro verde)", recolor(atlases["sprite_casas.png"], recolor_map("sprite_casas.png", (1, 0, 0)))))
    pad, head = 12, 14
    placed, x, y, row_h = [], pad, pad, 0
    for label, cv in blocks:
        w, hh = cv.w * scale, cv.h * scale + head
        if x + w > width and x > pad:
            x, y, row_h = pad, y + row_h + pad, 0
        placed.append((label, cv, x, y))
        x += w + pad
        row_h = max(row_h, hh)
    img = Image.new("RGBA", (width, y + row_h + pad), BG)
    draw = ImageDraw.Draw(img)
    for label, cv, x, y0 in placed:
        draw.text((x, y0), label, fill=INK)
        img.alpha_composite(cv.image().resize((cv.w * scale, cv.h * scale), Image.NEAREST), (x, y0 + head))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    img.save(path)
    print("hoja de contacto", path, img.size)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="carpeta para vistas ampliadas x3 de cada atlas")
    parser.add_argument("--sheet", help="PNG de la hoja de contacto (x3, fondo neutro)")
    args = parser.parse_args()
    palette = load_palette()
    atlases = build()
    missing = set(ATLASES) - set(atlases)
    if missing:
        raise SystemExit("faltan atlas: %s" % sorted(missing))
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in ATLASES:
        cv = atlases[name]
        validate(name, cv, palette)
        img = cv.image()
        img.save(os.path.join(OUT_DIR, name))
        print("%s %dx%d" % (name, img.width, img.height))
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            bg = Image.new("RGBA", img.size, BG)
            bg.alpha_composite(img)
            bg.resize((img.width * 3, img.height * 3), Image.NEAREST).save(os.path.join(args.preview, name))
    if args.sheet:
        contact_sheet(atlases, args.sheet)


if __name__ == "__main__":
    main()
