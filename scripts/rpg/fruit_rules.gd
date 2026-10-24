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
## Escribe en GameState (emptied_fruit_trees, fruit_taken). No dibuja ni abre diálogos: la
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


## Toma el fruto del frutal del Bosque `bosque_id` (`home`: Bosque natal). Cura, vacía el árbol y
## cuenta el fruto del Bosque en el Momento; si es robo, lo registra (AdventureRules.record_theft).
## Devuelve { "healed": PV ganados, "theft": bool } o {} si el árbol no tenía fruto.
static func take(coord: Vector2i, cell: Vector2i, bosque_id: int, home: int) -> Dictionary:
	if not has_fruit(coord, cell):
		return {}
	var theft: bool = is_theft(bosque_id, home)
	var before: int = GameState.hp
	AdventureRules.set_hp(GameState.hp + heal_amount(AdventureRules.max_hp()))
	GameState.emptied_fruit_trees.append(key(coord, cell))
	GameState.fruit_taken[str(bosque_id)] = taken_in(bosque_id) + 1
	if theft:
		AdventureRules.record_theft(bosque_id)
	return { "healed": GameState.hp - before, "theft": theft }


## Riutash: todos los frutales rebrotan y ningún Bosque ha dado fruto en el nuevo Momento.
static func regrow() -> void:
	GameState.emptied_fruit_trees.clear()
	GameState.fruit_taken.clear()
