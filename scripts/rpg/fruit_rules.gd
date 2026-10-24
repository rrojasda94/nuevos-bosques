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
##   límite por Momento y para el robo. Solo se come dentro de su Bosque de origen. Al entrar en
##   otro Bosque con él, la relación con el de origen baja relation_per_fruit_taken_out por fruto,
##   una vez por salida (la casilla queda marcada "out" hasta volver a su Bosque).
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


## El fruto de la casilla `index` se puede comer en el Bosque `bosque_id` (solo en su origen).
static func can_eat(index: int, bosque_id: int) -> bool:
	return InventoryLogic.id_at(GameState.bag, index) == Items.FRUIT_ID and bosque_id >= 0 		and InventoryLogic.origin_at(GameState.bag, index) == bosque_id


## Come un fruto guardado (casilla `index`) estando en el Bosque `bosque_id`. Devuelve los PV
## ganados, o -1 si no se puede (no es fruto o no es de este Bosque).
static func eat_from_bag(index: int, bosque_id: int) -> int:
	if not can_eat(index, bosque_id):
		return -1
	var before: int = GameState.hp
	InventoryLogic.remove_at(GameState.bag, index)
	AdventureRules.set_hp(GameState.hp + heal_amount(AdventureRules.max_hp()))
	return GameState.hp - before


## El Adoc entra en un chunk del Bosque `bosque_id`. Los frutos de otro origen que aún no se habían
## sacado bajan la relación con su Bosque (relation_per_fruit_taken_out por fruto) y quedan
## marcados; los de este Bosque se desmarcan (volver a sacarlos penaliza otra vez). No
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
	return taken_out


## Riutash: todos los frutales rebrotan y ningún Bosque ha dado fruto en el nuevo Momento.
static func regrow() -> void:
	GameState.emptied_fruit_trees.clear()
	GameState.fruit_taken.clear()
