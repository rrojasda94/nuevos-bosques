class_name FarQuests
extends RefCounted
## Misiones lejanas y salvoconducto (bosques-y-relacion.md, "Dormir y Pensamiento", #136). Palabras
## del dueño: "durmiendo puedes oir o ver misiones distantes en áras o regiones más lejanas" y "si
## un bosque diferente te llama para una misión, este no te cobra Luz puede ayudarte a tener una ruta
## de salvoconducto por bosques buenos que no necesariamente es la ruta más corta".
## Lógica pura sobre ids de Bosque:
## - Visión (vision_for): al dormir de noche, con probabilidad sleep.vision_chance (por seed y día),
##   un Bosque a min_hops saltos o más pide ayuda. Tipos: "fire" (apagar el incendio de su chunk
##   central, BosqueFires) y "reparep" (vencer a su grupo de reparep, BosquePatrols), según su estado
##   (types_by_state). Como mucho max_active misiones activas.
## - Misión: diccionario guardado en GameState.far_quests con los estados de QuestLogic (active ->
##   completed -> rewarded, o active -> failed). Se cumple al apagar ese incendio o vencer ese grupo;
##   falla si el Bosque que llama se enoja o muere.
## - Salvoconducto (covers): con la misión activa, el Bosque que llama y los de su ruta no cobran
##   peaje y sus Botarramas dejan pasar como si estuviera pagado (AdventureRules.is_paid).
## - Ruta (safe_route): la más corta que solo pasa por Bosques buenos (is_good), que no tiene por qué
##   ser la más corta del mapa. Se recalcula si se sale de ella o si uno de sus Bosques deja de ser
##   bueno.
## Solo complete() y fail() tocan Luz, fama y relación. Números en data/combat/balance.json
## (bloques far_quests y sleep).

const TYPE_FIRE: String = "fire"
const TYPE_REPAREP: String = "reparep"
const TYPES: Array[String] = [TYPE_FIRE, TYPE_REPAREP]
const SALT_VISION: int = 83
const SALT_TARGET: int = 89
const SALT_TYPE: int = 97


static func config() -> Dictionary:
	return AdventureRules.balance().get("far_quests", {})


static func min_hops() -> int:
	return int(config().get("min_hops", 3))


static func max_active() -> int:
	return int(config().get("max_active", 2))


static func reward() -> Dictionary:
	return config().get("reward", {})


# --- Estado ------------------------------------------------------------------------------------

## Misión lejana nueva, ya activa (se acepta en el mismo momento en que se crea).
static func new_quest(type: String, bosque_id: int, target_chunk: Vector2i, route: Array[int], day: int) -> Dictionary:
	return {
		"state": String(QuestLogic.ACTIVE),
		"type": type,
		"bosque": bosque_id,
		"target_chunk": [target_chunk.x, target_chunk.y],
		"route": route.duplicate(),
		"day": day,
	}


## Misión leída de un guardado (JSON: números como float). {} si no es válida.
static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not TYPES.has(str(raw.get("type", ""))) or int(raw.get("bosque", -1)) < 0:
		return {}
	var state: StringName = StringName(str(raw.get("state", QuestLogic.ACTIVE)))
	if not state in [QuestLogic.ACTIVE, QuestLogic.COMPLETED, QuestLogic.REWARDED, QuestLogic.FAILED]:
		state = QuestLogic.ACTIVE
	var route: Array[int] = []
	var saved: Variant = raw.get("route", [])
	if saved is Array:
		for id: Variant in saved:
			if int(id) >= 0 and not route.has(int(id)):
				route.append(int(id))
	var target: Vector2i = GameState._to_vector2i(raw.get("target_chunk", [-1, -1]), Vector2i(-1, -1))
	var q: Dictionary = new_quest(str(raw.type), int(raw.bosque), target, route, maxi(0, int(raw.get("day", 0))))
	q.state = String(state)
	return q


static func is_active(q: Dictionary) -> bool:
	return QuestLogic.state_of(q) == QuestLogic.ACTIVE


static func target_chunk(q: Dictionary) -> Vector2i:
	return GameState._to_vector2i(q.get("target_chunk", [-1, -1]), Vector2i(-1, -1))


static func route_of(q: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for id: Variant in q.get("route", []):
		out.append(int(id))
	return out


## Misiones lejanas activas de la partida.
static func active_quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q: Dictionary in GameState.far_quests:
		if is_active(q):
			out.append(q)
	return out


## Bosques que ya llaman al Adoc con una misión activa.
static func active_targets() -> Array[int]:
	var out: Array[int] = []
	for q: Dictionary in active_quests():
		out.append(int(q.bosque))
	return out


## Salvoconducto: el Bosque es el que llama o está en la ruta de una misión lejana activa. No cobra
## peaje y sus Botarramas dejan pasar como si estuviera pagado.
static func covers(bosque_id: int) -> bool:
	if bosque_id < 0:
		return false
	for q: Dictionary in active_quests():
		if int(q.bosque) == bosque_id or route_of(q).has(bosque_id):
			return true
	return false


# --- Visión de Pensamiento ---------------------------------------------------------------------

## Al dormir de noche el día `day`, hay visión: probabilidad sleep.vision_chance, determinista por
## seed y día.
static func has_vision(seed_value: int, day: int) -> bool:
	var chance: float = float(AdventureRules.balance().get("sleep", {}).get("vision_chance", 0.5))
	return ChunkGenerator.hash_ints([seed_value, day, SALT_VISION]) % 1000 < roundi(chance * 1000.0)


## Tipos de misión que puede pedir el Bosque ahora (según su estado y lo que queda por hacer):
## "fire" si su chunk central sigue ardiendo (`has_fire`: Callable(chunk) -> bool que dice si de
## verdad arde; sin ella, se da por hecho), "reparep" si tiene un grupo de reparep siempre fuera y
## sin vencer.
static func types_for(map: BosqueMap, seed_value: int, bosque_id: int, has_fire: Callable = Callable()) -> Array[String]:
	var out: Array[String] = []
	var state: String = BosqueStates.state_of(bosque_id, map)
	var allowed: Array = (config().get("types_by_state", {}) as Dictionary).get(state, [])
	for type: Variant in allowed:
		match str(type):
			TYPE_FIRE:
				var c: Vector2i = map.nujio_chunk[bosque_id]
				if not BosqueFires.is_extinguished(c) and (not has_fire.is_valid() or bool(has_fire.call(c))):
					out.append(TYPE_FIRE)
			TYPE_REPAREP:
				var group: Dictionary = BosquePatrols.reparep_group_of(map, seed_value, bosque_id)
				if not group.is_empty() and not bool(group.night) and not GameState.defeated_monsters.has(str(group.id)):
					out.append(TYPE_REPAREP)
	return out


## Chunk del objetivo: el central del Bosque (donde arde siempre) o el de su grupo de reparep.
static func objective_chunk(map: BosqueMap, seed_value: int, bosque_id: int, type: String) -> Vector2i:
	if type == TYPE_REPAREP:
		var group: Dictionary = BosquePatrols.reparep_group_of(map, seed_value, bosque_id)
		if not group.is_empty():
			return group.chunk
	return map.nujio_chunk[bosque_id]


## Visión al dormir de noche el día `day` en el Bosque `from_bosque`: { "type", "bosque",
## "target_chunk", "hops" } o {} si no hay (sin suerte, con max_active misiones activas o sin
## ningún Bosque lejano que pida ayuda). Determinista por seed y día.
static func vision_for(map: BosqueMap, seed_value: int, day: int, from_bosque: int, has_fire: Callable = Callable()) -> Dictionary:
	if not has_vision(seed_value, day) or active_quests().size() >= max_active():
		return {}
	var taken: Array[int] = active_targets()
	var candidates: Array[int] = []
	var types: Dictionary = {}
	for id: int in map.count():
		if id == map.home_bosque or taken.has(id) or map.distance(from_bosque, id) < min_hops():
			continue
		var t: Array[String] = types_for(map, seed_value, id, has_fire)
		if not t.is_empty():
			candidates.append(id)
			types[id] = t
	if candidates.is_empty():
		return {}
	var bosque: int = candidates[ChunkGenerator.hash_ints([seed_value, day, SALT_TARGET]) % candidates.size()]
	var options: Array[String] = types[bosque]
	var type: String = options[ChunkGenerator.hash_ints([seed_value, day, bosque, SALT_TYPE]) % options.size()]
	return {
		"type": type,
		"bosque": bosque,
		"target_chunk": objective_chunk(map, seed_value, bosque, type),
		"hops": map.distance(from_bosque, bosque),
	}


## Acepta la visión: crea la misión activa con su ruta de salvoconducto desde `from_bosque` y la
## guarda. Devuelve la misión ({} si ya hay max_active activas).
static func accept(map: BosqueMap, vision: Dictionary, from_bosque: int, day: int) -> Dictionary:
	if vision.is_empty() or active_quests().size() >= max_active():
		return {}
	var target: int = int(vision.bosque)
	var q: Dictionary = new_quest(str(vision.type), target, vision.target_chunk, route_for(map, from_bosque, target), day)
	GameState.far_quests.append(q)
	EventBus.quest_state_changed.emit(quest_id(q), QuestLogic.ACTIVE)
	return q


## Id de la misión para EventBus.quest_state_changed: "lejana_<Bosque>_<día>".
static func quest_id(q: Dictionary) -> StringName:
	return StringName("lejana_%d_%d" % [int(q.get("bosque", -1)), int(q.get("day", 0))])


# --- Ruta de salvoconducto ---------------------------------------------------------------------

## Bosque "bueno" para la ruta (dueño: "bosques buenos"): sano o que necesita ayuda (good_states), o
## con relación >= good_relation, y nunca enojado. El natal siempre lo es.
static func is_good(map: BosqueMap, bosque_id: int) -> bool:
	if bosque_id < 0 or bosque_id >= map.count():
		return false
	if bosque_id == map.home_bosque:
		return true
	var state: String = BosqueStates.state_of(bosque_id, map)
	if state == BosqueStates.ENOJADO:
		return false
	return (config().get("good_states", []) as Array).has(state) \
		or AdventureRules.relation(bosque_id) >= int(config().get("good_relation", 30))


## Ruta de `from` a `to` que solo pasa por Bosques para los que `is_good` (Callable(id) -> bool) es
## verdadero (el primero y el último pueden no serlo): la de menos saltos entre esas, con los
## vecinos en orden de id (determinista). `neighbours`: Callable(id) -> Array[int]. [] si no hay.
static func safe_route(neighbours: Callable, from: int, to: int, is_good_id: Callable) -> Array[int]:
	var out: Array[int] = []
	if from < 0 or to < 0:
		return out
	var prev: Dictionary = { from: -1 }
	var queue: Array[int] = [from]
	var head: int = 0
	while head < queue.size():
		var id: int = queue[head]
		head += 1
		if id == to:
			break
		var next: Array[int] = []
		next.assign(neighbours.call(id))
		next.sort()
		for n: int in next:
			if prev.has(n) or (n != to and not bool(is_good_id.call(n))):
				continue
			prev[n] = id
			queue.append(n)
	if not prev.has(to):
		return out
	var at: int = to
	while at != -1:
		out.push_front(at)
		at = int(prev[at])
	return out


## Ruta de salvoconducto en el reparto de la partida. Sin ruta buena, solo el Bosque que llama.
static func route_for(map: BosqueMap, from: int, to: int) -> Array[int]:
	var route: Array[int] = safe_route(func(id: int) -> Array[int]: return map.neighbours_of(id), from, to,
			func(id: int) -> bool: return is_good(map, id))
	if route.is_empty():
		route = [to]
	return route


## La ruta sigue sirviendo: el Adoc está en ella y todos sus Bosques intermedios siguen siendo
## buenos.
static func is_route_valid(map: BosqueMap, q: Dictionary, current: int) -> bool:
	var route: Array[int] = route_of(q)
	if not route.has(current):
		return false
	for i: int in range(1, route.size() - 1):
		if not is_good(map, route[i]):
			return false
	return true


## Recalcula la ruta desde `current` si ya no sirve. true si ha cambiado.
static func refresh_route(map: BosqueMap, q: Dictionary, current: int) -> bool:
	if not is_active(q) or current < 0 or is_route_valid(map, q, current) or current == int(q.bosque):
		return false
	var route: Array[int] = route_for(map, current, int(q.bosque))
	if route == route_of(q):
		return false
	q.route = route
	return true


## Siguiente Bosque de la ruta desde `current` (el que llama si ya está en él o es el siguiente).
## -1 si `current` no está en la ruta.
static func next_step(q: Dictionary, current: int) -> int:
	var target: int = int(q.bosque)
	if current == target:
		return target
	var route: Array[int] = route_of(q)
	var i: int = route.find(current)
	if i < 0:
		return -1
	return route[mini(i + 1, route.size() - 1)]


## Chunk al que apunta la brújula: en el Bosque que llama, el del objetivo; si no, el chunk del
## siguiente Bosque de la ruta más cercano al Adoc (Manhattan; empates por fila y columna). Fuera de
## la ruta, el del objetivo.
static func compass_chunk(map: BosqueMap, q: Dictionary, chunk: Vector2i) -> Vector2i:
	var current: int = map.bosque_at(chunk)
	var next: int = next_step(q, current)
	if next < 0 or current == int(q.bosque):
		return target_chunk(q)
	return _nearest_chunk(map, next, chunk)


static func _nearest_chunk(map: BosqueMap, bosque_id: int, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score: int = 1 << 30
	for c: Vector2i in map.chunks_of(bosque_id):
		var score: int = (absi(c.x - from.x) + absi(c.y - from.y)) * 10_000 + c.y * 100 + c.x
		if score < best_score:
			best_score = score
			best = c
	return best


## Chunks por los que se dibuja la ruta en el mapa (M): de Nujio a Nujio, pasando solo por los dos
## Bosques de cada tramo (camino más corto en la rejilla de chunks; determinista).
static func route_path(map: BosqueMap, route: Array[int]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i: int in route.size():
		var c: Vector2i = map.nujio_chunk[route[i]]
		if i == 0:
			out.append(c)
			continue
		var leg: Array[Vector2i] = _chunk_path(map, out.back(), c, [route[i - 1], route[i]])
		for j: int in range(1, leg.size()):
			out.append(leg[j])
	return out


## Línea de la misión en el mapa: la ruta (route_path) y, dentro del Bosque que llama, el tramo
## hasta el chunk del objetivo (el de su grupo de reparep puede no ser el del Nujio).
static func map_path(map: BosqueMap, q: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = route_path(map, route_of(q))
	var target: Vector2i = target_chunk(q)
	if out.is_empty() or target.x < 0 or out.back() == target:
		return out
	var leg: Array[Vector2i] = _chunk_path(map, out.back(), target, [int(q.bosque)])
	for j: int in range(1, leg.size()):
		out.append(leg[j])
	return out


static func _chunk_path(map: BosqueMap, from: Vector2i, to: Vector2i, allowed: Array) -> Array[Vector2i]:
	var prev: Dictionary = { from: from }
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == to:
			break
		for d: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not prev.has(n) and allowed.has(map.bosque_at(n)):
				prev[n] = c
				queue.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return [from, to] as Array[Vector2i]
	var at: Vector2i = to
	while at != from:
		out.push_front(at)
		at = prev[at]
	out.push_front(from)
	return out


# --- Cumplir o fallar --------------------------------------------------------------------------

## Hecho lo que pedía el Bosque: su incendio central apagado o su grupo de reparep vencido.
static func is_accomplished(q: Dictionary) -> bool:
	match str(q.get("type", "")):
		TYPE_FIRE:
			return BosqueFires.is_extinguished(target_chunk(q))
		TYPE_REPAREP:
			return GameState.defeated_monsters.has("reparep:%d" % int(q.bosque))
	return false


## El Bosque que llamaba ya no puede esperar ayuda: se ha enojado o ha muerto.
static func has_failed(q: Dictionary, map: BosqueMap = null) -> bool:
	var state: String = BosqueStates.state_of(int(q.bosque), map)
	return state == BosqueStates.ENOJADO or state == BosqueStates.MUERTO


## Cumple la misión: active -> completed -> rewarded, relación + per_mission con el Bosque que llamó
## (AdventureRules.reward_bosque_mission), fama y Luz suelta de reward. El salvoconducto termina.
## Devuelve { "relation", "fama", "luz" } o {} si no estaba activa.
static func complete(q: Dictionary) -> Dictionary:
	if not QuestLogic.transition(q, QuestLogic.COMPLETED):
		return {}
	QuestLogic.transition(q, QuestLogic.REWARDED)
	var bosque: int = int(q.bosque)
	var before: int = AdventureRules.relation(bosque)
	AdventureRules.reward_bosque_mission(bosque)
	var r: Dictionary = reward()
	GameState.fama += int(r.get("fama", 0))
	var luz_before: int = GameState.luz
	AdventureRules.set_luz(GameState.luz + int(r.get("luz", 0)))
	EventBus.quest_state_changed.emit(quest_id(q), QuestLogic.REWARDED)
	return { "relation": AdventureRules.relation(bosque) - before, "fama": int(r.get("fama", 0)), "luz": GameState.luz - luz_before }


## Falla la misión: el salvoconducto termina.
static func fail(q: Dictionary) -> bool:
	if not QuestLogic.transition(q, QuestLogic.FAILED):
		return false
	EventBus.quest_state_changed.emit(quest_id(q), QuestLogic.FAILED)
	return true
