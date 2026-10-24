"""Genera los sprites de la primera pasada (docs/art/specs/primera-pasada.md).

Cada fotograma es una lista de filas de caracteres; cada carácter es un color de la paleta
assets/palettes/palette_nuevos_bosques.gpl (tabla COLORS) y "." es transparente. El contorno de
1 px se añade solo (OUTLINE alrededor de lo pintado), así que las filas solo llevan el relleno y,
si hace falta, algún contorno interior explícito con "K".

Uso (desde la raíz del repo):
    python tools/art/make_sprites.py              # escribe assets/sprites/*.png
    python tools/art/make_sprites.py --preview D  # además, vistas x8 en la carpeta D

Los monstruos se pintan con COLORES CLAVE (A, B, C) que el juego reasigna a las hojas y el tronco
de cada Bosque al cargarlos (UnicoArt.recolor). No cambies esos tres colores sin cambiar también
UnicoArt.KEY_*.
"""
import argparse
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PALETTE_PATH = os.path.join(ROOT, "assets", "palettes", "palette_nuevos_bosques.gpl")
OUT_DIR = os.path.join(ROOT, "assets", "sprites")

OUTLINE = "181425"
COLORS = {
    "K": OUTLINE,     # contorno
    "W": "ffffff",    # blanco (ojos)
    # Lenfi
    "H": "262b44",    # cabello negro
    "h": "3a4466",    # brillo del cabello
    "S": "c28569",    # piel trigueña
    "s": "b86f50",    # sombra de la piel
    "E": "3e8948",    # ojos verdes
    # Adoc: protector, cuero y túnica rojiza
    "T": "be4a2f",    # túnica
    "t": "d77643",    # brillo de la túnica
    "L": "733e39",    # cuero (mangas, botas)
    "k": "3e2731",    # cinturón
    "P": "3a4466",    # pantalón
    # Sfida: túnica de oficiante violeta con cinta dorada
    "V": "68386c",    # túnica
    "v": "b55088",    # pliegues claros
    "Y": "feae34",    # cinta y diadema
    "y": "fee761",    # Luz entre las manos
    # Monstruos: colores clave (se reasignan por Bosque)
    "A": "c0cbdc",    # clave hoja clara
    "B": "8b9bb4",    # clave hoja oscura
    "C": "5a6988",    # clave tronco
    "R": "e43b44",    # iris del Ofomni (fijo)
    # Iconos
    "l": "b86f50",    # madera clara
    "r": "be4a2f",    # tejado
    "w": "e4a672",    # pared
}


def load_palette():
    colors = set()
    with open(PALETTE_PATH, encoding="utf-8") as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 3 and all(p.isdigit() for p in parts[:3]):
                colors.add("%02x%02x%02x" % tuple(int(p) for p in parts[:3]))
    return colors


# --- Adoc (16x16, 4 direcciones x 2 fotogramas) --------------------------------------------
# Cuerpo (filas 0-12) + piernas (filas 13-15). Los fotogramas de abajo/arriba alternan la pierna
# adelantada; los de lado alternan zancada y pies juntos.

ADOC_TOP_DOWN = [
    "................",
    "................",
    ".....HHHHHH.....",
    "....HHhhHHHH....",
    "....HhHHHHHH....",
    "....HSSSSSSH....",
    "....HSESSESH....",
    "....HsSSSSsH....",
    "....H.sSSs.H....",
    "...LHtTTTTtHL...",
    "...LHLTTTTLLL...",
    "...SHLTTTTLLS...",
    "....kkkkkkkk....",
]
ADOC_TOP_UP = [
    "................",
    "................",
    ".....HHHHHH.....",
    "....HHhhHHHH....",
    "....HhHHHHHH....",
    "....HHHHHHHH....",
    "....HHHHhHHH....",
    "....HHHHHHHH....",
    ".....HHhHHH.....",
    "...LLTTHhTTLL...",
    "...LLTTHhTTLL...",
    "...SLTTkhTTLS...",
    "....kkkkkkkk....",
]
ADOC_TOP_RIGHT = [
    "................",
    "................",
    ".....HHHHHH.....",
    "....HHhhHHHH....",
    "....HhHHHHHH....",
    "....HHHHSSSS....",
    "....HHHHSSES....",
    "....HHHHsSSS....",
    "....HH..sSs.....",
    "....H.LTTtL.....",
    "....H.LTTtL.....",
    "....h.LTStL.....",
    "......kkkkk.....",
]
LEGS_FRONT = [
    [
        ".....PP..LL.....",
        ".....LL.........",
        "................",
    ],
    [
        ".....LL..PP.....",
        ".........LL.....",
        "................",
    ],
]
LEGS_SIDE = [
    [
        ".....PP..PP.....",
        "....LL....LL....",
        "................",
    ],
    [
        "......PPPP......",
        "......LLLL......",
        "................",
    ],
]


def mirror(rows):
    return [r[::-1] for r in rows]


def adoc_frames():
    """Filas: abajo, arriba, izquierda, derecha (orden de PlayerWalker.SHEET_ROWS)."""
    down = [ADOC_TOP_DOWN + legs for legs in LEGS_FRONT]
    up = [ADOC_TOP_UP + legs for legs in LEGS_FRONT]
    right = [ADOC_TOP_RIGHT + legs for legs in LEGS_SIDE]
    left = [mirror(f) for f in right]
    return [down, up, left, right]


# --- Sfida (16x16, 2 fotogramas de reposo) --------------------------------------------------
SFIDA_0 = [
    "................",
    "................",
    ".....HHHHHH.....",
    "....HHYYYYHH....",
    "....HSSSSSSH....",
    "....HSESSESH....",
    "....HsSSSSsH....",
    "....H.sSSs.H....",
    "...HVVvYYvVVH...",
    "...HVvVYYVvVH...",
    "...hVvVYYVvVh...",
    "...SVVVYYVVVS...",
    "....VVVYYVVV....",
    "....VvVYYVvV....",
    "...VVVVYYVVVV...",
    "................",
]
# Junta las manos y sostiene un poco de Luz.
SFIDA_1 = SFIDA_0[:9] + [
    "...hVvSyySvVh...",
    "...hVVvWWvVVh...",
    "....VVVYYVVV....",
] + SFIDA_0[12:]


# --- Botarramas (16x24, 2 fotogramas de renqueo) --------------------------------------------
# Ave sin plumas mirando a la izquierda: piel clara con granos oscuros, muñón de ala, pico, cola y
# patas en color tronco. Fotograma 0: se apoya en la pata buena con la mala encogida.
# Fotograma 1: baja el cuerpo, adelanta la cabeza y apoya la pata mala, torcida.
BOTARRAMAS_0 = [
    "................",
    "................",
    "................",
    "................",
    "....AAA.........",
    "...AAAAA........",
    "...AWKAA........",
    ".CCCAAAA........",
    "..CCAAA.........",
    "....AAB.........",
    "....AAB.........",
    "....AAB.........",
    "....AABAA.......",
    "...AAABAAAAA....",
    "..AABAABBBAAAC..",
    "..ABAAABBBBAACC.",
    "..AAABAAABAAAC..",
    "...BAAABAAABB...",
    "....BBBBBBBB....",
    ".....C...CC.....",
    ".....C....C.....",
    ".....C..........",
    "....CCC.........",
    "................",
]
BOTARRAMAS_1 = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "....AAA.........",
    "...AAAAA........",
    "...AWKAA........",
    ".CCCAAAA........",
    "..CCAAA.........",
    "....AAB.........",
    "....AAB.........",
    "....AABAA.......",
    "...AAABAAAAA....",
    "..AABAABBBAAAC..",
    "..ABAAABBBBAACC.",
    "..AAABAAABAAAC..",
    "...BAAABAAABB...",
    "....BBBBBBBB....",
    ".....C....C.....",
    "......C...C.....",
    ".....C.....C....",
    "....CC....CCC...",
    "................",
]


# --- Ofomni (32x32, 2 fotogramas) -----------------------------------------------------------
# Mitad izquierda del cuerpo (se refleja para la derecha) + tentáculos por trayectoria.
OFOMNI_HALF = [
    "................",
    "................",
    "................",
    "...........AAAAA",
    "........AAAAAAAA",
    "......AAAAAAAAAA",
    ".....AAAAAAAAAAA",
    "....AAAAAAKKKKKK",
    "....AAAAKKWWWWWW",
    "...AAAAKWWWWWWWW",
    "...AAAKWWWWWRRRR",
    "...AAKWWWWWRRRRR",
    "...AAKWWWWRRRKKK",
    "...BAKWWWWRRKKKK",
    "...BAKWWWWRRKKKK",
    "...BBKWWWWRRRKKK",
    "...BBAKWWWWRRRRR",
    "....BBKWWWWWRRRR",
    "....BBBKKWWWWWWW",
    ".....BBBBKKKKKKK",
    "......BBBBBBBBBB",
    ".......BBBBBBBBB",
    "........BBBBBBBB",
]
# Brillo del ojo (arriba a la izquierda, de donde viene la luz).
OFOMNI_OVERRIDES = {(13, 12): "W", (14, 12): "W"}
OFOMNI_TENTACLE_TOP = 22
# Columna de cada tentáculo fila a fila desde OFOMNI_TENTACLE_TOP, por fotograma.
OFOMNI_TENTACLES = [
    [
        [9, 9, 8, 7, 7, 6, 6, 6, 7],
        [13, 13, 12, 12, 11, 11, 11, 12],
        [18, 18, 19, 19, 20, 20, 20, 19],
        [22, 22, 23, 24, 24, 25, 25, 25, 24],
    ],
    [
        [9, 9, 9, 8, 8, 8, 9, 10, 10],
        [13, 13, 13, 13, 14, 14, 14, 13],
        [18, 18, 18, 18, 17, 17, 17, 18],
        [22, 22, 22, 23, 23, 23, 22, 21, 21],
    ],
]
# Filas de cada tentáculo que miden 2 px (las de la raíz).
OFOMNI_THICK_ROWS = 3


def ofomni_frames():
    frames = []
    for paths in OFOMNI_TENTACLES:
        grid = [list(h + h[::-1]) for h in OFOMNI_HALF] + [list("." * 32) for _ in range(32 - len(OFOMNI_HALF))]
        for (x, y), ch in OFOMNI_OVERRIDES.items():
            grid[y][x] = ch
        for path in paths:
            toward_center = 1 if path[0] < 16 else -1
            for i, x in enumerate(path):
                y = OFOMNI_TENTACLE_TOP + i
                grid[y][x] = "C"
                if i < OFOMNI_THICK_ROWS:
                    grid[y][x + toward_center] = "C"
        frames.append(["".join(r) for r in grid])
    return frames


# --- Iconos 8x8 ---------------------------------------------------------------------------
ICON_SIGN = [
    "........",
    ".llllll.",
    ".lLLLLl.",
    ".llllll.",
    "...LL...",
    "...LL...",
    "...LL...",
    "........",
]
ICON_REFUGE = [
    "........",
    "...rr...",
    "..rrrr..",
    ".rrrrrr.",
    ".wwkkww.",
    ".wwkkww.",
    ".wwkkww.",
    "........",
]


# --- Render ---------------------------------------------------------------------------------
def render(rows, outline=True):
    h = len(rows)
    w = len(rows[0])
    for r in rows:
        if len(r) != w:
            raise ValueError("fila de ancho %d, se esperaba %d: %r" % (len(r), w, r))
    grid = [[None if ch == "." else COLORS[ch] for ch in r] for r in rows]
    if outline:
        src = [row[:] for row in grid]
        for y in range(h):
            for x in range(w):
                if src[y][x] is not None:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and src[yy][xx] is not None:
                        grid[y][x] = OUTLINE
                        break
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            c = grid[y][x]
            if c is not None:
                img.putpixel((x, y), (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255))
    return img


def sheet(frame_rows):
    """frame_rows: lista de filas de la hoja, cada una lista de fotogramas (listas de strings)."""
    imgs = [[render(f) for f in row] for row in frame_rows]
    fw, fh = imgs[0][0].size
    cols = max(len(r) for r in imgs)
    out = Image.new("RGBA", (fw * cols, fh * len(imgs)), (0, 0, 0, 0))
    for j, row in enumerate(imgs):
        for i, im in enumerate(row):
            if im.size != (fw, fh):
                raise ValueError("fotograma de tamaño %s, se esperaba %s" % (im.size, (fw, fh)))
            out.paste(im, (i * fw, j * fh))
    return out


SPRITES = {
    "sprite_adoc_walk.png": lambda: sheet(adoc_frames()),
    "sprite_sfida_idle.png": lambda: sheet([[SFIDA_0, SFIDA_1]]),
    "sprite_botarramas_walk.png": lambda: sheet([[BOTARRAMAS_0, BOTARRAMAS_1]]),
    "sprite_ofomni_idle.png": lambda: sheet([ofomni_frames()]),
    "sprite_icon_sign.png": lambda: sheet([[ICON_SIGN]]),
    "sprite_icon_refuge.png": lambda: sheet([[ICON_REFUGE]]),
}


def check_palette(img, palette, name):
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = img.getpixel((x, y))
            if a not in (0, 255):
                raise ValueError("%s: alfa parcial" % name)
            if a == 255 and ("%02x%02x%02x" % (r, g, b)) not in palette:
                raise ValueError("%s: color fuera de paleta %02x%02x%02x" % (name, r, g, b))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="carpeta para vistas ampliadas x8")
    args = parser.parse_args()
    palette = load_palette()
    for ch, c in COLORS.items():
        if c not in palette:
            sys.exit("color %s (%s) fuera de paleta" % (ch, c))
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in SPRITES.items():
        img = build()
        check_palette(img, palette, name)
        img.save(os.path.join(OUT_DIR, name))
        print("%s %dx%d" % (name, img.width, img.height))
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            bg = Image.new("RGBA", img.size, (62, 137, 72, 255))
            bg.alpha_composite(img)
            bg.resize((img.width * 8, img.height * 8), Image.NEAREST).save(os.path.join(args.preview, name))


if __name__ == "__main__":
    main()
