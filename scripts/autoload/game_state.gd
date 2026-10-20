extends Node
## GameState: estado serializable de la partida. Sin lógica de dominio.

const SAVE_VERSION: int = 1

var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var ticks: int = 0

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


func new_game(new_seed: int = 0) -> void:
	seed_value = new_seed if new_seed != 0 else int(Time.get_unix_time_from_system())
	rng.seed = seed_value
	ticks = 0
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
		"ticks": ticks,
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
	ticks = int(data.get("ticks", 0))
	rng.seed = seed_value
	rng.state = int(data.get("rng_state", rng.state))
	resources = data.get("resources", {})
	buildings = data.get("buildings", [])
	citizens = data.get("citizens", [])
	party = data.get("party", [])
	inventory = data.get("inventory", {})
	quests = data.get("quests", {})
