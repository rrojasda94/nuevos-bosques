extends Node
## GameState: estado serializable de la partida. Sin lógica de dominio.

## v2: chunk_coord y player_cell (ADR 0006). v3: luz, hp, open_bosques y battle_attempts
## (ADR 0009). v4: reloj de Aventura, clock_momento y clock_elapsed (ADR 0012). v5: chunks
## explorados y objetivo de la brújula (navegacion.md). v6: misiones (mision-ofomni.md), inventario
## como lista de ofrendas, villa dañada, XP, fama y Botarramas vistos. v7: nivel del Adoc y
## refugios saqueados (progresion-adoc.md, ofrendas-v1.md). v8: monstruos vencidos. v9: el Bosque
## recuerda (0.3): Bosques forzados, hostilidad y relación por Bosque; el Ofomni de la misión pasa a
## ofomni_descarriado. Las versiones anteriores se cargan con valores por defecto.
const SAVE_VERSION: int = 9
## Migración a v9: el Ofomni de la misión pasó de "ofomni" a "ofomni_descarriado" (y su etiqueta
## de brújula, de "Ofomni" a "Ofomni descarriado").
const LEGACY_OFOMNI_ID: String = "ofomni"
const LEGACY_OFOMNI_LABEL: String = "Ofomni"
const QUEST_OFOMNI_ID: String = "ofomni_descarriado"

var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var day: int = 1
## Reloj de Aventura (ADR 0012): Momento actual (&"gietos" o &"riumna") y segundos transcurridos
## dentro de él. La lógica está en WorldClock.
var clock_momento: StringName = &"gietos"
var clock_elapsed: float = 0.0
## Región del mapa mundial donde ocurre la partida (ADR 0003).
var region_id: StringName = &""
## Reservado para cambios persistentes sobre chunks (ADR 0006). Los tiles NO se guardan:
## se regeneran con ChunkGenerator a partir de seed + coordenadas.
var chunk: Dictionary = {}
## Chunk donde está el jugador, en coordenadas de la región ((0, 0) = esquina noroeste).
## (-1, -1) = el chunk inicial de la región (start_chunk en su JSON).
var chunk_coord: Vector2i = Vector2i(-1, -1)
## Casilla del jugador dentro del chunk. (-1, -1) = aparecer en el centro.
var player_cell: Vector2i = Vector2i(-1, -1)
## Adoc (ADR 0009): Luz y PV actuales. Valores iniciales en data/combat/balance.json.
var luz: int = 0
var hp: int = 0
## Ids de los Bosques con el paso pagado (Luz, ofrenda o Ofrecer Luz en combate), además del
## inicial: se cruzan y sus Botarramas quedan pasivos.
var open_bosques: Array[int] = []
## Ids de los Bosques forzados (se ha vencido a alguno de sus Botarramas sin pagar): se cruzan, pero
## sus demás Botarramas siguen activos y vuelven a exigir el pago. Pagar lo pasa a open_bosques.
var forced_bosques: Array[int] = []
## El Bosque recuerda: Botarramas vencidos por Bosque { "id": n }. Sube su peaje y su visión.
var bosque_hostility: Dictionary = {}
## Relación con cada Bosque { "id": -100 .. 100 } (bosques-y-relacion.md). Empieza en 0.
var bosque_relation: Dictionary = {}
## Combates empezados por Bosque: { "id": n }. Forma parte de la semilla de cada combate.
var battle_attempts: Dictionary = {}
## Chunks visitados en la partida (mapa con M, navegacion.md). Los marca MapLogic.mark_explored.
## Los refugios y villas vistos se deducen de aquí (chunk explorado con refugio o villa).
var explored_chunks: Array[Vector2i] = []
## Objetivo de la brújula y del mapa (por ejemplo, la última posición conocida del Ofomni).
## objective_chunk (-1, -1) = sin objetivo: la brújula apunta a la villa natal.
## objective_cell (-1, -1) = casilla desconocida dentro del chunk.
var objective_chunk: Vector2i = Vector2i(-1, -1)
var objective_cell: Vector2i = Vector2i(-1, -1)
var objective_label: String = ""

## Recursos de la ciudad: { "wood": 10, "stone": 5, ... }
var resources: Dictionary = {}
## Edificios colocados: [ { "id": "sawmill", "cell": [x, y], "progress": 1.0 } ]
var buildings: Array = []
## Ciudadanos: [ { "id": "c_001", "job": "sawmill", "home": null } ]
var citizens: Array = []
## Party RPG: [ { "id": "hero", "level": 1, "xp": 0, "hp": 10 } ]
var party: Array = []
## Inventario (ofrendas-v1.md): lista de ofrendas [ { "id": "cuenco_ritual", "luz": 6 } ].
var inventory: Array = []
## Misiones: { &"quest_id": estado de QuestLogic.new_quest() }.
var quests: Dictionary = {}
## La villa natal quedó dañada (misión del Ofomni fallida). En la 0.2.0 solo es una marca.
var villa_damaged: bool = false
## XP acumulada, nivel (1 a AdventureRules.max_level()) y fama del Adoc (progresion-adoc.md).
## El nivel lo sube AdventureRules.gain_xp.
var xp: int = 0
var level: int = 1
var fama: int = 0
## Chunks cuyo refugio ya se ha saqueado (hallazgos, ofrendas-v1.md): una vez por partida.
var looted_refuges: Array[Vector2i] = []
## Última posición vista de cada Botarramas, para el mapa:
## { "id del puesto": { "monster", "bosque_id", "chunk": [x, y] } }.
var seen_monsters: Dictionary = {}
## Monstruos del mundo vencidos que han vuelto a la Luz del Bosque (no reaparecen en la partida).
var defeated_monsters: Array[String] = []


func new_game(new_seed: int = 0, new_region: StringName = &"valle_del_sara") -> void:
	seed_value = new_seed if new_seed != 0 else int(Time.get_unix_time_from_system())
	rng.seed = seed_value
	day = 1
	clock_momento = TimeConfig.start_momento()
	clock_elapsed = TimeConfig.start_elapsed()
	region_id = new_region
	chunk = {}
	chunk_coord = Vector2i(-1, -1)
	player_cell = Vector2i(-1, -1)
	xp = 0
	level = 1
	luz = AdventureRules.start_luz()
	hp = AdventureRules.max_hp()
	open_bosques = []
	forced_bosques = []
	bosque_hostility = {}
	bosque_relation = {}
	battle_attempts = {}
	explored_chunks = []
	clear_objective()
	resources = { "wood": 20, "stone": 10, "food": 15, "gold": 0 }
	buildings = []
	citizens = []
	party = []
	inventory = []
	quests = {}
	villa_damaged = false
	fama = 0
	looted_refuges = []
	seen_monsters = {}
	defeated_monsters = []


func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"seed": seed_value,
		"day": day,
		"clock_momento": String(clock_momento),
		"clock_elapsed": clock_elapsed,
		"region_id": String(region_id),
		"chunk": chunk,
		"chunk_coord": [chunk_coord.x, chunk_coord.y],
		"player_cell": [player_cell.x, player_cell.y],
		"luz": luz,
		"hp": hp,
		"open_bosques": open_bosques,
		"forced_bosques": forced_bosques,
		"bosque_hostility": bosque_hostility,
		"bosque_relation": bosque_relation,
		"battle_attempts": battle_attempts,
		"explored_chunks": explored_chunks.map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"objective_chunk": [objective_chunk.x, objective_chunk.y],
		"objective_cell": [objective_cell.x, objective_cell.y],
		"objective_label": objective_label,
		"rng_state": rng.state,
		"resources": resources,
		"buildings": buildings,
		"citizens": citizens,
		"party": party,
		"inventory": inventory,
		"quests": quests,
		"villa_damaged": villa_damaged,
		"xp": xp,
		"level": level,
		"fama": fama,
		"looted_refuges": looted_refuges.map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"seen_monsters": seen_monsters,
		"defeated_monsters": defeated_monsters,
	}


func from_dict(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 0))
	day = int(data.get("day", 1))
	# Sin reloj (v3 o anterior): inicio del Momento inicial, como en una partida nueva.
	clock_momento = StringName(str(data.get("clock_momento", TimeConfig.start_momento())))
	if not TimeConfig.is_momento(clock_momento):
		clock_momento = TimeConfig.start_momento()
	clock_elapsed = clampf(float(data.get("clock_elapsed", TimeConfig.start_elapsed())), 0.0, TimeConfig.duration(clock_momento))
	region_id = StringName(data.get("region_id", "valle_del_sara"))
	chunk = data.get("chunk", {})
	chunk_coord = _to_vector2i(data.get("chunk_coord", [-1, -1]), Vector2i(-1, -1))
	player_cell = _to_vector2i(data.get("player_cell", [-1, -1]), Vector2i(-1, -1))
	luz = clampi(int(data.get("luz", AdventureRules.start_luz())), 0, AdventureRules.luz_max())
	# Antes que los PV: su máximo depende del nivel. Sin nivel (v6 o anterior), el de su XP.
	xp = maxi(0, int(data.get("xp", 0)))
	level = clampi(int(data.get("level", AdventureRules.level_for_xp(xp))), 1, AdventureRules.max_level())
	hp = clampi(int(data.get("hp", AdventureRules.max_hp())), 1, AdventureRules.max_hp())
	open_bosques = []
	for id: Variant in data.get("open_bosques", []):
		open_bosques.append(int(id))
	# v8 o anterior: no había Bosques forzados ni memoria (vencer abría el Bosque como pagar).
	forced_bosques = []
	for id: Variant in data.get("forced_bosques", []):
		if not open_bosques.has(int(id)) and not forced_bosques.has(int(id)):
			forced_bosques.append(int(id))
	bosque_hostility = _int_dict(data.get("bosque_hostility", {}), 0, 1 << 30)
	bosque_relation = _int_dict(data.get("bosque_relation", {}), -AdventureRules.relation_max(), AdventureRules.relation_max())
	battle_attempts = {}
	var attempts: Dictionary = data.get("battle_attempts", {})
	for key: Variant in attempts:
		battle_attempts[str(key)] = int(attempts[key])
	# Sin chunks explorados (v4 o anterior): solo el chunk actual, si se conoce.
	explored_chunks = []
	if data.has("explored_chunks"):
		for value: Variant in data["explored_chunks"]:
			var c: Vector2i = _to_vector2i(value, Vector2i(-1, -1))
			if c.x >= 0 and c.y >= 0 and not explored_chunks.has(c):
				explored_chunks.append(c)
	elif chunk_coord.x >= 0 and chunk_coord.y >= 0:
		explored_chunks.append(chunk_coord)
	objective_chunk = _to_vector2i(data.get("objective_chunk", [-1, -1]), Vector2i(-1, -1))
	objective_cell = _to_vector2i(data.get("objective_cell", [-1, -1]), Vector2i(-1, -1))
	objective_label = str(data.get("objective_label", ""))
	# v8 o anterior: el Ofomni de la misión aún no se llamaba "Ofomni descarriado".
	var old_version: bool = int(data.get("save_version", 1)) < 9
	if old_version and objective_label == LEGACY_OFOMNI_LABEL:
		objective_label = Texts.get_text("compass_ofomni_descarriado")
	rng.seed = seed_value
	rng.state = int(data.get("rng_state", rng.state))
	resources = data.get("resources", {})
	buildings = data.get("buildings", [])
	citizens = data.get("citizens", [])
	party = data.get("party", [])
	# v5 o anterior: el inventario era un diccionario vacío y las misiones no existían.
	inventory = []
	var items: Variant = data.get("inventory", [])
	if items is Array:
		for item: Variant in items:
			if item is Dictionary and item.has("id"):
				inventory.append({ "id": str(item.id), "luz": int(item.get("luz", 0)) })
	quests = {}
	var saved_quests: Variant = data.get("quests", {})
	if saved_quests is Dictionary:
		for id: Variant in saved_quests:
			quests[StringName(str(id))] = QuestLogic.sanitize(saved_quests[id])
	villa_damaged = bool(data.get("villa_damaged", false))
	fama = maxi(0, int(data.get("fama", 0)))
	looted_refuges = []
	for value: Variant in data.get("looted_refuges", []):
		var c: Vector2i = _to_vector2i(value, Vector2i(-1, -1))
		if c.x >= 0 and c.y >= 0 and not looted_refuges.has(c):
			looted_refuges.append(c)
	defeated_monsters = []
	for value: Variant in data.get("defeated_monsters", []):
		if not defeated_monsters.has(str(value)):
			defeated_monsters.append(str(value))
	seen_monsters = {}
	var seen: Variant = data.get("seen_monsters", {})
	if seen is Dictionary:
		for id: Variant in seen:
			var e: Variant = seen[id]
			if e is Dictionary:
				var c: Vector2i = _to_vector2i(e.get("chunk", [-1, -1]), Vector2i(-1, -1))
				var monster: String = str(e.get("monster", ""))
				if old_version and monster == LEGACY_OFOMNI_ID:
					monster = QUEST_OFOMNI_ID
				seen_monsters[str(id)] = { "monster": monster, "bosque_id": int(e.get("bosque_id", -1)), "chunk": [c.x, c.y] }


## Fija el objetivo de la brújula y del mapa. `label`: texto corto ya traducido ("Ofomni").
func set_objective(coord: Vector2i, label: String, cell: Vector2i = Vector2i(-1, -1)) -> void:
	objective_chunk = coord
	objective_cell = cell
	objective_label = label


func clear_objective() -> void:
	set_objective(Vector2i(-1, -1), "")


func has_objective() -> bool:
	return objective_chunk.x >= 0 and objective_chunk.y >= 0


## { "id": n } con claves de texto y valores enteros acotados (descarta lo que no sea diccionario).
static func _int_dict(value: Variant, lo: int, hi: int) -> Dictionary:
	var out: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			out[str(key)] = clampi(int(value[key]), lo, hi)
	return out


static func _to_vector2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback
