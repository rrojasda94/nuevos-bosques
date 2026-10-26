class_name Signpost
extends RefCounted
## Lo que dice un letrero de piedra al leerlo con E (navegacion.md y pedido del dueño): la villa
## de destino (con su nombre provisional), hacia dónde queda y cuánto se tarda en llegar andando.
## Vale para los dos tipos de letrero (villa natal por el camino, villa del Bosque actual).
## Lógica pura: no dibuja; la usa la exploración y los tests. Textos en data/text/sistema.json y
## nombres en data/text/nombres_villas.json (narrative-writer).

const NAMES_PATH: String = "res://data/text/nombres_villas.json"
const SALT_VILLA_NAME: int = 31

static var _names: Array = []


## Nombre de la villa del Bosque, determinista por seed + id del Bosque.
static func villa_name(seed_value: int, bosque_id: int) -> String:
	if _names.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAMES_PATH))
		assert(data is Dictionary and not (data.get("villas", []) as Array).is_empty(), "No se pudo leer %s" % NAMES_PATH)
		_names = data.villas
	return str(_names[ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_VILLA_NAME]) % _names.size()])


## Segundos de reloj para recorrer `chunks` chunks andando: cada chunk son unas ChunkData.SIZE
## casillas a PlayerWalker.STEP_TIME segundos por casilla. No cuenta peajes ni combates.
# ponytail: borrar en M17 (lo sustituye travel_seconds_world)
static func travel_seconds(chunks: int) -> float:
	return chunks * ChunkData.SIZE * PlayerWalker.STEP_TIME


## Minutos de camino redondeados hacia arriba, mínimo 1 (navegacion.md).
# ponytail: borrar en M17 (lo sustituye travel_minutes_world)
static func travel_minutes(chunks: int) -> int:
	return minutes_of(travel_seconds(chunks))


## Minutos de `seconds` segundos de camino, redondeados hacia arriba, mínimo 1.
static func minutes_of(seconds: float) -> int:
	return maxi(1, ceili(seconds / 60.0))


## Destino del letrero `cell` del chunk: { "bosque_id", "delta" (dirección a señalar), "chunks" }.
## Letrero del camino: la villa natal, en la dirección del siguiente tramo y a los chunks de camino
## que faltan. Letrero de Bosque: la villa de ese Bosque, en línea recta.
# ponytail: borrar en M17 (lo sustituye destination_world)
static func destination(map: BosqueMap, chunk: ChunkData, cell: Vector2i, home_bosque: int) -> Dictionary:
	var to_home: bool = chunk.sign_kind(cell) == ChunkData.SignKind.HOME_VILLA
	var bosque_id: int = home_bosque if to_home else map.bosque_at(chunk.coord)
	var straight: Vector2i = map.nujio_chunk[bosque_id] - chunk.coord
	var chunks: int = absi(straight.x) + absi(straight.y)
	var delta: Vector2i = straight
	if to_home:
		if map.road_distance(chunk.coord) >= 0:
			chunks = map.road_distance(chunk.coord)
		if chunk.home_direction != Vector2i.ZERO:
			delta = chunk.home_direction
	return { "bosque_id": bosque_id, "delta": delta, "chunks": chunks, "to_home": to_home }


## Texto del letrero para un camino de `chunks` chunks. Si el camino dura más que lo que falta
## para el riutash (`seconds_to_riutash`, < 0 = no se sabe) se añade el aviso.
# ponytail: borrar en M17 (lo sustituye text_world)
static func text(villa: String, to_home: bool, delta: Vector2i, chunks: int, seconds_to_riutash: float = -1.0) -> String:
	return text_for_seconds(villa, to_home, delta, travel_seconds(chunks), seconds_to_riutash)


## Texto del letrero para un camino de `seconds` segundos andando (ver text()).
static func text_for_seconds(villa: String, to_home: bool, delta: Vector2i, seconds: float,
		seconds_to_riutash: float = -1.0) -> String:
	var key: String = "signpost_to_home_villa" if to_home else "signpost_to_villa"
	var out: String = Texts.get_text(key) % [villa, ChunkGenerator.direction_name(delta)]
	var minutes: int = minutes_of(seconds)
	if minutes == 1:
		out += " " + Texts.get_text("signpost_eta_one")
	else:
		out += " " + Texts.get_text("signpost_eta") % minutes
	if seconds_to_riutash >= 0.0 and seconds > seconds_to_riutash:
		out += " " + Texts.get_text("signpost_eta_riutash")
	return out


# --- Mundo 2.0 (WorldChunk, ADR 0014 §2 y mundo-2.md §2) ----------------------------------------
# El letrero es un objeto SIGN de 1×1 que bloquea, con su tipo y su dirección en WorldChunk.signs.
# Se lee al entrar en una casilla vecina (sign_entered, desde cell_changed) o con E (Interaction).

## Segundos de reloj para recorrer `chunks` chunks andando: casillas de camino × TILE / walk_speed
## (data/world/movement.json). No cuenta peajes ni combates.
static func travel_seconds_world(chunks: int) -> float:
	return chunks * WorldCoords.CHUNK * WorldCoords.TILE / MovementConfig.walk_speed()


static func travel_minutes_world(chunks: int) -> int:
	return minutes_of(travel_seconds_world(chunks))


## Destino del letrero de la casilla `cell` (dentro de `chunk`), como destination(): { "bosque_id",
## "delta", "chunks", "to_home" }. El del camino señala el lado de su `direction` (el siguiente
## tramo hacia casa); el de Bosque, la línea recta a su villa. {} si no hay letrero en `cell`.
static func destination_world(map: BosqueMap, chunk: WorldChunk, cell: Vector2i, home_bosque: int) -> Dictionary:
	var sign_data: Dictionary = chunk.sign_at(cell)
	if sign_data.is_empty():
		return {}
	var to_home: bool = sign_data.kind == WorldChunk.SignKind.HOME_VILLA
	var bosque_id: int = home_bosque if to_home else map.bosque_at(chunk.coord)
	var straight: Vector2i = map.nujio_chunk[bosque_id] - chunk.coord
	var chunks: int = absi(straight.x) + absi(straight.y)
	var delta: Vector2i = straight
	if to_home:
		if map.road_distance(chunk.coord) >= 0:
			chunks = map.road_distance(chunk.coord)
		if sign_data.direction != Vector2i.ZERO:
			delta = sign_data.direction
	return { "bosque_id": bosque_id, "delta": delta, "chunks": chunks, "to_home": to_home }


## Texto del letrero del Mundo 2.0 (tiempo con travel_seconds_world).
static func text_world(villa: String, to_home: bool, delta: Vector2i, chunks: int, seconds_to_riutash: float = -1.0) -> String:
	return text_for_seconds(villa, to_home, delta, travel_seconds_world(chunks), seconds_to_riutash)


## Letrero en la casilla global `world_cell` o en una de sus 8 vecinas (primero las ortogonales, en
## el orden de Interaction.AROUND): { "world_cell", "coord", "cell" (en su chunk), "sign" } o {}.
## `get_chunk`: Callable(coord) -> WorldChunk (o null).
static func near_world(get_chunk: Callable, world_cell: Vector2i) -> Dictionary:
	for d: Vector2i in [Vector2i.ZERO] + Interaction.AROUND:
		var c: Vector2i = world_cell + d
		var coord: Vector2i = WorldCoords.world_cell_to_chunk(c)
		var chunk: WorldChunk = get_chunk.call(coord)
		if chunk == null:
			continue
		var local: Vector2i = WorldCoords.world_cell_to_cell(c)
		if chunk.object_at(local).get("kind", -1) != WorldChunk.ObjectKind.SIGN:
			continue
		var sign_data: Dictionary = chunk.sign_at(local)
		if not sign_data.is_empty():
			return { "world_cell": c, "coord": coord, "cell": local, "sign": sign_data }
	return {}


## Al pasar los pies de `from_world_cell` a `to_world_cell` (cell_changed), el letrero que se acaba
## de alcanzar: el de near_world(to) si no es el mismo que ya estaba al lado en `from`. {} si no hay
## o si solo se ha movido junto al mismo letrero.
static func sign_entered(get_chunk: Callable, from_world_cell: Vector2i, to_world_cell: Vector2i) -> Dictionary:
	var now: Dictionary = near_world(get_chunk, to_world_cell)
	if now.is_empty():
		return {}
	var before: Dictionary = near_world(get_chunk, from_world_cell)
	if not before.is_empty() and before.world_cell == now.world_cell:
		return {}
	return now
