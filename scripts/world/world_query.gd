class_name WorldQuery
extends RefCounted
## Consulta pura de un rectángulo de `world_cell` del Mundo 2.0 (pedida por el combate táctico,
## ADR 0016): por casilla, nivel, si bloquea, escalera o rampa, agua o vado y el objeto que la
## tapa. Cruza los bordes de chunk con WorldCoords y lee los WorldChunk que le da `get_chunk`.
## No genera chunks, no guarda referencias a ellos y no toca la escena: se puede llamar desde un
## hilo si `get_chunk` también se puede.
##
## Uso:
##   var area := WorldQuery.rect(func(c: Vector2i) -> WorldChunk: return streamer.chunk(c), origin, size)
##   var cell: Dictionary = area.at(origin + Vector2i(3, 2))

## Paso entre niveles de la casilla.
enum Crossing { NONE, STAIRS, RAMP }
## Agua de la casilla: honda (río, lago, mar: bloquea), vado (se pisa) o puente sobre el agua.
enum Water { NONE, DEEP, FORD, BRIDGE }

## Capas de un rectángulo, fila a fila (índice = y * size.x + x, relativo a `origin`).
class Area extends RefCounted:
	var origin: Vector2i = Vector2i.ZERO
	var size: Vector2i = Vector2i.ZERO
	## 1 si el chunk de la casilla existía (get_chunk no devolvió null). Si no, la casilla bloquea.
	var loaded := PackedByteArray()
	var level := PackedByteArray()
	var blocked := PackedByteArray()
	## WorldChunk.Ground y WorldChunk.Cliff tal cual, por si hace falta más detalle.
	var ground := PackedByteArray()
	var cliff := PackedByteArray()
	var crossing := PackedByteArray() # Crossing
	var water := PackedByteArray() # Water
	## WorldChunk.ObjectKind del objeto que tapa la casilla, o -1.
	var object_kind := PackedInt32Array()

	func has(world_cell: Vector2i) -> bool:
		return Rect2i(origin, size).has_point(world_cell)

	## Índice de la casilla en las capas, o -1 si cae fuera del rectángulo.
	func index(world_cell: Vector2i) -> int:
		if not has(world_cell):
			return -1
		var local: Vector2i = world_cell - origin
		return local.y * size.x + local.x

	## Todo lo de una casilla: {level, blocked, ground, cliff, crossing, water, object, loaded}, o {}
	## si cae fuera.
	func at(world_cell: Vector2i) -> Dictionary:
		var i: int = index(world_cell)
		if i < 0:
			return {}
		return {
			"level": level[i], "blocked": blocked[i] == 1, "ground": ground[i], "cliff": cliff[i],
			"crossing": crossing[i], "water": water[i], "object": object_kind[i], "loaded": loaded[i] == 1,
		}


## Capas del rectángulo de `size` casillas con esquina noroeste en `origin_world_cell`.
## `get_chunk`: Callable(chunk_coord: Vector2i) -> WorldChunk (o null si no existe o no está
## cargado). Se llama una vez por chunk que toca el rectángulo.
static func rect(get_chunk: Callable, origin_world_cell: Vector2i, size: Vector2i) -> Area:
	var area := Area.new()
	area.origin = origin_world_cell
	area.size = Vector2i(maxi(size.x, 0), maxi(size.y, 0))
	var n: int = area.size.x * area.size.y
	# Los Packed*Array se copian al iterarlos: cada capa se redimensiona por su nombre.
	area.loaded.resize(n)
	area.level.resize(n)
	area.blocked.resize(n)
	area.ground.resize(n)
	area.cliff.resize(n)
	area.crossing.resize(n)
	area.water.resize(n)
	area.object_kind.resize(n)
	area.object_kind.fill(WorldChunk.NO_OBJECT)
	area.blocked.fill(1)
	if n == 0:
		return area
	var first: Vector2i = WorldCoords.world_cell_to_chunk(origin_world_cell)
	var last: Vector2i = WorldCoords.world_cell_to_chunk(origin_world_cell + area.size - Vector2i.ONE)
	for cy: int in range(first.y, last.y + 1):
		for cx: int in range(first.x, last.x + 1):
			var coord := Vector2i(cx, cy)
			var chunk: WorldChunk = get_chunk.call(coord)
			if chunk == null:
				continue
			var base: Vector2i = coord * WorldCoords.CHUNK
			var r: Rect2i = Rect2i(base, Vector2i(WorldCoords.CHUNK, WorldCoords.CHUNK)).intersection(Rect2i(area.origin, area.size))
			for wy: int in range(r.position.y, r.end.y):
				for wx: int in range(r.position.x, r.end.x):
					var ci: int = (wy - base.y) * WorldCoords.CHUNK + (wx - base.x)
					var i: int = (wy - area.origin.y) * area.size.x + (wx - area.origin.x)
					_fill(area, i, chunk, ci)
	return area


static func _fill(area: Area, i: int, chunk: WorldChunk, ci: int) -> void:
	area.loaded[i] = 1
	area.level[i] = chunk.level[ci]
	area.blocked[i] = chunk.blocked[ci]
	var g: int = chunk.ground[ci]
	var c: int = chunk.cliff[ci]
	area.ground[i] = g
	area.cliff[i] = c
	area.crossing[i] = Crossing.STAIRS if c == WorldChunk.Cliff.STAIRS else (Crossing.RAMP if c == WorldChunk.Cliff.RAMP else Crossing.NONE)
	if g == WorldChunk.Ground.FORD:
		area.water[i] = Water.FORD
	elif g == WorldChunk.Ground.BRIDGE:
		area.water[i] = Water.BRIDGE
	elif WorldChunk.is_ground_blocking(g):
		area.water[i] = Water.DEEP
	var occ: int = chunk.occupant[ci]
	if occ != WorldChunk.NO_OBJECT:
		area.object_kind[i] = chunk.objects[occ].kind
