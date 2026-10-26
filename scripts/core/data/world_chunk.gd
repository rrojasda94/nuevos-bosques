class_name WorldChunk
extends RefCounted
## Chunk del Mundo 2.0 en capas (ADR 0014 §5 "Datos del chunk"): 80×80 casillas. Sustituirá a
## ChunkData (64×64, un solo byte por casilla) cuando llegue el ChunkBuilder (M5–M9); hasta
## entonces conviven y nadie del juego lo usa todavía.
##
## Lo escribe el ChunkBuilder en un hilo y después solo se lee. Por eso es RefCounted y no
## Resource: sin nodos, sin señales, y se serializa con to_dict/from_dict a tipos simples para la
## caché de M10 (`var_to_bytes` sin objetos).
##
## Capas (PackedByteArray de CELLS, fila a fila; índice = WorldCoords.cell_index(cell)):
## - `ground`: suelo (Ground). - `level`: nivel de relieve 0..MAX_LEVEL.
## - `cliff`: risco (Cliff). - `decor`: decoración plana que nunca bloquea (0 = nada; el catálogo
##   es de pixel-artist/world-gen-dev). - `variant`: variante de dibujo del suelo.
## - `blocked`: 1 si la casilla no se puede pisar. Es derivada: la rellena rebuild_blocked().
## `occupant` (PackedInt32Array): índice en `objects` del objeto que tapa la casilla, o -1.
##
## Los enums son provisionales y se amplían añadiendo valores AL FINAL (la caché guarda bytes).
## Cambiar su orden obliga a subir FORMAT_VERSION.

## Suelo de la casilla. Los ríos, el lago y el mar bloquean a pie.
enum Ground {
	GRASS, CLEARING, PATH, ROAD, ROCKY, PLAZA, BRIDGE, FORD, RIVER_NARROW, RIVER_NAVIGABLE, LAKE, SEA,
}
## Risco de la casilla (ADR 0014 §3). Las caras, los bordes y las cascadas bloquean; las escaleras
## (cruzan una cara) y las rampas (cruzan un borde) son el único paso entre niveles.
enum Cliff { NONE, FACE, EDGE, STAIRS, RAMP, WATERFALL }
## Objetos de una o varias casillas. Bloquean todos salvo los refugios (el jugador se mete dentro).
enum ObjectKind {
	TREE, TREE_YOUNG, TREE_BIG, TREE_DEAD, FRUIT_TREE, ROCK, STUMP, LOG, HOUSE, NUJIO, SIGN,
	REFUGE_TREE, CAVE, LANDMARK,
}
## Tipos de letrero (mismos valores que ChunkData.SignKind).
enum SignKind { BOSQUE_VILLA, HOME_VILLA }
## Puntos de interés (mundo-2.md §4). POINT_IDS da el id de datos de cada uno.
enum PointKind { HILL, LANDMARK_TREE, STONE_CIRCLE, GROVE, POND, MEADOW, PLACE }

const SIZE: int = WorldCoords.CHUNK
const CELLS: int = WorldCoords.CHUNK_CELLS
const MAX_LEVEL: int = 3
const NO_OBJECT: int = -1
## Versión del formato de to_dict. Súbela si cambian las capas, los enums o las claves.
const FORMAT_VERSION: int = 2
## Bordes del chunk, como dirección hacia fuera.
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## Tablas de bloqueo como máscaras de bits (bit n = el valor n del enum bloquea).
const GROUND_BLOCKING: int = (1 << Ground.RIVER_NARROW) | (1 << Ground.RIVER_NAVIGABLE) \
		| (1 << Ground.LAKE) | (1 << Ground.SEA)
const CLIFF_BLOCKING: int = (1 << Cliff.FACE) | (1 << Cliff.EDGE) | (1 << Cliff.WATERFALL)
const OBJECT_BLOCKING: int = (1 << ObjectKind.TREE) | (1 << ObjectKind.TREE_YOUNG) \
		| (1 << ObjectKind.TREE_BIG) | (1 << ObjectKind.TREE_DEAD) | (1 << ObjectKind.FRUIT_TREE) \
		| (1 << ObjectKind.ROCK) | (1 << ObjectKind.STUMP) | (1 << ObjectKind.LOG) \
		| (1 << ObjectKind.HOUSE) | (1 << ObjectKind.NUJIO) | (1 << ObjectKind.SIGN) \
		| (1 << ObjectKind.LANDMARK)

## Claves de las capas de bytes en to_dict.
const LAYER_KEYS: Array[String] = ["ground", "level", "cliff", "decor", "blocked", "variant"]
## Campos por objeto en la serialización plana: kind, cell.x, cell.y, size.x, size.y, variant.
const _OBJECT_STRIDE: int = 6
## Campos por letrero: cell.x, cell.y, kind, direction.x, direction.y.
const _SIGN_STRIDE: int = 5
## Campos por punto de interés: kind, rect (x, y, w, h), cell.x, cell.y.
const _POINT_STRIDE: int = 7
## Id de datos (`points_of_interest.weights` de la región) de cada PointKind.
const POINT_IDS: Array[String] = ["colina", "hito", "circulo_piedras", "arboleda", "laguna", "pradera", "lugar"]

var seed_value: int = 0
var coord: Vector2i = Vector2i.ZERO
var ground: PackedByteArray = PackedByteArray()
var level: PackedByteArray = PackedByteArray()
var cliff: PackedByteArray = PackedByteArray()
var decor: PackedByteArray = PackedByteArray()
var blocked: PackedByteArray = PackedByteArray()
var variant: PackedByteArray = PackedByteArray()
var occupant: PackedInt32Array = PackedInt32Array()
## Objetos en orden de colocación: {kind: int, cell: Vector2i (esquina sup. izq.), size: Vector2i,
## variant: int}. El índice en esta lista es el valor de `occupant`.
var objects: Array[Dictionary] = []
## Letreros: {cell: Vector2i, kind: SignKind, direction: Vector2i (lado hacia el que señala)}.
## Cada letrero es además un objeto SIGN de 1×1 en su casilla.
var signs: Array[Dictionary] = []
## Puntos de interés: {kind: PointKind, rect: Rect2i (huella en casillas), cell: Vector2i (casilla
## del sendero que llega a él)}. Los lugares del CSV que caen en el chunk también están aquí.
var points: Array[Dictionary] = []
## Casilla transitable a la que llegan todos los senderos (aparición y accesibilidad).
var hub: Vector2i = Vector2i(SIZE / 2, SIZE / 2)
## Huella del Nujio en este chunk (tamaño 0 si no lo hay).
var nujio_rect: Rect2i = Rect2i()
## Este chunk contiene la villa de su Bosque.
var has_villa: bool = false

var _reachable: PackedByteArray = PackedByteArray()


func _init() -> void:
	ground.resize(CELLS)
	level.resize(CELLS)
	cliff.resize(CELLS)
	decor.resize(CELLS)
	blocked.resize(CELLS)
	variant.resize(CELLS)
	occupant.resize(CELLS)
	occupant.fill(NO_OBJECT)


static func in_bounds(cell: Vector2i) -> bool:
	return WorldCoords.in_chunk(cell)


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


static func is_ground_blocking(value: int) -> bool:
	return (GROUND_BLOCKING >> value) & 1 == 1


static func is_cliff_blocking(value: int) -> bool:
	return (CLIFF_BLOCKING >> value) & 1 == 1


static func is_object_blocking(kind: int) -> bool:
	return (OBJECT_BLOCKING >> kind) & 1 == 1


# --- capas por casilla (cell debe estar dentro; compruébalo con in_bounds) ---

func get_ground(cell: Vector2i) -> int:
	return ground[WorldCoords.cell_index(cell)]


func set_ground(cell: Vector2i, value: int) -> void:
	ground[WorldCoords.cell_index(cell)] = value


func get_level(cell: Vector2i) -> int:
	return level[WorldCoords.cell_index(cell)]


func set_level(cell: Vector2i, value: int) -> void:
	level[WorldCoords.cell_index(cell)] = clampi(value, 0, MAX_LEVEL)


func get_cliff(cell: Vector2i) -> int:
	return cliff[WorldCoords.cell_index(cell)]


func set_cliff(cell: Vector2i, value: int) -> void:
	cliff[WorldCoords.cell_index(cell)] = value


func get_decor(cell: Vector2i) -> int:
	return decor[WorldCoords.cell_index(cell)]


func set_decor(cell: Vector2i, value: int) -> void:
	decor[WorldCoords.cell_index(cell)] = value


func get_variant(cell: Vector2i) -> int:
	return variant[WorldCoords.cell_index(cell)]


func set_variant(cell: Vector2i, value: int) -> void:
	variant[WorldCoords.cell_index(cell)] = value


func is_blocked(cell: Vector2i) -> bool:
	return not in_bounds(cell) or blocked[WorldCoords.cell_index(cell)] == 1


func is_walkable(cell: Vector2i) -> bool:
	return not is_blocked(cell)


# --- objetos ---

## Coloca un objeto con su esquina superior izquierda en `cell`. Devuelve su índice, o -1 si se
## sale del chunk o pisa otro objeto (en ese caso no cambia nada). No toca `blocked`: llama a
## rebuild_blocked() al terminar de colocar.
func add_object(kind: int, cell: Vector2i, size: Vector2i = Vector2i.ONE, object_variant: int = 0) -> int:
	if size.x < 1 or size.y < 1 or not in_bounds(cell) or not in_bounds(cell + size - Vector2i.ONE):
		return NO_OBJECT
	for y: int in range(cell.y, cell.y + size.y):
		var row: int = y * SIZE
		for x: int in range(cell.x, cell.x + size.x):
			if occupant[row + x] != NO_OBJECT:
				return NO_OBJECT
	var index: int = objects.size()
	objects.append({"kind": kind, "cell": cell, "size": size, "variant": object_variant})
	for y: int in range(cell.y, cell.y + size.y):
		var row: int = y * SIZE
		for x: int in range(cell.x, cell.x + size.x):
			occupant[row + x] = index
	_reachable = PackedByteArray()
	return index


func object_index_at(cell: Vector2i) -> int:
	return occupant[WorldCoords.cell_index(cell)] if in_bounds(cell) else NO_OBJECT


## Objeto que tapa la casilla (desde cualquiera de sus casillas), o {} si no hay.
func object_at(cell: Vector2i) -> Dictionary:
	var index: int = object_index_at(cell)
	return objects[index] if index != NO_OBJECT else {}


## Objetos de un tipo, en orden de colocación (p. ej. los frutales o los refugios).
func objects_of(kind: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for obj: Dictionary in objects:
		if obj.kind == kind:
			out.append(obj)
	return out


# --- letreros ---

## Pone un letrero en `cell` (un objeto SIGN de 1×1) que señala hacia `direction`. Devuelve
## false si la casilla no está libre.
func add_sign(cell: Vector2i, kind: int, direction: Vector2i = Vector2i.ZERO) -> bool:
	if add_object(ObjectKind.SIGN, cell) == NO_OBJECT:
		return false
	signs.append({"cell": cell, "kind": kind, "direction": direction})
	return true


## Letrero de la casilla, o {} si no hay.
func sign_at(cell: Vector2i) -> Dictionary:
	for s: Dictionary in signs:
		if s.cell == cell:
			return s
	return {}


# --- colisión derivada y accesibilidad ---

## Rehace `blocked` a partir del suelo, los riscos y los objetos, con las máscaras de bloqueo.
func rebuild_blocked() -> void:
	var object_blocks := PackedByteArray()
	object_blocks.resize(objects.size())
	for i: int in objects.size():
		object_blocks[i] = 1 if is_object_blocking(objects[i].kind) else 0
	for i: int in CELLS:
		var b: int = ((GROUND_BLOCKING >> ground[i]) | (CLIFF_BLOCKING >> cliff[i])) & 1
		var occ: int = occupant[i]
		if occ != NO_OBJECT:
			b |= object_blocks[occ]
		blocked[i] = b
	_reachable = PackedByteArray()


## 1 por cada casilla a la que se llega andando desde el hub (según `blocked`).
func reachable_from_hub() -> PackedByteArray:
	if not _reachable.is_empty():
		return _reachable
	_reachable.resize(CELLS)
	_reachable.fill(0)
	if is_blocked(hub):
		return _reachable
	var queue := PackedInt32Array()
	queue.resize(CELLS)
	var start: int = WorldCoords.cell_index(hub)
	queue[0] = start
	_reachable[start] = 1
	var head: int = 0
	var tail: int = 1
	while head < tail:
		var i: int = queue[head]
		head += 1
		var x: int = i % SIZE
		if x > 0:
			tail = _visit(i - 1, queue, tail)
		if x < SIZE - 1:
			tail = _visit(i + 1, queue, tail)
		if i >= SIZE:
			tail = _visit(i - SIZE, queue, tail)
		if i < CELLS - SIZE:
			tail = _visit(i + SIZE, queue, tail)
	return _reachable


func _visit(i: int, queue: PackedInt32Array, tail: int) -> int:
	if blocked[i] == 0 and _reachable[i] == 0:
		_reachable[i] = 1
		queue[tail] = i
		return tail + 1
	return tail


func is_reachable(cell: Vector2i) -> bool:
	return in_bounds(cell) and reachable_from_hub()[WorldCoords.cell_index(cell)] == 1


# --- serialización (caché de M10) ---

## Solo tipos simples: enteros, Vector2i, Rect2i y Packed*Array, para `var_to_bytes` sin objetos.
## `occupant` no se guarda: se rehace desde `objects`. Mismo chunk = mismos bytes.
func to_dict() -> Dictionary:
	var flat_objects := PackedInt32Array()
	flat_objects.resize(objects.size() * _OBJECT_STRIDE)
	var o: int = 0
	for obj: Dictionary in objects:
		var cell: Vector2i = obj.cell
		var size: Vector2i = obj.size
		flat_objects[o] = obj.kind
		flat_objects[o + 1] = cell.x
		flat_objects[o + 2] = cell.y
		flat_objects[o + 3] = size.x
		flat_objects[o + 4] = size.y
		flat_objects[o + 5] = obj.variant
		o += _OBJECT_STRIDE
	var flat_signs := PackedInt32Array()
	flat_signs.resize(signs.size() * _SIGN_STRIDE)
	var s: int = 0
	for sign_data: Dictionary in signs:
		var cell: Vector2i = sign_data.cell
		var dir: Vector2i = sign_data.direction
		flat_signs[s] = cell.x
		flat_signs[s + 1] = cell.y
		flat_signs[s + 2] = sign_data.kind
		flat_signs[s + 3] = dir.x
		flat_signs[s + 4] = dir.y
		s += _SIGN_STRIDE
	var flat_points := PackedInt32Array()
	for p: Dictionary in points:
		var r: Rect2i = p.rect
		var pc: Vector2i = p.cell
		flat_points.append_array(PackedInt32Array([p.kind, r.position.x, r.position.y, r.size.x, r.size.y, pc.x, pc.y]))
	return {
		"format": FORMAT_VERSION,
		"seed": seed_value,
		"coord": coord,
		"ground": ground,
		"level": level,
		"cliff": cliff,
		"decor": decor,
		"blocked": blocked,
		"variant": variant,
		"objects": flat_objects,
		"signs": flat_signs,
		"points": flat_points,
		"hub": hub,
		"nujio_rect": nujio_rect,
		"has_villa": has_villa,
	}


## Rehace un chunk desde to_dict(). Devuelve null si el formato no es el actual o los datos no
## cuadran (la caché lo trata como "falta" y regenera).
static func from_dict(data: Dictionary) -> WorldChunk:
	if int(data.get("format", -1)) != FORMAT_VERSION:
		return null
	var chunk := WorldChunk.new()
	for key: String in LAYER_KEYS:
		var layer: Variant = data.get(key)
		if not layer is PackedByteArray or (layer as PackedByteArray).size() != CELLS:
			return null
	chunk.seed_value = int(data.get("seed", 0))
	chunk.coord = data.get("coord", Vector2i.ZERO)
	chunk.ground = data.ground
	chunk.level = data.level
	chunk.cliff = data.cliff
	chunk.decor = data.decor
	chunk.blocked = data.blocked
	chunk.variant = data.variant
	chunk.hub = data.get("hub", center())
	chunk.nujio_rect = data.get("nujio_rect", Rect2i())
	chunk.has_villa = bool(data.get("has_villa", false))
	var flat_objects: PackedInt32Array = data.get("objects", PackedInt32Array())
	if flat_objects.size() % _OBJECT_STRIDE != 0:
		return null
	for o: int in range(0, flat_objects.size(), _OBJECT_STRIDE):
		var placed: int = chunk.add_object(flat_objects[o],
				Vector2i(flat_objects[o + 1], flat_objects[o + 2]),
				Vector2i(flat_objects[o + 3], flat_objects[o + 4]), flat_objects[o + 5])
		if placed == NO_OBJECT:
			return null
	var flat_signs: PackedInt32Array = data.get("signs", PackedInt32Array())
	if flat_signs.size() % _SIGN_STRIDE != 0:
		return null
	for s: int in range(0, flat_signs.size(), _SIGN_STRIDE):
		chunk.signs.append({
			"cell": Vector2i(flat_signs[s], flat_signs[s + 1]),
			"kind": flat_signs[s + 2],
			"direction": Vector2i(flat_signs[s + 3], flat_signs[s + 4]),
		})
	var flat_points: PackedInt32Array = data.get("points", PackedInt32Array())
	if flat_points.size() % _POINT_STRIDE != 0:
		return null
	for k: int in range(0, flat_points.size(), _POINT_STRIDE):
		chunk.points.append({
			"kind": flat_points[k],
			"rect": Rect2i(flat_points[k + 1], flat_points[k + 2], flat_points[k + 3], flat_points[k + 4]),
			"cell": Vector2i(flat_points[k + 5], flat_points[k + 6]),
		})
	return chunk
