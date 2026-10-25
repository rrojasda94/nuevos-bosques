class_name WorldCoords
extends RefCounted
## Escala y conversiones de coordenadas del Mundo 2.0 (ADR 0014 §1, CONVENCIONES §6).
## Clase pura, solo estáticas. Fuera de aquí no se escriben `* 16`, `* 80` ni `/ 4` sueltos.
##
## - `chunk` (Vector2i): coordenada del chunk en la región.
## - `cell` (Vector2i): casilla dentro del chunk, 0..CHUNK-1.
## - `world_cell` (Vector2i): casilla global de la región, `chunk * CHUNK + cell`.
## - `world_pos` (Vector2): posición en píxeles de los pies; su casilla es `floor(world_pos / TILE)`.
## - `sector`: bloque de SECTOR×SECTOR casillas (dibujo y streaming).
## - `macro`: celda gruesa de MACRO×MACRO casillas (relieve y autoría).
## Todas las divisiones redondean hacia abajo (también con negativos): -1 está en el chunk -1.
## Las funciones de sector y macro valen tanto para `cell` como para `world_cell`.

## Píxeles por casilla.
const TILE: int = 16
## Casillas por lado de un chunk.
const CHUNK: int = 80
## Casillas por lado de un sector.
const SECTOR: int = 16
## Casillas por lado de una celda gruesa.
const MACRO: int = 4
## Casillas de un chunk.
const CHUNK_CELLS: int = CHUNK * CHUNK
## Sectores por lado de un chunk (5).
const SECTORS_PER_CHUNK: int = CHUNK / SECTOR
## Celdas gruesas por lado de un chunk (20).
const MACROS_PER_CHUNK: int = CHUNK / MACRO
## Píxeles por lado de un chunk.
const CHUNK_PX: int = CHUNK * TILE


## División entera hacia abajo (`floor(a / b)`), correcta con `a` negativo. `b` > 0.
static func floor_div(a: int, b: int) -> int:
	return (a - posmod(a, b)) / b


static func floor_div_v(v: Vector2i, b: int) -> Vector2i:
	return Vector2i(floor_div(v.x, b), floor_div(v.y, b))


static func posmod_v(v: Vector2i, b: int) -> Vector2i:
	return Vector2i(posmod(v.x, b), posmod(v.y, b))


# --- chunk + cell <-> world_cell ---

static func to_world_cell(chunk: Vector2i, cell: Vector2i) -> Vector2i:
	return chunk * CHUNK + cell


static func world_cell_to_chunk(world_cell: Vector2i) -> Vector2i:
	return floor_div_v(world_cell, CHUNK)


## Casilla dentro de su chunk (siempre 0..CHUNK-1).
static func world_cell_to_cell(world_cell: Vector2i) -> Vector2i:
	return posmod_v(world_cell, CHUNK)


# --- world_cell <-> world_pos ---

## Casilla lógica de una posición (la de los pies).
static func world_pos_to_world_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))


## Esquina superior izquierda de la casilla, en píxeles.
static func world_cell_origin(world_cell: Vector2i) -> Vector2:
	return Vector2(world_cell * TILE)


## Centro de la casilla, en píxeles: donde se ponen los pies al aparecer o al cargar.
static func world_cell_to_world_pos(world_cell: Vector2i) -> Vector2:
	return Vector2(world_cell * TILE) + Vector2(TILE, TILE) * 0.5


static func world_pos_to_chunk(world_pos: Vector2) -> Vector2i:
	return world_cell_to_chunk(world_pos_to_world_cell(world_pos))


static func world_pos_to_cell(world_pos: Vector2) -> Vector2i:
	return world_cell_to_cell(world_pos_to_world_cell(world_pos))


## Posición de los pies en el centro de `cell` del chunk `chunk`.
static func cell_to_world_pos(chunk: Vector2i, cell: Vector2i) -> Vector2:
	return world_cell_to_world_pos(to_world_cell(chunk, cell))


# --- sector y macro ---

static func cell_to_sector(cell: Vector2i) -> Vector2i:
	return floor_div_v(cell, SECTOR)


## Primera casilla (esquina superior izquierda) del sector.
static func sector_origin(sector: Vector2i) -> Vector2i:
	return sector * SECTOR


static func cell_to_macro(cell: Vector2i) -> Vector2i:
	return floor_div_v(cell, MACRO)


## Primera casilla (esquina superior izquierda) de la celda gruesa.
static func macro_origin(macro: Vector2i) -> Vector2i:
	return macro * MACRO


# --- índices en las capas del chunk ---

static func in_chunk(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < CHUNK and cell.y < CHUNK


## Índice de `cell` en las capas de un chunk (fila a fila). `cell` debe estar dentro.
static func cell_index(cell: Vector2i) -> int:
	return cell.y * CHUNK + cell.x


static func index_to_cell(index: int) -> Vector2i:
	return Vector2i(index % CHUNK, index / CHUNK)
