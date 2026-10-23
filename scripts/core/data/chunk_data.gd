class_name ChunkData
extends Resource
## Chunk generado: 64x64 tiles (ADR 0004). Escala: chunk < Bosque < área < región.
## Lo produce ChunkGenerator (ADR 0006); el resto de sistemas solo lo leen.

## Bloquean el paso: TREE (un árbol por casilla), CLIFF (riscos y pendientes), los dos ríos,
## BUILDING (edificios de la villa) y NUJIO (el árbol enorme del Bosque).
## RIVER_NAVIGABLE = "rio_navegable" (bloquea a pie hasta que haya navegación);
## RIVER_NARROW = "rio_estrecho" (nunca navegable). FORD = vado; SIGN = letrero de piedra.
enum Tile {
	GRASS, CLEARING, PATH, TREE, ROCKY, CLIFF, RIVER_NARROW, RIVER_NAVIGABLE, BRIDGE, FORD,
	PLAZA, BUILDING, SIGN, NUJIO,
}

const SIZE: int = 64
## Bordes del chunk, como dirección hacia fuera.
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const BLOCKING: Array[int] = [Tile.TREE, Tile.CLIFF, Tile.RIVER_NARROW, Tile.RIVER_NAVIGABLE, Tile.BUILDING, Tile.NUJIO]

@export var seed_value: int = 0
@export var coord: Vector2i = Vector2i.ZERO
## Un byte por tile (ChunkData.Tile), fila a fila.
@export var tiles: PackedByteArray = PackedByteArray()
## Casilla transitable a la que llegan todos los senderos (aparición y cálculo de accesibilidad).
@export var hub: Vector2i = Vector2i(SIZE / 2, SIZE / 2)
## Huella del Nujio en este chunk (tamaño 0 si no lo hay).
@export var nujio_rect: Rect2i = Rect2i()
## Este chunk contiene la villa de su Bosque.
@export var has_villa: bool = false

var _reachable: PackedByteArray = PackedByteArray()


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE


static func center() -> Vector2i:
	return Vector2i(SIZE / 2, SIZE / 2)


## Casilla número `index` del borde `side` (LEFT/RIGHT recorren filas, UP/DOWN columnas).
static func border_cell(side: Vector2i, index: int) -> Vector2i:
	if side == Vector2i.LEFT:
		return Vector2i(0, index)
	if side == Vector2i.RIGHT:
		return Vector2i(SIZE - 1, index)
	if side == Vector2i.UP:
		return Vector2i(index, 0)
	return Vector2i(index, SIZE - 1)


func get_tile(cell: Vector2i) -> int:
	return tiles[cell.y * SIZE + cell.x]


func set_tile(cell: Vector2i, tile: int) -> void:
	tiles[cell.y * SIZE + cell.x] = tile
	_reachable = PackedByteArray()


func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return is_walkable_tile(get_tile(cell))


static func is_walkable_tile(tile: int) -> bool:
	return not BLOCKING.has(tile)


static func is_river(tile: int) -> bool:
	return tile == Tile.RIVER_NARROW or tile == Tile.RIVER_NAVIGABLE


## 1 por cada casilla a la que se llega andando desde el hub.
func reachable_from_hub() -> PackedByteArray:
	if not _reachable.is_empty():
		return _reachable
	_reachable.resize(SIZE * SIZE)
	_reachable.fill(0)
	if not is_walkable(hub):
		return _reachable
	var queue: Array[Vector2i] = [hub]
	_reachable[hub.y * SIZE + hub.x] = 1
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for dir: Vector2i in SIDES:
			var next: Vector2i = cell + dir
			if is_walkable(next) and _reachable[next.y * SIZE + next.x] == 0:
				_reachable[next.y * SIZE + next.x] = 1
				queue.append(next)
	return _reachable


func is_reachable(cell: Vector2i) -> bool:
	return in_bounds(cell) and reachable_from_hub()[cell.y * SIZE + cell.x] == 1


## Casilla donde aparece el jugador al entrar por el borde `side` a la altura `along`.
## Si esa casilla es transitable se respeta (continuidad); si no, la transitable y accesible
## desde el hub más cercana del mismo borde.
func find_entry(side: Vector2i, along: int) -> Vector2i:
	var wanted: Vector2i = border_cell(side, clampi(along, 0, SIZE - 1))
	if is_walkable(wanted):
		return wanted
	var best: Vector2i = hub
	var best_score: int = 1 << 30
	for i: int in SIZE:
		var cell: Vector2i = border_cell(side, i)
		if not is_walkable(cell):
			continue
		var score: int = absi(i - along) + (0 if is_reachable(cell) else SIZE)
		if score < best_score:
			best_score = score
			best = cell
	return best
