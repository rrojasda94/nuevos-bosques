class_name FruitRules
extends RefCounted
## Frutos del Bosque (bosques-y-relacion.md, sección Fruto). Regla del dueño: "si pagas tu peaje
## puedes tomar un fruto por momento. Pero si en otro arbol del mismo bosque tomas un fruto, es
## robo. solo 1 por momento. el arbol del que tomaste queda vacio. No todos los arboles tienen
## fruto."
## - Un frutal (ChunkData.Tile.FRUIT_TREE, una fracción de los árboles) da un fruto que cura
##   heal_pct de los PV máximos y queda vacío hasta el próximo riutash.
## - El límite es por Bosque: en un Bosque con permiso (el natal o uno con el peaje pagado) el
##   primer fruto de cada Momento lo da el Bosque; el segundo, de cualquier árbol, es robo.
## - En un Bosque sin permiso (no pagado) tomar fruto es robo desde el primero.
## - Guardar (dueño: "puedes elegir solo coger el fruto y almacenarlo en el inventario para
##   consumirlo dentro del bosque luego. no puedes sacar un fruto de su bosque sino dañas su
##   relación"): el fruto va a la bolsa con su Bosque de origen, sin curar. Cuenta igual para el
##   límite por Momento y para el robo. Al entrar en otro Bosque con él, la relación con el de
##   origen baja relation_per_fruit_taken_out por fruto, una vez por salida (la casilla queda
##   marcada "out" hasta volver a su Bosque).
## - Comer fuera (dueño, 0.3: "Puedes comer el fruto del bosque en otro lado pero [...] esto
##   perjudica tu relación con dicho bosque"): se puede comer en cualquier sitio; fuera de su
##   Bosque de origen la relación con él baja además relation_per_fruit_eaten_away.
## Escribe en GameState (emptied_fruit_trees, fruit_taken, bag). No dibuja ni abre diálogos: la
## exploración decide qué mostrar. Los números viven en data/combat/balance.json (bloque fruit).


static func config() -> Dictionary:
	return AdventureRules.balance().get("fruit", {})


## PV que cura un fruto con `hp_max` PV máximos (redondeo hacia arriba).
static func heal_amount(hp_max: int) -> int:
	return ceili(hp_max * float(config().get("heal_pct", 25)) / 100.0)


## Clave del frutal en el guardado: chunk (x, y) y casilla (z, w).
static func key(coord: Vector2i, cell: Vector2i) -> Vector4i:
	return Vector4i(coord.x, coord.y, cell.x, cell.y)


static func has_fruit(coord: Vector2i, cell: Vector2i) -> bool:
	return not GameState.emptied_fruit_trees.has(key(coord, cell))


## El Bosque deja tomar fruto: es el natal o se ha pagado su peaje (AdventureRules.is_paid). Un
## Bosque forzado (se cruza tras vencer a un Botarramas sin pagar) no da permiso.
static func has_permission(bosque_id: int, home: int) -> bool:
	return AdventureRules.is_paid(bosque_id, home)


## Frutos tomados en el Bosque en este Momento.
static func taken_in(bosque_id: int) -> int:
	return int(GameState.fruit_taken.get(str(bosque_id), 0))


## Tomar un fruto ahora en este Bosque sería robar: sin permiso, o ya se tomó uno en el Momento.
static func is_theft(bosque_id: int, home: int) -> bool:
	return not has_permission(bosque_id, home) or taken_in(bosque_id) > 0


# --- Permiso a la vista (ajustes-playtest-0.5.md, punto 2: la regla no cambia) -------------------

## Estados del permiso del fruto en un Bosque (icono del HUD, avisos y confirmación del robo).
const GRANTED: StringName = &"granted"
const USED: StringName = &"used"
const FORCED: StringName = &"forced"
const SNEAKED: StringName = &"sneaked"
const CLOSED: StringName = &"closed"


## Permiso del fruto ahora en el Bosque `bosque_id` (`home`: natal): GRANTED (natal, pagado,
## salvoconducto o que no cobra, y sin fruto tomado en el Momento), USED (con permiso, pero ya dio
## el de este Momento), o sin permiso: FORCED (venciste a un Botarramas sin pagar), SNEAKED (colado)
## o CLOSED.
static func permission_state(bosque_id: int, home: int) -> StringName:
	if has_permission(bosque_id, home):
		return USED if taken_in(bosque_id) > 0 else GRANTED
	if AdventureRules.is_forced(bosque_id):
		return FORCED
	if AdventureRules.is_sneaked(bosque_id):
		return SNEAKED
	return CLOSED


## Permiso del fruto donde está el Adoc (GameState.chunk_coord en el reparto de la partida), o &""
## fuera de un Bosque o sin partida. Lo lee el HUD.
static func current_permission_state() -> StringName:
	if MapLogic.region_plan() == null:
		return &""
	var bosque_id: int = MapLogic.current_bosques().bosque_at(GameState.chunk_coord)
	if bosque_id < 0:
		return &""
	return permission_state(bosque_id, AdventureRules.current_home())


## Línea que el aviso de entrada añade al entrar en un Bosque sin permiso de fruto (forzado o
## colado), o "" si no hace falta. Una vez por entrada: la exploración la pone con los demás avisos.
static func entry_notice(bosque_id: int, home: int) -> String:
	match permission_state(bosque_id, home):
		FORCED:
			return Texts.get_text("fruit_entry_forced")
		SNEAKED:
			return Texts.get_text("fruit_entry_sneaked")
	return ""


## Pregunta del frutal (`can_store`: cabe en la bolsa): { text, actions, options, cursor }.
## `actions`: &"eat", &"store" (si cabe) y &"leave"; `options`: sus textos; `cursor`: la opción
## marcada al abrir. Si sería robo, el título dice el motivo (el estado del permiso), la opción de
## tomarlo se llama "Robarlo" y el cursor empieza en "Dejarlo".
static func prompt(bosque_id: int, home: int, store_fits: bool) -> Dictionary:
	var actions: Array[StringName] = [&"eat"]
	if store_fits:
		actions.append(&"store")
	actions.append(&"leave")
	var theft: bool = is_theft(bosque_id, home)
	var options: Array[String] = []
	for a: StringName in actions:
		options.append(Texts.get_text(("fruit_steal_" if theft and a != &"leave" else "fruit_") + String(a)))
	var text: String = Texts.get_text("fruit_prompt")
	if theft:
		text = Texts.get_text("fruit_theft_title")
		var reason: String = theft_reason(permission_state(bosque_id, home))
		if reason != "":
			text += "\n" + reason
	return { "text": text, "actions": actions, "options": options, "cursor": actions.size() - 1 if theft else 0 }


## Segunda línea del título del robo según el estado del permiso ("" si no hay motivo que añadir).
static func theft_reason(state: StringName) -> String:
	match state:
		FORCED:
			return Texts.get_text("fruit_reason_forced")
		SNEAKED:
			return Texts.get_text("fruit_reason_sneaked")
		USED:
			return Texts.get_text("fruit_reason_used")
	return ""


## Cabe en la bolsa un fruto de ese Bosque (si no, solo se puede comer).
static func can_store(bosque_id: int) -> bool:
	return InventoryLogic.can_add(GameState.bag, Items.FRUIT_ID, 1, bosque_id)


## Toma el fruto del frutal del Bosque `bosque_id` (`home`: Bosque natal). Lo come (cura) o, con
## `store`, lo guarda en la bolsa con su origen. Vacía el árbol y cuenta el fruto del Bosque en el
## Momento; si es robo, lo registra (AdventureRules.record_theft). Devuelve { "healed": PV
## ganados, "stored": bool, "theft": bool } o {} si el árbol no tenía fruto o no cabe al guardar.
static func take(coord: Vector2i, cell: Vector2i, bosque_id: int, home: int, store: bool = false) -> Dictionary:
	if not has_fruit(coord, cell) or (store and not can_store(bosque_id)):
		return {}
	var theft: bool = is_theft(bosque_id, home)
	var before: int = GameState.hp
	if store:
		InventoryLogic.add(GameState.bag, Items.FRUIT_ID, 1, bosque_id)
	else:
		AdventureRules.set_hp(GameState.hp + heal_amount(AdventureRules.max_hp()))
	GameState.emptied_fruit_trees.append(key(coord, cell))
	GameState.fruit_taken[str(bosque_id)] = taken_in(bosque_id) + 1
	if theft:
		AdventureRules.record_theft(bosque_id)
	return { "healed": GameState.hp - before, "stored": store, "theft": theft }


## La casilla `index` de la bolsa tiene un fruto, que se puede comer en cualquier sitio.
static func can_eat(index: int, _bosque_id: int = -1) -> bool:
	return InventoryLogic.id_at(GameState.bag, index) == Items.FRUIT_ID


## Comer ahora el fruto de la casilla `index` en el Bosque `bosque_id` sería comerlo lejos de su
## Bosque de origen (y bajaría la relación con él).
static func is_eaten_away(index: int, bosque_id: int) -> bool:
	if not can_eat(index):
		return false
	var origin: int = InventoryLogic.origin_at(GameState.bag, index)
	return origin >= 0 and origin != bosque_id


## Come un fruto guardado (casilla `index`) estando en el Bosque `bosque_id`. Fuera de su Bosque de
## origen, la relación con él baja relation_per_fruit_eaten_away. Devuelve { "healed": PV ganados,
## "away_from": Bosque de origen si se comió lejos de él (-1 si no) }, o {} si no es un fruto.
static func eat_from_bag(index: int, bosque_id: int) -> Dictionary:
	if not can_eat(index):
		return {}
	var away_from: int = InventoryLogic.origin_at(GameState.bag, index) if is_eaten_away(index, bosque_id) else -1
	var before: int = GameState.hp
	InventoryLogic.remove_at(GameState.bag, index)
	AdventureRules.set_hp(GameState.hp + heal_amount(AdventureRules.max_hp()))
	if away_from >= 0:
		AdventureRules.change_relation(away_from,
			int(AdventureRules.balance().bosque_memory.get("relation_per_fruit_eaten_away", 0)))
	return { "healed": GameState.hp - before, "away_from": away_from }


## El Adoc entra en un chunk del Bosque `bosque_id`. Los frutos de otro origen que aún no se habían
## sacado bajan la relación con su Bosque (relation_per_fruit_taken_out por fruto) y quedan
## marcados (y la Senda baja por cada uno); los de este Bosque se desmarcan (volver a sacarlos penaliza otra vez). No
## desaparecen. Devuelve cuántos frutos se acaban de sacar.
static func bosque_entered(bosque_id: int) -> int:
	var per: int = int(AdventureRules.balance().bosque_memory.get("relation_per_fruit_taken_out", 0))
	var taken_out: int = 0
	for i: int in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) != Items.FRUIT_ID:
			continue
		var slot: Dictionary = GameState.bag[i]
		var origin: int = InventoryLogic.origin_at(GameState.bag, i)
		if origin == bosque_id:
			slot.out = false
		elif bosque_id >= 0 and origin >= 0 and not bool(slot.get("out", false)):
			slot.out = true
			AdventureRules.change_relation(origin, per * int(slot.qty))
			taken_out += int(slot.qty)
	# Sacar frutos guardados de su Bosque baja la Senda (fruit_taken_out por fruto).
	Senda.record(Senda.FRUIT_TAKEN_OUT, taken_out)
	return taken_out


# --- Mundo 2.0 (WorldChunk, ADR 0014 §7) --------------------------------------------------------
# El frutal es un objeto FRUIT_TREE de 2×2. Su clave en emptied_fruit_trees es key(coord, esquina
# noroeste del objeto), así que da igual desde cuál de sus casillas se pregunte. El fruto se toma
# desde cualquier casilla vecina (también en diagonal). Las reglas son las de arriba.

## Esquina noroeste (casilla del chunk) del frutal que tapa `cell`, o (-1, -1) si no es un frutal.
static func tree_origin(chunk: WorldChunk, cell: Vector2i) -> Vector2i:
	var obj: Dictionary = chunk.object_at(cell)
	if obj.get("kind", -1) != WorldChunk.ObjectKind.FRUIT_TREE:
		return Vector2i(-1, -1)
	return obj.cell


## Es un frutal (cualquiera de sus casillas).
static func is_fruit_tree_world(chunk: WorldChunk, cell: Vector2i) -> bool:
	return tree_origin(chunk, cell).x >= 0


## Clave del frutal que tapa `cell`: chunk y esquina noroeste.
static func key_world(chunk: WorldChunk, cell: Vector2i) -> Vector4i:
	return key(chunk.coord, tree_origin(chunk, cell))


## El frutal que tapa `cell` tiene fruto (false si no es un frutal).
static func has_fruit_world(chunk: WorldChunk, cell: Vector2i) -> bool:
	return is_fruit_tree_world(chunk, cell) and has_fruit(chunk.coord, tree_origin(chunk, cell))


## Con los pies en la casilla global `feet_world_cell` se llega al frutal que tapa `cell`: los pies
## están en una de las casillas vecinas de su 2×2 (también en diagonal).
static func can_reach_world(chunk: WorldChunk, cell: Vector2i, feet_world_cell: Vector2i) -> bool:
	if not is_fruit_tree_world(chunk, cell):
		return false
	var obj: Dictionary = chunk.object_at(cell)
	var rect := Rect2i(WorldCoords.to_world_cell(chunk.coord, obj.cell), obj.size)
	return Interaction.is_beside(rect, feet_world_cell) and not rect.has_point(feet_world_cell)


## Como take(), con el frutal que tapa `cell` (cualquiera de sus casillas). {} si no es un frutal,
## no tiene fruto o no cabe al guardar.
static func take_world(chunk: WorldChunk, cell: Vector2i, bosque_id: int, home: int, store: bool = false) -> Dictionary:
	if not is_fruit_tree_world(chunk, cell):
		return {}
	return take(chunk.coord, tree_origin(chunk, cell), bosque_id, home, store)


## Riutash: todos los frutales rebrotan y ningún Bosque ha dado fruto en el nuevo Momento.
static func regrow() -> void:
	GameState.emptied_fruit_trees.clear()
	GameState.fruit_taken.clear()
