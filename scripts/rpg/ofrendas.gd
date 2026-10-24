class_name Ofrendas
extends RefCounted
## Ofrendas del catálogo de objetos (data/items/items.json, kind "ofrenda") y reglas para pagar con
## ellas (ofrendas-v1.md, ADR 0010): una ofrenda se deja entera, se puede completar con Luz suelta
## hasta llegar a N y el excedente se pierde. No se combinan varias. Las ofrendas viven en la bolsa
## (InventoryLogic); `from_bag` da la lista { id, luz } (una entrada por unidad) con la que se
## paga. Lógica pura: no toca GameState; quien paga (AdventureRules, BattleLogic) aplica el
## resultado.


## Entradas del catálogo que son ofrendas, en el orden del archivo.
static func catalog() -> Array:
	return Items.all().filter(func(e: Dictionary) -> bool: return StringName(str(e.kind)) == Items.KIND_OFRENDA)


static func entry(id: StringName) -> Dictionary:
	var e: Dictionary = Items.entry(id)
	return e if Items.kind_of(id) == Items.KIND_OFRENDA else {}


static func is_ofrenda(id: StringName) -> bool:
	return Items.kind_of(id) == Items.KIND_OFRENDA


## Nombre visible (o el propio id si no está en el catálogo).
static func display_name(id: StringName) -> String:
	return Items.display_name(id)


## Elemento { id, luz } de una ofrenda del catálogo.
static func make_item(id: StringName) -> Dictionary:
	return { "id": String(id), "luz": Items.luz_of(id) }


## Ofrendas de la bolsa como lista { id, luz }: una entrada por unidad, en el orden de las casillas.
static func from_bag(bag: Array) -> Array:
	var out: Array = []
	for i: int in bag.size():
		var id: StringName = InventoryLogic.id_at(bag, i)
		if id != &"" and is_ofrenda(id):
			for n: int in InventoryLogic.qty_at(bag, i):
				out.append(make_item(id))
	return out


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


## Índices de una lista de ofrendas (from_bag) con los que se puede pagar `cost`: uno por id (el primero),
## de menor a mayor valor (a igual valor, en el orden de la lista).
static func payable(list: Array, luz: int, cost: int) -> Array[int]:
	var out: Array[int] = []
	var seen: Dictionary = {}
	for i: int in list.size():
		var item: Dictionary = list[i]
		var id: String = str(item.get("id", ""))
		if seen.has(id) or not can_pay(int(item.get("luz", 0)), luz, cost):
			continue
		seen[id] = true
		out.append(i)
	out.sort_custom(func(a: int, b: int) -> bool:
		var va: int = int(list[a].luz)
		var vb: int = int(list[b].luz)
		return va < vb or (va == vb and a < b))
	return out


## Cuántas ofrendas hay de un id en una lista de ofrendas.
static func count_of(list: Array, id: String) -> int:
	var n: int = 0
	for item: Variant in list:
		if item is Dictionary and str(item.get("id", "")) == id:
			n += 1
	return n
