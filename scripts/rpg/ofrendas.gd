class_name Ofrendas
extends RefCounted
## Catálogo de ofrendas (data/items/ofrendas.json) y reglas para pagar con ellas (ofrendas-v1.md,
## ADR 0010): una ofrenda se deja entera, se puede completar con Luz suelta hasta llegar a N y el
## excedente se pierde. No se combinan varias. Lógica pura: no toca GameState; quien paga
## (AdventureRules, BattleLogic) aplica el resultado.

const CATALOG_PATH: String = "res://data/items/ofrendas.json"

static var _catalog: Array = []


static func catalog() -> Array:
	if _catalog.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		assert(data is Dictionary, "No se pudo leer %s" % CATALOG_PATH)
		_catalog = data.ofrendas
	return _catalog


static func entry(id: StringName) -> Dictionary:
	for e: Dictionary in catalog():
		if StringName(str(e.id)) == id:
			return e
	return {}


## Nombre visible (o el propio id si no está en el catálogo).
static func display_name(id: StringName) -> String:
	return str(entry(id).get("name", id))


## Elemento de inventario { id, luz } de una ofrenda del catálogo.
static func make_item(id: StringName) -> Dictionary:
	return { "id": String(id), "luz": int(entry(id).get("luz", 0)) }


## Ids del catálogo con ese origen ("refuge", "villa", "quest"), en el orden del archivo.
static func ids_from(source: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in catalog():
		if str(e.get("source", "")) == source:
			out.append(StringName(str(e.id)))
	return out


## Luz suelta que hace falta para completar una ofrenda de valor `value` hasta `cost`.
static func luz_needed(value: int, cost: int) -> int:
	return maxi(0, cost - value)


## La ofrenda, más la Luz suelta que haga falta, llega al coste.
static func can_pay(value: int, luz: int, cost: int) -> bool:
	return cost > 0 and value + luz >= cost


## Índices del inventario con los que se puede pagar `cost`: uno por id (el primero que aparece),
## de menor a mayor valor (a igual valor, en orden de inventario).
static func payable(inventory: Array, luz: int, cost: int) -> Array[int]:
	var out: Array[int] = []
	var seen: Dictionary = {}
	for i: int in inventory.size():
		var item: Dictionary = inventory[i]
		var id: String = str(item.get("id", ""))
		if seen.has(id) or not can_pay(int(item.get("luz", 0)), luz, cost):
			continue
		seen[id] = true
		out.append(i)
	out.sort_custom(func(a: int, b: int) -> bool:
		var va: int = int(inventory[a].luz)
		var vb: int = int(inventory[b].luz)
		return va < vb or (va == vb and a < b))
	return out


## Cuántas ofrendas hay de un id en el inventario.
static func count_of(inventory: Array, id: String) -> int:
	var n: int = 0
	for item: Variant in inventory:
		if item is Dictionary and str(item.get("id", "")) == id:
			n += 1
	return n
