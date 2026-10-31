class_name Trade
extends RefCounted
## Trueque mínimo en la villa (P5; ajustes-playtest-0.5.md 5b, ADR 0017 §5, npcs-y-villas.md):
## el Sarua cambia ofrendas o Luz suelta por máscaras y talismanes, y el Paruas, por las armas.
## - Catálogo y precios en data/npcs/<id>.json, bloque "trade": { daily_stock, catalog: [{ id,
##   price }] }. Sin bloque "trade", el NPC no comercia.
## - Existencias: cada artesano ofrece daily_stock objetos de su catálogo (todos si tiene menos),
##   elegidos por la seed de la partida, la villa, el NPC y el día (GameState.day sube en el riutash
##   del amanecer, DayManager). Cada objeto se cambia una vez por día, así que como mucho
##   daily_stock objetos al día por artesano y villa.
## - Lo vendido hoy se guarda en GameState.trade_sold { "<villa>:<npc>": { day, sold: [ids] } }; con
##   otro día, no cuenta (se repone).
## - Las armas que ya tienes (bolsa o equipo) no se ofrecen. Las máscaras y los talismanes sí: la
##   máscara de ceniza se rompe y se vuelve a por otra.
## - Se paga como el peaje (Ofrendas): con Luz suelta, o con una ofrenda entera completada con Luz
##   si no llega; el excedente se pierde. No vende ni compra ofrendas.
## Sin escena: TradeDialog lleva el diálogo y la exploración solo lo abre.

## Resultado de buy().
const OK: StringName = &"ok"
const NOT_OFFERED: StringName = &"not_offered"
const LIMIT: StringName = &"limit"
const NO_FUNDS: StringName = &"no_funds"
const BAG_FULL: StringName = &"bag_full"
## Formas de pago (pay_options, buy).
const PAY_LUZ: StringName = &"luz"
const PAY_OFRENDA: StringName = &"ofrenda"
const SALT_STOCK: int = 47


## Bloque "trade" del NPC ({} si no comercia).
static func config(npc_id: StringName) -> Dictionary:
	if npc_id == &"" or not FileAccess.file_exists(NpcDialogue.NPC_PATH % npc_id):
		return {}
	var raw: Variant = NpcDialogue.data(npc_id).get("trade", {})
	return raw if raw is Dictionary else {}


static func is_trader(npc_id: StringName) -> bool:
	return not catalog(npc_id).is_empty()


## Catálogo completo del NPC [{ id, price }], en el orden del archivo (solo objetos que existen).
static func catalog(npc_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in config(npc_id).get("catalog", []):
		if e is Dictionary and Items.exists(StringName(str(e.get("id", "")))):
			out.append({ "id": StringName(str(e.id)), "price": maxi(1, int(e.get("price", 1))) })
	return out


## Precio de un objeto en el catálogo del NPC (0 si no lo tiene).
static func price_of(npc_id: StringName, item_id: StringName) -> int:
	for e: Dictionary in catalog(npc_id):
		if e.id == item_id:
			return int(e.price)
	return 0


## Objetos que ofrece al día (y como mucho que cambia al día).
static func daily_stock(npc_id: StringName) -> int:
	return maxi(1, int(config(npc_id).get("daily_stock", 3)))


## Clave de la villa: su chunk "x,y".
static func villa_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


static func _key(npc_id: StringName, villa: String) -> String:
	return "%s:%s" % [villa, npc_id]


## Existencias del día [{ id, price }]: daily_stock entradas del catálogo elegidas por seed (en el
## orden del catálogo). Determinista con la misma seed, villa, NPC y día.
static func stock(npc_id: StringName, seed_value: int, villa: String, day: int) -> Array[Dictionary]:
	var all: Array[Dictionary] = catalog(npc_id)
	var n: int = daily_stock(npc_id)
	if all.size() <= n:
		return all
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, SALT_STOCK, villa, String(npc_id), day])
	var picks: Array[int] = []
	for i: int in all.size():
		picks.append(i)
	# Fisher-Yates con el RNG propio (no toca GameState.rng).
	for i: int in range(picks.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = picks[i]
		picks[i] = picks[j]
		picks[j] = t
	var chosen: Array[int] = picks.slice(0, n)
	chosen.sort()
	var out: Array[Dictionary] = []
	for i: int in chosen:
		out.append(all[i])
	return out


## Ids cambiados hoy con ese NPC en esa villa (vacío si lo guardado es de otro día).
static func sold_today(npc_id: StringName, villa: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var e: Variant = GameState.trade_sold.get(_key(npc_id, villa), {})
	if not e is Dictionary or int(e.get("day", 0)) != GameState.day:
		return out
	for id: Variant in e.get("sold", []):
		out.append(StringName(str(id)))
	return out


## Ya no cambia nada más hoy: llegó a daily_stock objetos.
static func limit_reached(npc_id: StringName, villa: String) -> bool:
	return sold_today(npc_id, villa).size() >= daily_stock(npc_id)


## Un arma que ya tienes no se ofrece.
static func is_hidden(item_id: StringName) -> bool:
	return Items.kind_of(item_id) == Items.KIND_WEAPON and AdventureRules.owns(item_id)


## Lo que ofrece ahora [{ id, price }]: las existencias de hoy sin lo ya cambiado ni las armas que
## ya tienes. Vacío si llegó al límite del día.
static func offer(npc_id: StringName, villa: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if limit_reached(npc_id, villa):
		return out
	var sold: Array[StringName] = sold_today(npc_id, villa)
	for e: Dictionary in stock(npc_id, GameState.seed_value, villa, GameState.day):
		if not sold.has(e.id) and not is_hidden(e.id):
			out.append(e)
	return out


## Formas de pagar `price` con lo que llevas: [{ kind: PAY_LUZ }] si llega la Luz suelta, y una
## { kind: PAY_OFRENDA, id, value, luz } por tipo de ofrenda de la bolsa que, con la Luz que haga
## falta (luz), llega al precio; de menor a mayor valor.
static func pay_options(price: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if price <= 0:
		return out
	if GameState.luz >= price:
		out.append({ "kind": PAY_LUZ })
	var list: Array = AdventureRules.bag_ofrendas()
	for i: int in Ofrendas.payable(list, GameState.luz, price):
		var value: int = int(list[i].luz)
		out.append({ "kind": PAY_OFRENDA, "id": StringName(str(list[i].id)), "value": value,
			"luz": Ofrendas.luz_needed(value, price) })
	return out


static func can_afford(price: int) -> bool:
	return not pay_options(price).is_empty()


## Cambia `item_id` con el NPC de la villa pagando con `payment` (una entrada de pay_options; sin
## "kind", con Luz). Si sale bien (OK): cobra, mete el objeto en la bolsa, lo anota como vendido hoy
## y emite EventBus.item_traded. Si no, no cambia nada y devuelve LIMIT, NOT_OFFERED, NO_FUNDS o
## BAG_FULL.
static func buy(npc_id: StringName, villa: String, item_id: StringName, payment: Dictionary = {}) -> StringName:
	if limit_reached(npc_id, villa):
		return LIMIT
	var entry: Dictionary = {}
	for e: Dictionary in offer(npc_id, villa):
		if e.id == item_id:
			entry = e
	if entry.is_empty():
		return NOT_OFFERED
	var price: int = int(entry.price)
	var kind: StringName = StringName(str(payment.get("kind", PAY_LUZ)))
	var ofrenda: StringName = StringName(str(payment.get("id", "")))
	var luz_cost: int = price
	var value: int = 0
	if kind == PAY_OFRENDA:
		if not Ofrendas.is_ofrenda(ofrenda) or InventoryLogic.count(GameState.bag, ofrenda) <= 0:
			return NO_FUNDS
		value = Items.luz_of(ofrenda)
		luz_cost = Ofrendas.luz_needed(value, price)
	elif kind != PAY_LUZ:
		return NO_FUNDS
	if GameState.luz < luz_cost:
		return NO_FUNDS
	# La ofrenda sale de la bolsa antes de mirar si cabe el objeto (deja su casilla libre).
	var bag: Array = GameState.bag.duplicate(true)
	if kind == PAY_OFRENDA:
		InventoryLogic.remove(bag, ofrenda)
	if not InventoryLogic.can_add(bag, item_id):
		return BAG_FULL
	InventoryLogic.add(bag, item_id)
	GameState.bag = bag
	AdventureRules.set_luz(GameState.luz - luz_cost)
	_mark_sold(npc_id, villa, item_id)
	EventBus.item_traded.emit(npc_id, item_id, String(ofrenda) if kind == PAY_OFRENDA else "", luz_cost)
	return OK


static func _mark_sold(npc_id: StringName, villa: String, item_id: StringName) -> void:
	var sold: Array[StringName] = sold_today(npc_id, villa)
	sold.append(item_id)
	GameState.trade_sold[_key(npc_id, villa)] = {
		"day": GameState.day, "sold": sold.map(func(id: StringName) -> String: return String(id)) }
	# Lo de otros días ya no cuenta: no se guarda.
	for key: String in GameState.trade_sold.keys():
		if int(GameState.trade_sold[key].get("day", 0)) != GameState.day:
			GameState.trade_sold.erase(key)


## GameState.trade_sold leído de un guardado, saneado: { "<villa>:<npc>": { day >= 1, sold: [ids de
## objetos que existen, sin repetir] } }. Descarta lo que no tenga esa forma.
static func sanitize_sold(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not value is Dictionary:
		return out
	for key: Variant in value:
		var e: Variant = value[key]
		if not e is Dictionary or int(e.get("day", 0)) < 1 or not e.get("sold", []) is Array:
			continue
		var sold: Array[String] = []
		for id: Variant in e.sold:
			if Items.exists(StringName(str(id))) and not sold.has(str(id)):
				sold.append(str(id))
		out[str(key)] = { "day": int(e.day), "sold": sold }
	return out
