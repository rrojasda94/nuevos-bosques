class_name Items
extends RefCounted
## Catálogo de objetos (data/items/items.json): ofrendas, armas, máscaras y talismanes, con el
## tamaño de la bolsa y el equipo y la bolsa de una partida nueva. Cada objeto tiene id, kind
## (KIND_*), name, description, stack_max y campos por tipo (ofrenda: luz y source; arma:
## atk_bonus; máscara y talismán: camouflage, y opcionalmente speed_bonus, def_penalty y max_uses,
## que usa el sigilo, Stealth y sigilo-y-robo.md; fruto: se guarda con su Bosque de origen,
## FruitRules). Solo lee datos: el inventario está en InventoryLogic.
## Armas en el combate táctico (P4, ajustes-playtest-0.5.md 4b y 4d): range, line, back_bonus,
## hit_mod y short_name (weapon_profile). Objetos de combate (acción Objeto, 5a): combat_use y
## use_range.

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


## Casillas que resta a la visión de los Únicos una máscara o un talismán equipado (Stealth).
static func camouflage(id: StringName) -> int:
	return int(entry(id).get("camouflage", 0))


## Nombre corto (ficha del táctico: "ATQ 8 (Lanza +2)"); sin él, el nombre visible.
static func short_name(id: StringName) -> String:
	return str(entry(id).get("short_name", display_name(id)))


## Alcance del ataque con el arma: [mín, máx] en casillas ([1, 1] si no tiene o no es un arma).
static func weapon_range(id: StringName) -> Array[int]:
	var r: Array = entry(id).get("range", [1, 1])
	var lo: int = maxi(1, int(r[0])) if r.size() > 0 else 1
	var hi: int = maxi(lo, int(r[1])) if r.size() > 1 else lo
	return [lo, hi]


## El arma solo golpea en línea ortogonal (lanza; por defecto true). La honda, por encima de todo.
static func weapon_line(id: StringName) -> bool:
	return bool(entry(id).get("line", true))


## Daño extra del arma al golpear por la espalda (el cuchillo, 2).
static func back_bonus(id: StringName) -> int:
	return int(entry(id).get("back_bonus", 0))


## Precisión que suma o resta el arma (la honda, −10).
static func hit_mod(id: StringName) -> int:
	return int(entry(id).get("hit_mod", 0))


## Todo lo que el arma lleva al combate táctico (TacticalBridge): { id, atk_bonus, range, line,
## back_bonus, hit_mod }. {} si `id` no es un arma.
static func weapon_profile(id: StringName) -> Dictionary:
	if kind_of(id) != KIND_WEAPON:
		return {}
	return { "id": id, "atk_bonus": atk_bonus(id), "range": weapon_range(id), "line": weapon_line(id),
		"back_bonus": back_bonus(id), "hit_mod": hit_mod(id) }


## Se usa en combate con la acción Objeto (hoy, el fruto).
static func is_combat_usable(id: StringName) -> bool:
	return bool(entry(id).get("combat_use", false))


## Alcance del objeto de combate: 0 = solo el Adoc; 1 = también un aliado adyacente.
static func use_range(id: StringName) -> int:
	return int(entry(id).get("use_range", 0))


## Camuflaje que resta un arma enfundada (ajustes-playtest-0.5.md, punto 4a; la lanza, 2).
static func sheathed_camo_penalty(id: StringName) -> int:
	return int(entry(id).get("sheathed_camo_penalty", 0))


## Velocidad extra al andar (fracción: 0.3 = un 30% más rápido; talismanes de viaje).
static func speed_bonus(id: StringName) -> float:
	return float(entry(id).get("speed_bonus", 0.0))


## DEF que resta mientras se lleva equipado (0 si nada).
static func def_penalty(id: StringName) -> int:
	return int(entry(id).get("def_penalty", 0))


## Cruces colados hasta que se rompe (0 = no se rompe).
static func max_uses(id: StringName) -> int:
	return int(entry(id).get("max_uses", 0))


## Casillas de la bolsa.
static func bag_size() -> int:
	return int(data().bag_size)


## Equipo de una partida nueva { main_hand, mask, talisman } → id o "".
static func start_equipped() -> Dictionary:
	return (data().get("start_equipped", {}) as Dictionary).duplicate()


## Una partida nueva empieza con el arma en la mano (false: enfundada, 5c).
static func start_weapon_drawn() -> bool:
	return bool(data().get("start_weapon_drawn", false))


## Objetos de la bolsa de una partida nueva [{ id, qty }].
static func start_bag() -> Array:
	return (data().get("start_bag", []) as Array).duplicate(true)
