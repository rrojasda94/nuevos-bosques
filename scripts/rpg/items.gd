class_name Items
extends RefCounted
## Catálogo de objetos (data/items/items.json): ofrendas, armas, máscaras y talismanes, con el
## tamaño de la bolsa y el equipo y la bolsa de una partida nueva. Cada objeto tiene id, kind
## (KIND_*), name, description, stack_max y campos por tipo (ofrenda: luz y source; arma:
## atk_bonus; máscara y talismán: camouflage, que aún no se usa: llega con el sigilo,
## sigilo-y-robo.md; fruto: se guarda con su Bosque de origen, FruitRules). Solo lee datos: el inventario está en InventoryLogic.

const CATALOG_PATH: String = "res://data/items/items.json"
const KIND_OFRENDA: StringName = &"ofrenda"
const KIND_WEAPON: StringName = &"weapon"
const KIND_MASK: StringName = &"mask"
const KIND_TALISMAN: StringName = &"talisman"
const KIND_FRUIT: StringName = &"fruit"
## Id del fruto guardado (FruitRules): uno solo, distinguido en la bolsa por su Bosque de origen.
const FRUIT_ID: StringName = &"fruto"

static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		assert(parsed is Dictionary, "No se pudo leer %s" % CATALOG_PATH)
		_data = parsed
		for e: Dictionary in _data.items:
			_by_id[str(e.id)] = e
	return _data


## Todas las entradas, en el orden del archivo.
static func all() -> Array:
	return data().items


## Entrada del catálogo ({} si no existe).
static func entry(id: StringName) -> Dictionary:
	data()
	return _by_id.get(String(id), {})


static func exists(id: StringName) -> bool:
	return not entry(id).is_empty()


static func kind_of(id: StringName) -> StringName:
	return StringName(str(entry(id).get("kind", "")))


## Nombre visible (o el propio id si no está en el catálogo).
static func display_name(id: StringName) -> String:
	return str(entry(id).get("name", id))


static func description(id: StringName) -> String:
	return str(entry(id).get("description", ""))


## Cuántas unidades caben en una casilla (al menos 1).
static func stack_max(id: StringName) -> int:
	return maxi(1, int(entry(id).get("stack_max", 1)))


## Valor en Luz de una ofrenda (0 si no lo es).
static func luz_of(id: StringName) -> int:
	return int(entry(id).get("luz", 0))


## ATQ que suma un arma equipada (0 si no lo es).
static func atk_bonus(id: StringName) -> int:
	return int(entry(id).get("atk_bonus", 0))


## Casillas de la bolsa.
static func bag_size() -> int:
	return int(data().bag_size)


## Equipo de una partida nueva { main_hand, mask, talisman } → id o "".
static func start_equipped() -> Dictionary:
	return (data().get("start_equipped", {}) as Dictionary).duplicate()


## Objetos de la bolsa de una partida nueva [{ id, qty }].
static func start_bag() -> Array:
	return (data().get("start_bag", []) as Array).duplicate(true)
