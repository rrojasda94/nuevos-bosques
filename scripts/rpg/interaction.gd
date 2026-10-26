class_name Interaction
extends RefCounted
## Qué hay al pulsar interact (E) en exploración (navegacion.md, mision-ofomni.md): un NPC, un
## letrero, un refugio, un frutal (FruitRules; bloquea, así que solo se toma desde delante) o el
## Nujio (bloquea: se le dejan ofrendas desde delante, bosques-y-relacion.md). Mira primero la casilla de delante (cell + facing) y luego la propia,
## porque sobre los letreros y los refugios también se puede estar de pie. Si no hay nada de eso y
## el Adoc está en un lugar de descanso de una villa (su plaza o junto a su Nujio), REST: ahí se
## puede dormir (SleepRules).
##
## Mundo 2.0 (ADR 0014 §2, movimiento libre): find_world() busca con un punto de sondeo delante
## de los pies (pies + facing × probe_px) y encuentra los objetos de varias casillas (frutal 2×2,
## árbol hueco, cueva, Nujio) desde cualquiera de sus casillas por `WorldChunk.occupant`.
## Lógica pura: no dibuja ni abre diálogos; la usa la exploración y los tests.

enum Kind { NONE, NPC, SIGN, REFUGE, FRUIT_TREE, NUJIO, REST }

## Tipo de interacción de cada WorldChunk.ObjectKind (los que no están no se usan con E).
const OBJECT_KINDS: Dictionary = {
	WorldChunk.ObjectKind.SIGN: Kind.SIGN,
	WorldChunk.ObjectKind.REFUGE_TREE: Kind.REFUGE,
	WorldChunk.ObjectKind.CAVE: Kind.REFUGE,
	WorldChunk.ObjectKind.FRUIT_TREE: Kind.FRUIT_TREE,
	WorldChunk.ObjectKind.NUJIO: Kind.NUJIO,
}
## Las 8 casillas de alrededor, en orden fijo (desempate del orden por distancia al sondeo).
const AROUND: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]


# ponytail: borrar en M17
static func target_cell(cell: Vector2i, facing: Vector2i) -> Vector2i:
	return cell + facing


## Objetivo de la interacción: { "kind": Kind, "cell": Vector2i, "npc_id": StringName }.
## `npcs`: casilla -> id de NPC del chunk actual.
# ponytail: borrar en M17 (lo sustituye find_world)
static func find(chunk: ChunkData, cell: Vector2i, facing: Vector2i, npcs: Dictionary) -> Dictionary:
	var ahead: Vector2i = target_cell(cell, facing)
	if npcs.has(ahead):
		return { "kind": Kind.NPC, "cell": ahead, "npc_id": npcs[ahead] }
	for c: Vector2i in [ahead, cell]:
		if not ChunkData.in_bounds(c):
			continue
		match chunk.get_tile(c):
			ChunkData.Tile.SIGN:
				return { "kind": Kind.SIGN, "cell": c, "npc_id": &"" }
			ChunkData.Tile.REFUGE:
				return { "kind": Kind.REFUGE, "cell": c, "npc_id": &"" }
			ChunkData.Tile.FRUIT_TREE:
				return { "kind": Kind.FRUIT_TREE, "cell": c, "npc_id": &"" }
			ChunkData.Tile.NUJIO:
				return { "kind": Kind.NUJIO, "cell": c, "npc_id": &"" }
	if AdventureRules.is_villa_rest(chunk, cell):
		return { "kind": Kind.REST, "cell": cell, "npc_id": &"" }
	return { "kind": Kind.NONE, "cell": ahead, "npc_id": &"" }


# --- Mundo 2.0 ----------------------------------------------------------------------------------

## Píxeles por delante de los pies del punto de sondeo (data/world/movement.json, probe_px).
static func probe_px() -> float:
	return float(MovementConfig.data().get("probe_px", 12))


## Distancia máxima (px) del sondeo a los pies de un NPC para hablar con él (npc_reach_px).
static func npc_reach_px() -> float:
	return float(MovementConfig.data().get("npc_reach_px", 14))


## Punto de sondeo: pies + facing × probe_px.
static func probe_point(world_pos: Vector2, facing: Vector2i) -> Vector2:
	return world_pos + Vector2(facing) * probe_px()


## Casillas globales donde se busca, en orden: la del sondeo, la de los pies y las 8 de alrededor
## del sondeo (de la más cercana al punto de sondeo a la más lejana; empates en el orden de AROUND).
static func probe_cells(world_pos: Vector2, facing: Vector2i) -> Array[Vector2i]:
	var probe: Vector2 = probe_point(world_pos, facing)
	var at: Vector2i = WorldCoords.world_pos_to_world_cell(probe)
	var feet: Vector2i = WorldCoords.world_pos_to_world_cell(world_pos)
	var out: Array[Vector2i] = [at]
	if feet != at:
		out.append(feet)
	var ring: Array[Vector2i] = []
	var scores: Dictionary = {}
	for k: int in AROUND.size():
		var c: Vector2i = at + AROUND[k]
		if c == feet:
			continue
		ring.append(c)
		scores[c] = Vector2(_dist_sq_to_cell(probe, c), k)
	ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var sa: Vector2 = scores[a]
		var sb: Vector2 = scores[b]
		return sa.x < sb.x or (sa.x == sb.x and sa.y < sb.y))
	out.append_array(ring)
	return out


## NPC con el que se habla: el más cercano al sondeo a ≤ npc_reach_px, con los pies en el semiplano
## de `facing` (estrictamente delante de los pies del Adoc). `npcs`: id (StringName) -> world_pos
## (Vector2, sus pies). Empate de distancia: el id menor. &"" si no hay.
static func npc_in_reach(world_pos: Vector2, facing: Vector2i, npcs: Dictionary) -> StringName:
	var probe: Vector2 = probe_point(world_pos, facing)
	var reach: float = npc_reach_px()
	var best: StringName = &""
	var best_d: float = INF
	for id: StringName in npcs:
		var pos: Vector2 = npcs[id]
		if (pos - world_pos).dot(Vector2(facing)) <= 0.0:
			continue
		var d: float = pos.distance_to(probe)
		if d > reach:
			continue
		if d < best_d or (d == best_d and str(id) < str(best)):
			best = id
			best_d = d
	return best


## La casilla `feet` (global) está dentro de `rect` (casillas globales) o en una de sus vecinas,
## también en diagonal: desde ahí se usa el objeto (el frutal "desde cualquier casilla vecina").
static func is_beside(rect: Rect2i, feet: Vector2i) -> bool:
	return rect.grow(1).has_point(feet)


## Objetivo de la interacción en el Mundo 2.0. `get_chunk`: Callable(coord: Vector2i) -> WorldChunk
## (o null si no está cargado). `world_pos`: los pies; `facing`: 4 direcciones. `npcs`: id ->
## world_pos (npc_in_reach). Devuelve { "kind": Kind, "cell": casilla global (la esquina noroeste
## del objeto; la del NPC; la de los pies en REST; la del sondeo en NONE), "chunk": coord del chunk,
## "local": `cell` dentro de su chunk, "object": índice en chunk.objects (-1 si no es un objeto),
## "npc_id": StringName }.
## Orden: NPC; objeto con E en probe_cells() del que los pies estén al lado (is_beside); descanso de
## villa en la casilla de los pies; NONE.
static func find_world(get_chunk: Callable, world_pos: Vector2, facing: Vector2i, npcs: Dictionary = {}) -> Dictionary:
	var feet: Vector2i = WorldCoords.world_pos_to_world_cell(world_pos)
	var npc: StringName = npc_in_reach(world_pos, facing, npcs)
	if npc != &"":
		return _target(Kind.NPC, WorldCoords.world_pos_to_world_cell(npcs[npc]), WorldChunk.NO_OBJECT, npc)
	var cells: Array[Vector2i] = probe_cells(world_pos, facing)
	for c: Vector2i in cells:
		var coord: Vector2i = WorldCoords.world_cell_to_chunk(c)
		var chunk: WorldChunk = get_chunk.call(coord)
		if chunk == null:
			continue
		var index: int = chunk.object_index_at(WorldCoords.world_cell_to_cell(c))
		if index == WorldChunk.NO_OBJECT:
			continue
		var obj: Dictionary = chunk.objects[index]
		var kind: int = OBJECT_KINDS.get(obj.kind, Kind.NONE)
		if kind == Kind.NONE:
			continue
		var origin: Vector2i = WorldCoords.to_world_cell(coord, obj.cell)
		if not is_beside(Rect2i(origin, obj.size), feet):
			continue
		return _target(kind, origin, index)
	var here: WorldChunk = get_chunk.call(WorldCoords.world_cell_to_chunk(feet))
	if here != null and AdventureRules.is_villa_rest_world(here, WorldCoords.world_cell_to_cell(feet)):
		return _target(Kind.REST, feet)
	return _target(Kind.NONE, cells[0])


static func _target(kind: int, world_cell: Vector2i, index: int = WorldChunk.NO_OBJECT,
		npc_id: StringName = &"") -> Dictionary:
	return {
		"kind": kind, "cell": world_cell, "chunk": WorldCoords.world_cell_to_chunk(world_cell),
		"local": WorldCoords.world_cell_to_cell(world_cell), "object": index, "npc_id": npc_id,
	}


## Distancia al cuadrado del punto `p` (px) a la casilla global `c`.
static func _dist_sq_to_cell(p: Vector2, c: Vector2i) -> float:
	var origin: Vector2 = WorldCoords.world_cell_origin(c)
	var q := Vector2(clampf(p.x, origin.x, origin.x + WorldCoords.TILE),
		clampf(p.y, origin.y, origin.y + WorldCoords.TILE))
	return p.distance_squared_to(q)
