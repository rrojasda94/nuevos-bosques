class_name InventoryLogic
extends RefCounted
## Bolsa y equipo del Adoc (roadmap-0.3.md #113: bolsa de casillas estilo Minecraft y 3 ranuras:
## mano principal, máscara y talismán). Lógica pura sobre los arrays que recibe (normalmente
## GameState.bag y GameState.equipped); no emite señales ni lee GameState.
## - Bolsa: Array de casillas; cada una es {} (vacía) o { "id": String, "qty": int }. Los frutos
##   llevan además "origin" (id de su Bosque de origen) y "out" (ya se penalizó sacarlos de él,
##   FruitRules); solo apilan con los del mismo origen.
## - Equipo: { "main_hand": id, "mask": id, "talisman": id }, con "" si la ranura está vacía.
## Añadir y quitar son "todo o nada": si no cabe (o no hay tantas), no se toca nada.

const SLOT_MAIN_HAND: StringName = &"main_hand"
const SLOT_MASK: StringName = &"mask"
const SLOT_TALISMAN: StringName = &"talisman"
## Ranuras de equipo, en el orden de la pantalla.
const SLOTS: Array[StringName] = [SLOT_MAIN_HAND, SLOT_MASK, SLOT_TALISMAN]


# --- Bolsa ---------------------------------------------------------------------------------------

static func new_bag(size: int) -> Array:
	var bag: Array = []
	for i: int in size:
		bag.append({})
	return bag


static func is_slot_empty(slot: Variant) -> bool:
	return not (slot is Dictionary) or str(slot.get("id", "")) == "" or int(slot.get("qty", 0)) <= 0


## Id de la casilla `index` (&"" si está vacía o fuera de la bolsa).
static func id_at(bag: Array, index: int) -> StringName:
	if index < 0 or index >= bag.size() or is_slot_empty(bag[index]):
		return &""
	return StringName(str(bag[index].id))


static func qty_at(bag: Array, index: int) -> int:
	return 0 if id_at(bag, index) == &"" else int(bag[index].qty)


## Unidades de un objeto en toda la bolsa.
static func count(bag: Array, id: StringName) -> int:
	var n: int = 0
	for i: int in bag.size():
		if id_at(bag, i) == id:
			n += int(bag[i].qty)
	return n


static func free_slots(bag: Array) -> int:
	var n: int = 0
	for slot: Variant in bag:
		if is_slot_empty(slot):
			n += 1
	return n


static func is_full(bag: Array) -> bool:
	return free_slots(bag) == 0


## Bosque de origen de la casilla (-1 si no tiene: todo lo que no es fruto).
static func origin_at(bag: Array, index: int) -> int:
	return -1 if id_at(bag, index) == &"" else int(bag[index].get("origin", -1))


## La casilla tiene ese objeto con ese origen (apilan juntos).
static func _matches(bag: Array, index: int, id: StringName, origin: int) -> bool:
	return id_at(bag, index) == id and origin_at(bag, index) == origin


## Cuántas unidades de `id` (con ese origen) caben aún (completando montones y en casillas vacías).
static func room_for(bag: Array, id: StringName, stack_max: int, origin: int = -1) -> int:
	var room: int = 0
	for i: int in bag.size():
		if is_slot_empty(bag[i]):
			room += stack_max
		elif _matches(bag, i, id, origin):
			room += maxi(0, stack_max - int(bag[i].qty))
	return room


## Caben `qty` unidades de un objeto del catálogo (con ese origen, para los frutos).
static func can_add(bag: Array, id: StringName, qty: int = 1, origin: int = -1) -> bool:
	return Items.exists(id) and qty > 0 and room_for(bag, id, Items.stack_max(id), origin) >= qty


## Añade `qty` unidades de un objeto del catálogo (apila hasta su stack_max). false si no caben
## todas: entonces no añade ninguna. `origin`: Bosque de origen de un fruto (-1 = ninguno).
static func add(bag: Array, id: StringName, qty: int = 1, origin: int = -1) -> bool:
	if not Items.exists(id):
		return false
	return add_stacked(bag, id, qty, Items.stack_max(id), origin)


## Añade con un tope de montón dado: primero completa los montones del mismo id (y origen) y luego
## ocupa las casillas vacías de la primera a la última. false (sin tocar nada) si no cabe todo.
static func add_stacked(bag: Array, id: StringName, qty: int, stack_max: int, origin: int = -1) -> bool:
	if qty <= 0 or id == &"" or room_for(bag, id, stack_max, origin) < qty:
		return false
	var left: int = qty
	for i: int in bag.size():
		if left > 0 and _matches(bag, i, id, origin):
			var put: int = mini(left, stack_max - int(bag[i].qty))
			if put > 0:
				bag[i].qty = int(bag[i].qty) + put
				left -= put
	for i: int in bag.size():
		if left > 0 and is_slot_empty(bag[i]):
			var put: int = mini(left, stack_max)
			bag[i] = { "id": String(id), "qty": put }
			if origin >= 0:
				bag[i].origin = origin
				bag[i].out = false
			left -= put
	return true


## Quita `qty` unidades de un objeto, empezando por la última casilla que lo tiene. false (sin
## tocar nada) si no hay tantas.
static func remove(bag: Array, id: StringName, qty: int = 1) -> bool:
	if qty <= 0 or count(bag, id) < qty:
		return false
	var left: int = qty
	for i: int in range(bag.size() - 1, -1, -1):
		if left > 0 and id_at(bag, i) == id:
			var take: int = mini(left, int(bag[i].qty))
			left -= take
			_take_at(bag, i, take)
	return true


## Quita `qty` unidades de la casilla `index`. false si no hay tantas.
static func remove_at(bag: Array, index: int, qty: int = 1) -> bool:
	if qty <= 0 or qty_at(bag, index) < qty:
		return false
	_take_at(bag, index, qty)
	return true


static func _take_at(bag: Array, index: int, qty: int) -> void:
	var left: int = int(bag[index].qty) - qty
	if left <= 0:
		bag[index] = {}
	else:
		bag[index].qty = left


# --- Equipo --------------------------------------------------------------------------------------

static func new_equipped() -> Dictionary:
	var out: Dictionary = {}
	for slot: StringName in SLOTS:
		out[String(slot)] = ""
	return out


## Ranura en la que se equipa un tipo de objeto (&"" si no se equipa: las ofrendas).
static func slot_for_kind(kind: StringName) -> StringName:
	match kind:
		Items.KIND_WEAPON:
			return SLOT_MAIN_HAND
		Items.KIND_MASK:
			return SLOT_MASK
		Items.KIND_TALISMAN:
			return SLOT_TALISMAN
	return &""


## Ranura en la que se equipa un objeto del catálogo (&"" si no se equipa).
static func slot_for(id: StringName) -> StringName:
	return slot_for_kind(Items.kind_of(id))


static func is_equippable(id: StringName) -> bool:
	return slot_for(id) != &""


## Id equipado en una ranura (&"" si está vacía).
static func equipped_in(equipped: Dictionary, slot: StringName) -> StringName:
	return StringName(str(equipped.get(String(slot), "")))


## Equipa el objeto de la casilla `index`: pasa a su ranura y, si la ranura estaba ocupada, el
## objeto anterior vuelve a la bolsa (cambio). false (sin tocar nada) si la casilla está vacía,
## el objeto no se equipa o el anterior no cabe en la bolsa.
static func equip(bag: Array, equipped: Dictionary, index: int) -> bool:
	var id: StringName = id_at(bag, index)
	var slot: StringName = slot_for(id)
	if slot == &"":
		return false
	var before: Array = bag.duplicate(true)
	var previous: StringName = equipped_in(equipped, slot)
	_take_at(bag, index, 1)
	if previous != &"" and not _put_back(bag, previous, index):
		bag.assign(before)
		return false
	equipped[String(slot)] = String(id)
	return true


## Desequipa una ranura: su objeto vuelve a la bolsa. false si estaba vacía o la bolsa no tiene
## sitio.
static func unequip(bag: Array, equipped: Dictionary, slot: StringName) -> bool:
	var id: StringName = equipped_in(equipped, slot)
	if id == &"" or not add_stacked(bag, id, 1, Items.stack_max(id)):
		return false
	equipped[String(slot)] = ""
	return true


## Devuelve a la bolsa un objeto desequipado, preferentemente en la casilla `index` si quedó vacía.
static func _put_back(bag: Array, id: StringName, index: int) -> bool:
	if is_slot_empty(bag[index]):
		bag[index] = { "id": String(id), "qty": 1 }
		return true
	return add_stacked(bag, id, 1, Items.stack_max(id))


# --- Saneado (guardado) --------------------------------------------------------------------------

## Bolsa de `size` casillas a partir de datos guardados: descarta ids desconocidos y acota las
## cantidades a 1..stack_max.
static func sanitize_bag(value: Variant, size: int) -> Array:
	var bag: Array = new_bag(size)
	if not (value is Array):
		return bag
	for i: int in mini(size, value.size()):
		var slot: Variant = value[i]
		if is_slot_empty(slot) or not Items.exists(StringName(str(slot.id))):
			continue
		var id: StringName = StringName(str(slot.id))
		bag[i] = { "id": String(id), "qty": clampi(int(slot.qty), 1, Items.stack_max(id)) }
		if slot.has("origin"):
			bag[i].origin = int(slot.origin)
			bag[i].out = bool(slot.get("out", false))
	return bag


## Equipo a partir de datos guardados: cada ranura solo con un objeto de su tipo.
static func sanitize_equipped(value: Variant) -> Dictionary:
	var out: Dictionary = new_equipped()
	if not (value is Dictionary):
		return out
	for slot: StringName in SLOTS:
		var id: StringName = StringName(str(value.get(String(slot), "")))
		if id != &"" and slot_for(id) == slot:
			out[String(slot)] = String(id)
	return out
