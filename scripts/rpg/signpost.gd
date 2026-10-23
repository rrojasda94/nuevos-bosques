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
static func travel_seconds(chunks: int) -> float:
	return chunks * ChunkData.SIZE * PlayerWalker.STEP_TIME


## Minutos de camino redondeados hacia arriba, mínimo 1 (navegacion.md).
static func travel_minutes(chunks: int) -> int:
	return maxi(1, ceili(travel_seconds(chunks) / 60.0))


## Destino del letrero `cell` del chunk: { "bosque_id", "delta" (dirección a señalar), "chunks" }.
## Letrero del camino: la villa natal, en la dirección del siguiente tramo y a los chunks de camino
## que faltan. Letrero de Bosque: la villa de ese Bosque, en línea recta.
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
static func text(villa: String, to_home: bool, delta: Vector2i, chunks: int, seconds_to_riutash: float = -1.0) -> String:
	var key: String = "signpost_to_home_villa" if to_home else "signpost_to_villa"
	var out: String = Texts.get_text(key) % [villa, ChunkGenerator.direction_name(delta)]
	var minutes: int = travel_minutes(chunks)
	if minutes == 1:
		out += " " + Texts.get_text("signpost_eta_one")
	else:
		out += " " + Texts.get_text("signpost_eta") % minutes
	if seconds_to_riutash >= 0.0 and travel_seconds(chunks) > seconds_to_riutash:
		out += " " + Texts.get_text("signpost_eta_riutash")
	return out
