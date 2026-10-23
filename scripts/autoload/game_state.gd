extends Node
## GameState: estado serializable de la partida. Sin lógica de dominio.

## v2: chunk_coord y player_cell (ADR 0006). Las v1 se cargan con valores por defecto.
const SAVE_VERSION: int = 2

var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var day: int = 1
## Región del mapa mundial donde ocurre la partida (ADR 0003).
var region_id: StringName = &""
## Reservado para cambios persistentes sobre chunks (ADR 0006). Los tiles NO se guardan:
## se regeneran con ChunkGenerator a partir de seed + coordenadas.
var chunk: Dictionary = {}
## Chunk (zona) donde está el jugador. (0, 0) es el chunk inicial de la partida.
var chunk_coord: Vector2i = Vector2i.ZERO
## Casilla del jugador dentro del chunk. (-1, -1) = aparecer en el centro.
var player_cell: Vector2i = Vector2i(-1, -1)

## Recursos de la ciudad: { "wood": 10, "stone": 5, ... }
var resources: Dictionary = {}
## Edificios colocados: [ { "id": "sawmill", "cell": [x, y], "progress": 1.0 } ]
var buildings: Array = []
## Ciudadanos: [ { "id": "c_001", "job": "sawmill", "home": null } ]
var citizens: Array = []
## Party RPG: [ { "id": "hero", "level": 1, "xp": 0, "hp": 10 } ]
var party: Array = []
## Inventario: { "item_id": cantidad }
var inventory: Dictionary = {}
## Misiones: { "quest_id": "active" }
var quests: Dictionary = {}


func new_game(new_seed: int = 0, new_region: StringName = &"claro_inicial") -> void:
	seed_value = new_seed if new_seed != 0 else int(Time.get_unix_time_from_system())
	rng.seed = seed_value
	day = 1
	region_id = new_region
	chunk = {}
	chunk_coord = Vector2i.ZERO
	player_cell = Vector2i(-1, -1)
	resources = { "wood": 20, "stone": 10, "food": 15, "gold": 0 }
	buildings = []
	citizens = []
	party = []
	inventory = {}
	quests = {}


func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"seed": seed_value,
		"day": day,
		"region_id": String(region_id),
		"chunk": chunk,
		"chunk_coord": [chunk_coord.x, chunk_coord.y],
		"player_cell": [player_cell.x, player_cell.y],
		"rng_state": rng.state,
		"resources": resources,
		"buildings": buildings,
		"citizens": citizens,
		"party": party,
		"inventory": inventory,
		"quests": quests,
	}


func from_dict(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 0))
	day = int(data.get("day", 1))
	region_id = StringName(data.get("region_id", "claro_inicial"))
	chunk = data.get("chunk", {})
	chunk_coord = _to_vector2i(data.get("chunk_coord", [0, 0]), Vector2i.ZERO)
	player_cell = _to_vector2i(data.get("player_cell", [-1, -1]), Vector2i(-1, -1))
	rng.seed = seed_value
	rng.state = int(data.get("rng_state", rng.state))
	resources = data.get("resources", {})
	buildings = data.get("buildings", [])
	citizens = data.get("citizens", [])
	party = data.get("party", [])
	inventory = data.get("inventory", {})
	quests = data.get("quests", {})


static func _to_vector2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback
