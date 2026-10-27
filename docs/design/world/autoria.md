# Autoría de regiones: cómo pintar el mundo

Guía para el dueño. Decisión: [ADR 0014 §4](../../decisions/0014-mundo-2-relieve-movimiento-libre-y-mundo-hibrido.md). Lectura del código: `scripts/world/region_authoring.gd` (`RegionAuthoring`). Paleta: [`data/world/authoring_palette.json`](../../../data/world/authoring_palette.json).

La geografía grande de cada región (relieve, ríos, caminos, Bosques clave y lugares con nombre) se dibuja a mano en **imágenes PNG por capas** y una **tabla de lugares**. Lo que dejes sin pintar lo rellena el generador, distinto en cada partida.

## 1. Qué hay en la carpeta de una región

Todo vive en `data/world/regions/<region>/`. Para el Valle del Sara: `data/world/regions/valle_del_sara/`.

| Archivo | Qué pintas | Si lo dejas transparente |
|---|---|---|
| `altura.png` | Relieve: 4 niveles y las cumbres | El generador pone la altura con su ruido |
| `agua.png` | Ríos, lagos, mar y vados | Sin agua; el generador puede añadir arroyos de montaña |
| `caminos.png` | Caminos principales y puentes | El generador traza caminos entre las villas |
| `bosques.png` | Bosques clave, un color por Bosque | El generador reparte los Bosques (4–16 chunks) |
| `lugares.csv` | Villas, villa natal, hitos, tarcas, Nujio de los Bosques clave y otros lugares | — |

Las PNG que hay ahora salieron del generador actual (seed 15, la primera en la que la villa natal cae donde empieza hoy la partida). Son un punto de partida: retócalas o pinta encima tu mapa del Sur Lenfi.

**Ya no son solo del generador.** Encima de esa exportación hay trazos por script: los **7 afluentes del Sara** (4 de las Urd Gumnavis y 3 de las Gumnada Gumnavis; ver [`sur-lenfi.md`](sur-lenfi.md#afluentes-del-sara)) en `agua.png`, sus colinas de nacimiento en `altura.png`, sus fuentes (filas `manantial_<n>`, "Fuente del 1ro"… "Fuente del 7mo") en `lugares.csv`, sus puentes en `caminos.png` y sus nombres ("1ro del Sara"… "7mo del Sara") como filas `lugar` con id `afluente_<n>` en `lugares.csv` (el script las rehace; las demás filas no las toca). Salen de `tools/world/paint_afluentes.py`: para mover un afluente, cambia sus puntos de control y ejecuta `python tools/world/paint_afluentes.py --from-ref` (rehace los afluentes desde la exportación original; descarta lo retocado a mano en esas tres PNG después). Sin `--from-ref` pinta encima de lo que haya y no borra nada.

Encima de los afluentes va **el relieve del dueño** (2026-10-26), de `tools/world/paint_relieve_autor.py`:
- **Larr**, la cordillera norte, "una pared impenetrable": las 3 filas de arriba de `altura.png` (12 casillas) son cumbre de lado a lado, sin huecos. El Sara ya no toca el borde norte: nace al pie de Larr. Debajo, 3 filas de nivel 2 como mínimo.
- **Cordillera occidental** (Urd Gumnavis, a caballo con Dorias), "colinas y montañas bastante transitables": en la franja `x < 40` (2 chunks), desde el pie de Larr hasta la fila 259 (casi la costa), no hay cumbres (pasan a nivel 3) y el nivel 0 sube a 1: todo es nivel 1-3 y se cruza a pie. Los tres afluentes del oeste (3ro, 5to y 7mo del Sara) **nacen dentro de la cordillera** (dueño: "no nacen en el Valle, no pueden nacer en Dorias porque la cordillera lo impide"), en un **manantial** (§5) sobre una colina de nivel 3 y 2, sin cumbre, y bajan al Sara. Ningún río toca el borde oeste. Los otros cuatro (1ro, 2do, 4to y 6to) también nacen en un manantial pisable en lo alto de su colina, sin cumbre (dueño, 2026-10-26: los 7 afluentes nacen en un manantial; ficha `docs/design/mechanics/mundo-2.md`). Fuera de Larr ningún río nace ya en una cumbre.
- **Azhin**: fila `villa_azhin` de `lugares.csv` en (16, 4), al pie de Larr en el noroeste (Lean), con un camino hasta el camino de Lean que ya existía. Su **tarca** es un lugar propio, `tarca_azhin` en (8, 8): en lo alto de la montaña al oeste de la villa (nivel 3, sin nada más alto alrededor, a unas 36 casillas de Azhin; dueño: "a 20 o más casillas, pero más al oeste, en las montañas, en lo alto de una montaña"). Aparece en la historia en el encuentro con los ledai de Estrellazul. Los manantiales se llaman "Fuente del 3ro", "Fuente del 5to" y "Fuente del 7mo" (dueño: nombre corto).
- **Pendiente**: la **Tarca de Trastas** está en la misma cordillera pero del lado de Dorias, fuera de esta región. Se pondrá cuando exista la región de Dorias.

**Orden de los scripts** (cada uno sobre la salida del anterior; los dos son idempotentes):

```bash
python tools/world/paint_afluentes.py --from-ref   # 1. afluentes (rehace altura, agua y caminos desde la base)
python tools/world/paint_relieve_autor.py          # 2. Larr, cordillera occidental y Azhin
bash tools/world/preview_region.sh valle_del_sara 7  # 3. validar y ver
```

Si se ejecuta el paso 1 con `--from-ref`, hay que volver a pasar el 2: el 1 parte de la exportación original y borra Larr y el camino de Azhin.

## 2. La escala

- **1 píxel = 1 celda gruesa = 4×4 casillas del juego.**
- **Un chunk son 20×20 píxeles.** El Valle del Sara mide 12×16 chunks, es decir, **240×320 píxeles**.
- El tamaño de la región **sale de la imagen**: si haces la imagen más grande, la región crece. Los lados tienen que ser múltiplos de 20.
- **Las cuatro PNG tienen que medir lo mismo.**
- El píxel (0, 0) es la esquina noroeste (arriba a la izquierda). El norte está arriba.

Truco: pon en tu programa una **cuadrícula de 20×20 px** y verás los chunks.

## 3. El programa y el lápiz

Vale cualquier programa con capas que exporte PNG con transparencia. Recomendados: **Aseprite** (de pago, el mejor para píxel) o **Krita** (gratis). También sirven LibreSprite, Pixelorama o GIMP.

Configura **antes de pintar**:
1. Lienzo de **240×320** px (o el tamaño de tu región), modo **RGBA** y fondo **transparente**.
2. **Lápiz de 1 px sin suavizado** (sin *antialiasing*): en Aseprite, la herramienta *Pencil*; en Krita, un pincel *Pixel Art* con suavizado desactivado. Nada de pinceles blandos, difuminar, degradados ni varitas con suavizado.
3. El **cubo de relleno** sin tolerancia (0) y sin suavizado.
4. Al **escalar o rotar**, interpolación "vecino más cercano" (*Nearest Neighbor*).
5. Carga la paleta: los colores exactos están en `data/world/authoring_palette.json` (tabla de abajo). Un color que no esté en la paleta es un error.

### Colores

| Capa | Qué | Color |
|---|---|---|
| altura | nivel 0 (llano) | `#303030` |
| altura | nivel 1 | `#606060` |
| altura | nivel 2 | `#909090` |
| altura | nivel 3 | `#c0c0c0` |
| altura | cumbre (montaña que no se puede cruzar) | `#ffffff` |
| agua | río navegable | `#1e4fbe` |
| agua | río estrecho | `#4f8fff` |
| agua | lago | `#2aa8a8` |
| agua | mar | `#0e1e6e` |
| agua | vado o paso (se cruza a pie) | `#a0d8ff` |
| caminos | camino | `#c08040` |
| caminos | puente | `#804020` |
| bosques | cada Bosque clave | el que pongas en su fila de `lugares.csv` |

**Borrar** es dejar el píxel **transparente** (goma con alfa al 0), no pintarlo de blanco ni de negro.

## 4. Las capas, una a una

**Altura.** Pinta los niveles a manchas grandes. Entre dos niveles el juego pondrá riscos con escaleras o rampas donde pase un camino. La cumbre es infranqueable: úsala para las cimas, no para colinas.

**Agua.** Un río tiene que **unir dos sitios**: dos bordes del mapa, un borde y un lago o el mar, o nacer en una cumbre o en un **manantial**. Un manantial es un lugar de `lugares.csv` (tipo `manantial`) pegado por un lado al primer píxel del río, en nivel 2 o 3: sirve para que un río nazca en la montaña sin cumbre (en la cordillera occidental, que no tiene). En el juego el agua se queda quieta junto a él (no hace meandro). Un río que se corta en medio es un error. Píntalo como una línea continua de píxeles que se toquen **por un lado** (no solo por la esquina). Pon **vados** cada cierto tramo para que se pueda cruzar a pie; un camino que cruza un río se convierte en puente.

**Caminos.** Una línea de 1 px por camino (en el juego tendrá 3 casillas de ancho). Donde cruce agua, usa el color de puente.

**Bosques.** Basta con pintar el chunk o los chunks del Bosque (un píxel en cada chunk ya vale). Reglas:
- Cada color es un Bosque declarado en `lugares.csv` (fila de tipo `bosque`).
- Un Bosque tiene de **4 a 16 chunks**, contiguos (que se toquen por un lado). Si pintas menos de 4, el generador lo amplía con chunks libres de alrededor.
- Un chunk es de un solo Bosque.
- El **Nujio** del Bosque (la `x`, `y` de su fila) tiene que caer dentro de su color.

## 5. La tabla de lugares (`lugares.csv`)

Se edita con cualquier hoja de cálculo (Excel, LibreOffice, Google Sheets) y se guarda como **CSV UTF-8**. Vale con comas o con punto y coma.

| Columna | Qué poner |
|---|---|
| `id` | Identificador único, sin espacios ni tildes: `villa_natal`, `hito_puente_viejo` |
| `nombre` | El nombre que verá el jugador, con tildes |
| `tipo` | `villa`, `villa_natal`, `hito`, `tarca`, `bosque` (el Nujio de un Bosque clave), `lugar` o `manantial` (nacimiento de un río; ver §4, Agua) |
| `x`, `y` | **Píxeles de las PNG**: los que marca el cursor de tu programa. Sin cuentas de chunks |
| `color` | Solo para `bosque`: su color en `bosques.png`, como `#3a8f2b` |
| `estilo` | Opcional: silueta y hojas del Bosque |
| `notas` | Libre |

Reglas: una sola `villa_natal` (sustituye a `start_chunk`: ahí empieza la partida). Ningún lugar fuera del mapa, en el agua ni en una cumbre. Toda villa tiene que poder alcanzarse a pie desde la villa natal (sin cumbres ni agua sin vado o puente por medio). Las líneas en blanco o que empiezan por `#` se ignoran.

Ejemplo:

```csv
id,nombre,tipo,x,y,color,estilo,notas
villa_natal,Olss,villa_natal,130,270,,,Donde empieza la partida
bosque_sara,Bosque del Sara,bosque,120,150,#3a8f2b,conifera,"Bosque clave, junto al río"
```

## 6. Exportar las capas

Lo cómodo es tener **un solo archivo con cuatro capas** llamadas `altura`, `agua`, `caminos` y `bosques`, y exportar cada capa a su PNG.

**Aseprite** (desde la consola, en la carpeta de la región):

```bash
aseprite -b valle.aseprite --split-layers --save-as "{layer}.png"
```

O en el menú: *Archivo → Exportar → Exportar como…*, nombre `{layer}.png` y marcar **Split layers**.

**Krita**: *Herramientas → Scripts → Exportar capas* (*Export Layers*), formato PNG, carpeta de la región, sin recortar al contenido (**desmarca "ajustar al contenido"** para que todas midan 240×320).

**Otros programas**: oculta todas las capas menos una, *Exportar como PNG* con el nombre exacto (`altura.png`…) y repite.

Guarda los PNG en `data/world/regions/<region>/`, sobrescribiendo los que haya.

## 7. Comprobar y ver la vista previa

En Git Bash, desde la carpeta del proyecto:

```bash
bash tools/world/preview_region.sh valle_del_sara 42
```

- Primero **valida** e imprime los errores en español, con las coordenadas en píxeles y el chunk. Ejemplo: `altura.png: color desconocido #2f2f2f en (12, 40) [chunk 0, 2].` Ve a ese píxel y píntalo con un color de la paleta.
- Después escribe **`build/preview_valle_del_sara_42.png`**: la región a 1 píxel por casilla (960×1280 en el Valle del Sara), con la altura en verdes (más claro = más alto; las cumbres en blanco; a cuadros lo que no has pintado), el agua, los caminos, los Bosques clave con un velo de su color, la rejilla de chunks con sus coordenadas, los lugares con su nombre y los **errores rodeados en rojo**. La leyenda y la lista de lugares salen en la consola.
- Si no hay errores dice `Autoría válida.`. Si hay errores, la imagen se escribe igual y el script termina con error.
- El número del final es la **seed**. La vista previa dibuja encima lo que rellena el generador con esa seed (la pasada de región, `RegionPlan`): los Bosques con su frontera (velo de color; gris los muertos), los caminos de la red procedural (marrón claro), las puertas entre chunks (blanco = sendero, amarillo = camino, cian = abierta para que el Bosque se recorra a pie), los refugios (cuadro granate) y las **aldeas** (rombo naranja con su nombre tentativo). Lo que pintas manda: la altura y el agua pintadas no cambian con la seed, salvo el meandro del agua (±1 px).

Si algo no funciona, Godot tiene que estar instalado (lo busca igual que `tools/test.sh`).

## 8. Para programadores

- `RegionAuthoring.load_region(&"valle_del_sara")` lee la carpeta indicada en la clave `"authoring"` del JSON de la región y devuelve capas (`height`, `water`, `roads`, `bosque`), `places`, `size_chunks()`, `home_chunk()` y `errors`.
- La carpeta de autoría tiene un `.gdignore`: Godot no la importa (las PNG se leen como datos y el CSV no es una traducción). Cómo llega a un build exportado se decide en M5/M10.
- Las PNG van en Git LFS (`.gitattributes`). Tras clonar: `git lfs pull`.
- `bash tools/world/export_region_authoring.sh valle_del_sara [seed]` vuelve a exportar las PNG iniciales desde el generador actual. **Sobrescribe lo que haya pintado**: solo para el punto de partida. Si la región ya tiene `agua.png` se niega y solo escribe con `--force`. En el Valle del Sara **no lo fuerces**: borraría los afluentes del Sara (`agua.png`, `altura.png`, `caminos.png` ya llevan trazos por script, §1) y lo que el dueño haya retocado. Si alguna vez hiciera falta, después hay que volver a pasar `python tools/world/paint_afluentes.py` y `python tools/world/paint_relieve_autor.py` (en ese orden, §1) y revisar el diff de las PNG antes de hacer commit.
- `python tools/world/paint_afluentes.py [--from-ref [commit]]` (Pillow) pinta los afluentes del Sara: polilíneas de puntos de control en px de la PNG, trazo de 1 px en 4-vecindad que se para al tocar el Sara, río estrecho en la montaña y navegable desde que sale de ella (`mountain_exit`), filas `afluente_<n>` de `lugares.csv` con su nombre, nacimiento en un manantial (fila `manantial_<n>` de `lugares.csv`, un px aguas arriba) en lo alto de una colina de nivel 3 y 2 sin cumbre (solo sube el relieve; queda el modo `"nacimiento": "cumbre"` con cumbre de 3×3 por si hiciera falta), puente donde cruza un camino. Es idempotente. El test `test_valle_del_sara_has_the_sara_tributaries` comprueba que la red de agua es conexa, que llegan al Sara al menos 4 afluentes por el oeste y 3 por el este, que nacen estrechos, que lo navegable va sobre todo por tierra baja y que están sus nombres.
- `python tools/world/paint_relieve_autor.py` (Pillow; después de `paint_afluentes.py`) pinta Larr (`LARR_ROWS` filas de cumbre en el borde norte y `FOOT_ROWS` de nivel 2 debajo; corta el agua y los caminos que hubiera encima), la cordillera occidental (`x < STRIP_W`, `LARR_ROWS <= y < STRIP_END`: cumbre → nivel 3, nivel 0 → 1), la fila `villa_azhin` de `lugares.csv` y su camino (`AZHIN_ROAD`, se para si pisa una cumbre o no toca la red). Idempotente. Tests en `tests/unit/world/test_region_authoring.gd` (mismas constantes): Larr continua (ninguna celda del borde norte se pisa), ninguna cumbre ni nivel 0 en la franja y se cruza a pie de oeste a este en cada fila de chunks, Azhin es villa, la más septentrional, al pie de Larr y accesible, y la red de agua del plan sigue conexa en las seeds 7, 15 y 42.
