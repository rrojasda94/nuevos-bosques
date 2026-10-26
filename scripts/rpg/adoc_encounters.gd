class_name AdocEncounters
extends RefCounted
## Otros adoc en el mundo (otros-adoc.md, versión mínima de la 0.3; dueño: "encontrarte con otros
## adoc, ayudarles a luchar contra Únicos" y "los adoc son aliados siempre [...] No hacen daño").
## Lógica pura y determinista por seed:
## - En one_in de cada N Bosques (nunca el natal) hay un adoc NPC con su nombre, su ropa y su nivel,
##   a punto de pelear contra un grupo de reparep o un Único, en un chunk de ese Bosque.
## - Con E: "Ayudar" o "Seguir tu camino". Ayudar empieza el combate con él como aliado (ATQ y DEF de
##   su nivel; no muere: a 0 PV se retira). Ganar: relación con el Bosque + relation_reward y fama +
##   fama_reward (finish_battle).
## - Cada encuentro pasa una sola vez: queda resuelto (GameState.adoc_encounters) al ayudar (gane o
##   no) o al seguir tu camino. Ganar con él sube la Senda (Senda.ADOC_HELPED).
## - Afinidad (otros-adoc.md, 0.5): cada adoc tiene su Senda por seed; si la diferencia con la tuya
##   llega a affinity_gap, no quiere trabajar contigo (accepts_help). Con la skill Rostro conocido
##   aceptan siempre.
## Números en data/combat/balance.json (bloque otros_adoc); nombres y ropa en
## data/npcs/otros_adoc.json.

const DATA_PATH: String = "res://data/npcs/otros_adoc.json"
## Id de NPC con el que la exploración marca la casilla del adoc (Interaction lo trata como NPC).
const NPC_ID: StringName = &"adoc_encounter"
const HELPED: String = "helped"
const RETIRED: String = "retired"
const PASSED: String = "passed"
const SALT_EVENT: int = 81
const SALT_CHUNK: int = 83
const SALT_NAME: int = 89
const SALT_LEVEL: int = 97
const SALT_ENEMY: int = 101
const SALT_CELL: int = 103
const SALT_CLOTHES: int = 107
const SALT_SENDA: int = 109
const CELL_TRIES: int = 400

static var _data: Dictionary = {}


static func config() -> Dictionary:
	return AdventureRules.balance().get("otros_adoc", {})


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		assert(parsed is Dictionary, "No se pudo leer %s" % DATA_PATH)
		_data = parsed
	return _data


## Encuentro del Bosque `bosque_id` ({} si no tiene): { id, bosque_id, chunk, name, level, enemy,
## count, clothes }. `enemy`: id de monstruo; `count`: tamaño del grupo (1 si no va en grupo).
static func encounter_of(map: BosqueMap, seed_value: int, bosque_id: int) -> Dictionary:
	var cfg: Dictionary = config()
	if bosque_id < 0 or bosque_id == map.home_bosque or cfg.is_empty():
		return {}
	if ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_EVENT]) % maxi(1, int(cfg.one_in)) != 0:
		return {}
	var chunks: Array[Vector2i] = map.chunks_of(bosque_id)
	if chunks.is_empty():
		return {}
	var id: String = "adoc:%d" % bosque_id
	var names: Array = data().get("names", ["Adoc"])
	var clothes: Array = data().get("clothes", [])
	var lo: int = int(cfg.get("level_min", 1))
	var hi: int = maxi(lo, int(cfg.get("level_max", lo)))
	var enemies: Array = cfg.get("enemies", ["reparep"])
	var enemy: StringName = StringName(str(enemies[ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_ENEMY]) % enemies.size()]))
	return {
		"id": id,
		"bosque_id": bosque_id,
		"chunk": chunks[ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_CHUNK]) % chunks.size()],
		"name": str(names[ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_NAME]) % names.size()]),
		"level": lo + ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_LEVEL]) % (hi - lo + 1),
		"enemy": enemy,
		"count": AdventureRules.group_size(enemy, seed_value, id),
		"clothes": clothes[ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_CLOTHES]) % clothes.size()] if not clothes.is_empty() else {},
	}


## Todos los encuentros de la región, por id de Bosque.
static func all(map: BosqueMap, seed_value: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: int in map.count():
		var e: Dictionary = encounter_of(map, seed_value, id)
		if not e.is_empty():
			out.append(e)
	return out


## Encuentro sin resolver en el chunk `coord` ({} si no hay). El rival se ajusta al Bosque
## (enemy_for con `welcome`: el Bosque deja pasar en paz al Adoc).
static func encounter_in(map: BosqueMap, seed_value: int, coord: Vector2i, welcome: bool) -> Dictionary:
	var e: Dictionary = encounter_of(map, seed_value, map.bosque_at(coord))
	if e.is_empty() or e.chunk != coord or is_resolved(e.id):
		return {}
	return with_enemy(e, welcome)


## En un Bosque que deja pasar en paz (pagado, natal o amistoso) sus Únicos no pelean: el rival pasa
## a ser un grupo de reparep (otros-adoc.md: "el evento no se genera ahí").
static func with_enemy(e: Dictionary, welcome: bool) -> Dictionary:
	var out: Dictionary = e.duplicate()
	if welcome and not AdventureRules.is_outsider(out.enemy):
		out.enemy = StringName(str(AdventureRules.balance().get("reparep_groups", {}).get("monster", "reparep")))
		out.count = AdventureRules.group_size(out.enemy, GameState.seed_value, str(out.id))
	return out


static func is_resolved(id: String) -> bool:
	return GameState.adoc_encounters.has(id)


static func resolve(id: String, outcome: String) -> void:
	GameState.adoc_encounters[id] = outcome


## Senda del adoc del encuentro `id` (por seed): de -senda_range a +senda_range.
static func adoc_senda(seed_value: int, id: String) -> int:
	var span: int = int(config().get("senda_range", 80))
	return ChunkGenerator.hash_ints([seed_value, id.hash(), SALT_SENDA]) % (2 * span + 1) - span


## El adoc acepta tu ayuda: la diferencia entre su Senda y la tuya no llega a affinity_gap, o tienes
## la skill Rostro conocido (aceptan siempre).
static func accepts_help(e: Dictionary, seed_value: int = GameState.seed_value) -> bool:
	if AdocGrowth.has_skill(AdocGrowth.ROSTRO_CONOCIDO):
		return true
	var gap: int = int(config().get("affinity_gap", 60))
	return absi(adoc_senda(seed_value, str(e.get("id", ""))) - GameState.senda) < gap


## El adoc como aliado: stats de adoc de su nivel (AdventureRules.adoc_stats).
static func ally_of(e: Dictionary) -> Dictionary:
	var s: Dictionary = AdventureRules.adoc_stats(int(e.level))
	return { "name": str(e.name), "max_hp": int(s.max_hp), "atk": int(s.atk), "def": int(s.def), "kind": &"adoc" }


## Pregunta del encuentro: "Tavra, un adoc, está a punto de pelear contra 3 reparep."
static func prompt(e: Dictionary) -> String:
	var rival: String = AdventureRules.monster_name(e.enemy)
	if int(e.count) > 1:
		rival = Texts.get_text("adoc_encounter_vs_group") % int(e.count)
	return Texts.get_text("adoc_encounter_prompt") % [str(e.name), rival]


## Final del combate de ayuda (ya aplicado por AdventureRules.finish_unico_battle): ganar da
## relación con el Bosque y fama; en todo caso, el encuentro queda resuelto. Devuelve las líneas
## que dice la exploración (agradecimiento y recompensa, o que el adoc se retira).
static func finish(e: Dictionary, outcome: StringName) -> PackedStringArray:
	var cfg: Dictionary = config()
	var lines: PackedStringArray = []
	if outcome == &"victory":
		resolve(e.id, HELPED)
		var relation: int = int(cfg.get("relation_reward", 0))
		var fama: int = int(cfg.get("fama_reward", 0))
		AdventureRules.change_relation(int(e.bosque_id), relation)
		GameState.fama += fama
		Senda.record(Senda.ADOC_HELPED)
		lines.append(Texts.get_text("adoc_encounter_thanks") % str(e.name))
		lines.append(Texts.get_text("adoc_encounter_reward") % [relation, fama])
	elif outcome == &"appeased":
		resolve(e.id, HELPED)
	elif outcome != &"game_over":
		resolve(e.id, RETIRED)
		lines.append(Texts.get_text("adoc_encounter_retired") % str(e.name))
	return lines


## Casilla del adoc en su chunk: alcanzable, libre (`can_use`, también la de su rival a la derecha
## o a la izquierda) y lejos de la plaza. Devuelve [adoc, rival] o [] si no hay sitio.
static func cells(chunk: ChunkData, seed_value: int, id: String, can_use: Callable) -> Array[Vector2i]:
	var gap: int = int(config().get("min_hub_distance", 8))
	var margin: int = 4
	var span: int = ChunkData.SIZE - 2 * margin
	for t: int in CELL_TRIES:
		var h: int = ChunkGenerator.hash_ints([seed_value, id.hash(), t, SALT_CELL])
		var c := Vector2i(margin + h % span, margin + (h / span) % span)
		if MonsterSteering.chebyshev(c, chunk.hub) < gap or not chunk.is_reachable(c) or not can_use.call(c):
			continue
		for side: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2)]:
			var r: Vector2i = c + side
			if chunk.is_reachable(r) and can_use.call(r) and can_use.call(c + side / 2):
				return [c, r]
	return []
