class_name ChunkData
extends Resource
## Chunk (zona) generado: 64x64 tiles (ADR 0004). Lo produce ChunkGenerator (ADR 0006);
## el resto de sistemas solo lo leen.

enum Tile { GRASS, CLEARING, PATH, TREE, WATER }

const SIZE: int = 64
## Bordes del chunk, como dirección hacia fuera.
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

@export var seed_value: int = 0
@export var coord: Vector2i = Vector2i.ZERO
## Un byte por tile (ChunkData.Tile), fila a fila.
@export var tiles: PackedByteArray = PackedByteArray()

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
	var tile: int = get_tile(cell)
	return tile != Tile.TREE and tile != Tile.WATER


## 1 por cada casilla a la que se llega andando desde el centro.
func reachable_from_center() -> PackedByteArray:
	if not _reachable.is_empty():
		return _reachable
	_reachable.resize(SIZE * SIZE)
	_reachable.fill(0)
	var start: Vector2i = center()
	if not is_walkable(start):
		return _reachable
	var queue: Array[Vector2i] = [start]
	_reachable[start.y * SIZE + start.x] = 1
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
	return in_bounds(cell) and reachable_from_center()[cell.y * SIZE + cell.x] == 1


## Casilla donde aparece el jugador al entrar por el borde `side` a la altura `along`.
## Si esa casilla es transitable se respeta (continuidad); si no, la transitable y accesible
## desde el centro más cercana del mismo borde.
func find_entry(side: Vector2i, along: int) -> Vector2i:
	var wanted: Vector2i = border_cell(side, clampi(along, 0, SIZE - 1))
	if is_walkable(wanted):
		return wanted
	var best: Vector2i = center()
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
