class_name BosquePatrols
extends RefCounted
## Únicos que rondan por dentro de cada Bosque con Nujio (feedback del dueño 0.3: "tampoco veo más
## diversidad de estos rondando por ahí"). Lógica pura y determinista por seed:
## - Cada Bosque tiene entre count_min y count_max Únicos que rondan, cada uno en un chunk del
##   Bosque y de un tipo de `kinds` (Botarramas, Ofomni, Aledra), elegidos por seed y Bosque.
## - Los de tipo nocturno (`night_only`, Aledra) solo están fuera en el Momento de Riumna.
## - Rondan alrededor de su puesto (patrol_wander de sus datos) y miran pasar al jugador; si su
##   Bosque no está pagado, persiguen al verle (MonsterField.can_detect).
## Números en data/combat/balance.json (bloque patrols).

const SALT_COUNT: int = 41
const SALT_CHUNK: int = 43
const SALT_KIND: int = 47
const SALT_CELL: int = 53
## Intentos para encontrar una casilla de puesto.
const CELL_TRIES: int = 400


static func config() -> Dictionary:
	return AdventureRules.balance().get("patrols", {})


## Todos los Únicos que rondan el Bosque `bosque_id`: [{ "id", "monster", "bosque_id", "chunk" }],
## estén fuera o no según el Momento.
static func patrols_of(map: BosqueMap, seed_value: int, bosque_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if bosque_id < 0:
		return out
	var cfg: Dictionary = config()
	var kinds: Array = cfg.get("kinds", ["botarramas", "ofomni"])
	var lo: int = int(cfg.get("count_min", 1))
	var hi: int = maxi(lo, int(cfg.get("count_max", 2)))
	var n: int = lo + ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_COUNT]) % (hi - lo + 1)
	var chunks: Array[Vector2i] = map.chunks_of(bosque_id)
	if chunks.is_empty() or kinds.is_empty():
		return out
	for i: int in n:
		var chunk: Vector2i = chunks[ChunkGenerator.hash_ints([seed_value, bosque_id, i, SALT_CHUNK]) % chunks.size()]
		var kind: String = str(kinds[ChunkGenerator.hash_ints([seed_value, bosque_id, i, SALT_KIND]) % kinds.size()])
		out.append({ "id": "patrol:%d:%d" % [bosque_id, i], "monster": StringName(kind), "bosque_id": bosque_id, "chunk": chunk })
	return out


## Únicos que rondan ahora el chunk `coord` en el Momento `momento` (Aledra, solo de noche).
static func patrols_in(map: BosqueMap, seed_value: int, coord: Vector2i, momento: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in patrols_of(map, seed_value, map.bosque_at(coord)):
		if p.chunk == coord and is_out(p.monster, momento):
			out.append(p)
	return out


## El Único de ese tipo está fuera en ese Momento: los de night_only, solo en Riumna.
static func is_out(monster_id: StringName, momento: StringName) -> bool:
	return not (config().get("night_only", []) as Array).has(String(monster_id)) or momento == TimeConfig.RIUMNA


## Casilla del puesto de un Único que ronda (`key`): alcanzable, libre (`can_use`) y a min_hub_distance
## o más del hub (lejos de la plaza de la villa). Determinista. (-1, -1) si no hay.
static func post_cell(chunk: ChunkData, seed_value: int, key: String, can_use: Callable) -> Vector2i:
	var gap: int = int(config().get("min_hub_distance", 10))
	var margin: int = 4
	for t: int in CELL_TRIES:
		var h: int = ChunkGenerator.hash_ints([seed_value, key.hash(), t, SALT_CELL])
		var span: int = ChunkData.SIZE - 2 * margin
		var c := Vector2i(margin + h % span, margin + (h / span) % span)
		if MonsterSteering.chebyshev(c, chunk.hub) >= gap and chunk.is_reachable(c) and can_use.call(c):
			return c
	return Vector2i(-1, -1)
