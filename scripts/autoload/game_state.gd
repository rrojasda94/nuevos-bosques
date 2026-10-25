extends Node
## GameState: estado serializable de la partida. Sin lógica de dominio.

## v2: chunk_coord y player_cell (ADR 0006). v3: luz, hp, open_bosques y battle_attempts
## (ADR 0009). v4: reloj de Aventura, clock_momento y clock_elapsed (ADR 0012). v5: chunks
## explorados y objetivo de la brújula (navegacion.md). v6: misiones (mision-ofomni.md), inventario
## como lista de ofrendas, villa dañada, XP, fama y Botarramas vistos. v7: nivel del Adoc y
## refugios saqueados (progresion-adoc.md, ofrendas-v1.md). v8: monstruos vencidos. v9: el Bosque
## recuerda (0.3): Bosques forzados, hostilidad y relación por Bosque; el Ofomni de la misión pasa a
## ofomni_descarriado. v10: frutales vaciados y frutos tomados en el Momento por Bosque
## (FruitRules). v11: bolsa de casillas y equipo (roadmap-0.3.md #113) en lugar de la lista de
## ofrendas; al migrar, las ofrendas pasan a la bolsa y el arma inicial va equipada. v12: el pago
## caduca (bosques-y-relacion.md, #134): open_until por Bosque en lugar de la lista permanente
## open_bosques, contador de riutash y Bosques candidatos a enojarse (angry_candidate); al migrar,
## lo pagado queda abierto hasta el segundo riutash desde la carga (o para siempre con amistad
## alta). v13: último Bosque al que se pagó peaje (last_paid_bosque), destino de reaparición tras
## una derrota (cruce-y-combate-v2.md); al migrar, el pagado más reciente que siga abierto (el de
## caducidad más tardía; si solo hay permanentes, el de id más bajo) o ninguno. v14: estados de
## Bosque (bosques-y-relacion.md, #133): cambios de estado en la partida (bosque_state_overrides) e
## incendios apagados (extinguished_fires); al migrar, ningún incendio apagado y los candidatos a
## enojarse con la relación aún en el umbral pasan a enojados (BosqueStates.make_angry). v15: sigilo
## (sigilo-y-robo.md): Bosques colados (sneaked_bosques), segundos de camuflaje roto
## (stealth_exposed) y usos de los objetos que se rompen (item_uses); al migrar, nada colado, el
## camuflaje intacto y ningún uso gastado. Las versiones anteriores se cargan con valores por defecto.
const SAVE_VERSION: int = 15
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
## Riutash pasados en la partida (WorldClock los cuenta). Mide la caducidad del peaje.
var riutash_count: int = 0
## Paso pagado (Luz, ofrenda u Ofrecer Luz en combate) por Bosque: { "id": riutash } = abierto
## mientras riutash_count < riutash; AdventureRules.OPEN_PERMANENT (-1) = para siempre (amistad
## alta). Mientras dura, se cruza y sus Botarramas quedan pasivos. Lo gestiona AdventureRules.
var open_until: Dictionary = {}
## Último Bosque al que se pagó el peaje (Luz, ofrenda u Ofrecer Luz), aunque ya haya caducado:
## destino de reaparición tras una derrota (AdventureRules.respawn_target). -1 = ninguno.
var last_paid_bosque: int = -1
## Ids de los Bosques forzados (se ha vencido a alguno de sus Botarramas sin pagar): se cruzan, pero
## sus demás Botarramas siguen activos y vuelven a exigir el pago. Pagar no borra la marca: si el
## paso caduca, el Bosque vuelve a estar forzado (AdventureRules.is_forced).
var forced_bosques: Array[int] = []
## Bosques que han llegado a una relación muy baja (bosque_relation.angry_candidate_at): candidatos
## a volverse enojados (BosqueStates.make_angry). La marca se queda aunque la relación mejore.
var angry_candidate: Array[int] = []
## Cambios de estado de Bosque durante la partida { "id": "enojado" } (BosqueStates). Mandan sobre
## el estado de generación (BosqueMap.state, que no se guarda: sale de la seed).
var bosque_state_overrides: Dictionary = {}
## Bosques en los que el Adoc se ha colado sin pagar y en los que sigue (Stealth):
## { "id": visto } con visto = true si un Único le ha visto dentro (entonces el Bosque le caza).
## Se borran al salir de ellos. Mientras dura, la frontera se cruza.
var sneaked_bosques: Dictionary = {}
## Segundos que le quedan al camuflaje roto (te han visto). 0 = funciona.
var stealth_exposed: float = 0.0
## Cruces colados gastados por los objetos que se rompen { "id del objeto": n }.
var item_uses: Dictionary = {}
## Chunks cuyo incendio (Bosque que necesita ayuda) ya se apagó (BosqueFires): no vuelven a arder.
var extinguished_fires: Array[Vector2i] = []
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
## Bolsa (InventoryLogic): Items.bag_size() casillas, cada una {} (vacía) o { "id", "qty" }.
var bag: Array = []
## Equipo (InventoryLogic): { "main_hand", "mask", "talisman" } → id del objeto o "".
var equipped: Dictionary = {}
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
## Frutales sin fruto hasta el próximo riutash (FruitRules): Vector4i(chunk x, chunk y, casilla x,
## casilla y).
var emptied_fruit_trees: Array[Vector4i] = []
## Frutos tomados en el Momento actual por Bosque: { "id del Bosque": n }. Se vacía en cada
## riutash. Con n > 0, el siguiente fruto de ese Bosque es un robo.
var fruit_taken: Dictionary = {}


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
	riutash_count = 0
	open_until = {}
	last_paid_bosque = -1
	forced_bosques = []
	angry_candidate = []
	bosque_state_overrides = {}
	extinguished_fires = []
	sneaked_bosques = {}
	stealth_exposed = 0.0
	item_uses = {}
	bosque_hostility = {}
	bosque_relation = {}
	battle_attempts = {}
	explored_chunks = []
	clear_objective()
	resources = { "wood": 20, "stone": 10, "food": 15, "gold": 0 }
	buildings = []
	citizens = []
	party = []
	bag = InventoryLogic.new_bag(Items.bag_size())
	for item: Dictionary in Items.start_bag():
		InventoryLogic.add(bag, StringName(str(item.id)), int(item.get("qty", 1)))
	equipped = InventoryLogic.sanitize_equipped(Items.start_equipped())
	quests = {}
	villa_damaged = false
	fama = 0
	looted_refuges = []
	seen_monsters = {}
	defeated_monsters = []
	emptied_fruit_trees = []
	fruit_taken = {}


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
		"riutash_count": riutash_count,
		"open_until": open_until,
		"last_paid_bosque": last_paid_bosque,
		"forced_bosques": forced_bosques,
		"angry_candidate": angry_candidate,
		"bosque_state_overrides": bosque_state_overrides,
		"extinguished_fires": extinguished_fires.map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"sneaked_bosques": sneaked_bosques,
		"stealth_exposed": stealth_exposed,
		"item_uses": item_uses,
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
		"bag": bag,
		"equipped": equipped,
		"quests": quests,
		"villa_damaged": villa_damaged,
		"xp": xp,
		"level": level,
		"fama": fama,
		"looted_refuges": looted_refuges.map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"seen_monsters": seen_monsters,
		"defeated_monsters": defeated_monsters,
		"emptied_fruit_trees": emptied_fruit_trees.map(func(k: Vector4i) -> Array: return [k.x, k.y, k.z, k.w]),
		"fruit_taken": fruit_taken,
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
	riutash_count = maxi(0, int(data.get("riutash_count", 0)))
	bosque_hostility = _int_dict(data.get("bosque_hostility", {}), 0, 1 << 30)
	bosque_relation = _int_dict(data.get("bosque_relation", {}), -AdventureRules.relation_max(), AdventureRules.relation_max())
	# v11 o anterior: el pago era permanente (lista open_bosques) y pagar borraba la marca de forzado.
	var legacy: bool = int(data.get("save_version", 1)) < 12
	var legacy_open: Array[int] = []
	if legacy:
		for id: Variant in data.get("open_bosques", []):
			legacy_open.append(int(id))
	# v8 o anterior: no había Bosques forzados ni memoria (vencer abría el Bosque como pagar).
	forced_bosques = []
	for id: Variant in data.get("forced_bosques", []):
		if not legacy_open.has(int(id)) and not forced_bosques.has(int(id)):
			forced_bosques.append(int(id))
	open_until = {}
	var saved: Variant = data.get("open_until", {})
	if not legacy and saved is Dictionary:
		for key: Variant in saved:
			var until: int = int(saved[key])
			open_until[str(key)] = until if until >= 0 else AdventureRules.OPEN_PERMANENT
	# Lo pagado en la v11 queda abierto hasta el segundo riutash desde la carga, o para siempre con
	# amistad alta.
	for id: int in legacy_open:
		AdventureRules.open_bosque(id)
	# v12 o anterior: sin último pagado; se deduce de lo que sigue abierto.
	if data.has("last_paid_bosque"):
		last_paid_bosque = maxi(-1, int(data.last_paid_bosque))
	else:
		last_paid_bosque = _latest_paid(open_until)
	angry_candidate = []
	for id: Variant in data.get("angry_candidate", []):
		if not angry_candidate.has(int(id)):
			angry_candidate.append(int(id))
	# v11 o anterior: sin marca; la tienen los Bosques que ya estaban en la relación del umbral.
	if legacy:
		for key: String in bosque_relation:
			if int(bosque_relation[key]) <= AdventureRules.angry_candidate_at() and not angry_candidate.has(int(key)):
				angry_candidate.append(int(key))
	extinguished_fires = []
	for value: Variant in data.get("extinguished_fires", []):
		var c: Vector2i = _to_vector2i(value, Vector2i(-1, -1))
		if c.x >= 0 and c.y >= 0 and not extinguished_fires.has(c):
			extinguished_fires.append(c)
	bosque_state_overrides = {}
	var overrides: Variant = data.get("bosque_state_overrides", {})
	if overrides is Dictionary:
		for key: Variant in overrides:
			if BosqueMap.STATES.has(str(overrides[key])) and int(str(key)) >= 0:
				bosque_state_overrides[str(int(str(key)))] = str(overrides[key])
	# v13 o anterior: sin estados; los candidatos a enojarse que siguen en el umbral se enojan.
	if int(data.get("save_version", 1)) < 14:
		for id: int in angry_candidate:
			if int(bosque_relation.get(str(id), 0)) <= AdventureRules.angry_candidate_at():
				BosqueStates.make_angry(id)
	# v14 o anterior: sin sigilo (nada colado, camuflaje intacto, ningún uso gastado).
	sneaked_bosques = {}
	var sneaked: Variant = data.get("sneaked_bosques", {})
	if sneaked is Dictionary:
		for key: Variant in sneaked:
			if int(str(key)) >= 0:
				sneaked_bosques[str(int(str(key)))] = bool(sneaked[key])
	stealth_exposed = maxf(0.0, float(data.get("stealth_exposed", 0.0)))
	item_uses = {}
	var uses: Variant = data.get("item_uses", {})
	if uses is Dictionary:
		for id: Variant in uses:
			if Items.max_uses(StringName(str(id))) > int(uses[id]) and int(uses[id]) > 0:
				item_uses[str(id)] = int(uses[id])
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
	_load_inventory(data)
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
	# v9 o anterior: todos los frutales con fruto y ninguno tomado en el Momento.
	emptied_fruit_trees = []
	for value: Variant in data.get("emptied_fruit_trees", []):
		if value is Array and value.size() == 4:
			var k := Vector4i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))
			if not emptied_fruit_trees.has(k):
				emptied_fruit_trees.append(k)
	fruit_taken = {}
	var taken: Variant = data.get("fruit_taken", {})
	if taken is Dictionary:
		for id: Variant in taken:
			if int(taken[id]) > 0:
				fruit_taken[str(id)] = int(taken[id])
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


## Bolsa y equipo. v11: tal cual (saneados). v10 o anterior: la lista de ofrendas "inventory"
## [{ id, luz }] pasa a la bolsa (si hubiera más de las que caben, las sobrantes se pierden) y el
## equipo es el inicial (el arma del Adoc equipada). En v5 o anterior "inventory" era un
## diccionario vacío.
func _load_inventory(data: Dictionary) -> void:
	if data.has("bag"):
		bag = InventoryLogic.sanitize_bag(data.bag, Items.bag_size())
		equipped = InventoryLogic.sanitize_equipped(data.get("equipped", {}))
		return
	bag = InventoryLogic.new_bag(Items.bag_size())
	var items: Variant = data.get("inventory", [])
	if items is Array:
		for item: Variant in items:
			if item is Dictionary and item.has("id"):
				InventoryLogic.add(bag, StringName(str(item.id)))
	equipped = InventoryLogic.sanitize_equipped(Items.start_equipped())


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


## Bosque pagado más reciente según open_until: el de caducidad más tardía (empates: id más bajo);
## si solo hay permanentes, el de id más bajo. -1 si no hay ninguno.
static func _latest_paid(until_by_id: Dictionary) -> int:
	var best: int = -1
	var best_until: int = -2
	for key: Variant in until_by_id:
		var id: int = int(key)
		var until: int = int(until_by_id[key])
		# Permanente (-1) cuenta como el más antiguo: no se sabe cuándo se pagó.
		if until > best_until or (until == best_until and id < best):
			best = id
			best_until = until
	return best


static func _to_vector2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback
