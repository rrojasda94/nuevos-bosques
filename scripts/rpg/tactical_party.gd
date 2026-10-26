class_name TacticalParty
extends RefCounted
## Elección de la party antes del combate táctico (combate-tactico.md, "Tu party"; #188, PR T1b).
## Lógica pura salvo last_choice / save_choice, que leen y guardan GameState.last_party.
## - Candidatos: los aliados presentes del BattleLogic (adoc aliados, Únicos del Bosque, la Llamada
##   del Bosque; más adelante, el grupo garelino). El Adoc del jugador siempre entra y ocupa una
##   plaza del cupo: se eligen hasta cupo − 1 aliados.
## - Cada aliado tiene una clave estable (ally_keys): su `party_key` si la trae; si no, su tipo y el
##   número de aparición de ese tipo ("adoc:0", "botarramas:1"). La última elección se guarda como
##   esas claves.
## - Preselección: los aliados cuya clave estaba en la última elección, en el orden de la lista;
##   si quedan plazas libres, se completan con los demás en orden (la party más grande que cabe).
## - No se pregunta (needs_prompt false) si la party entera cabe en el cupo o en una emboscada del
##   enemigo (no hay tiempo: entra la última party guardada; T6 creará las emboscadas).
## - Los aliados que no se eligen esperan en el borde y entran como refuerzo (TacticalBattle).


## Claves estables de los aliados (en su orden).
static func ally_keys(allies: Array) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for a: Variant in allies:
		var ally: Dictionary = a
		if ally.has("party_key"):
			out.append(str(ally.party_key))
			continue
		var kind: String = str(ally.get("kind", "adoc"))
		var n: int = int(seen.get(kind, 0))
		seen[kind] = n + 1
		out.append("%s:%d" % [kind, n])
	return out


## Plazas para aliados con un cupo por bando (el Adoc ocupa una).
static func ally_slots(quota: int) -> int:
	return maxi(quota - 1, 0)


## Hay que preguntar: hay más aliados que plazas y no es una emboscada.
static func needs_prompt(ally_count: int, quota: int, ambush: bool = false) -> bool:
	return not ambush and ally_count > ally_slots(quota)


## Índices de aliados preseleccionados: los de la última elección (`last`, claves), completados con
## los demás en orden hasta llenar las plazas.
static func preselect(keys: Array[String], last: Array, quota: int) -> Array[int]:
	var slots: int = ally_slots(quota)
	var out: Array[int] = []
	for i: int in keys.size():
		if out.size() < slots and last.has(keys[i]):
			out.append(i)
	for i: int in keys.size():
		if out.size() >= slots:
			break
		if not out.has(i):
			out.append(i)
	out.sort()
	return out


## Elección con o sin pregunta: { prompt: bool, chosen: Array[int] } (preseleccionada).
static func resolve(allies: Array, quota: int, last: Array, ambush: bool = false) -> Dictionary:
	var keys: Array[String] = ally_keys(allies)
	return { "prompt": needs_prompt(allies.size(), quota, ambush), "chosen": preselect(keys, last, quota) }


## Marca o desmarca el aliado `index`; no deja pasar de las plazas. Devuelve la elección nueva.
static func toggle(chosen: Array[int], index: int, quota: int) -> Array[int]:
	var out: Array[int] = chosen.duplicate()
	if out.has(index):
		out.erase(index)
	elif out.size() < ally_slots(quota):
		out.append(index)
		out.sort()
	return out


## Orden de los aliados para el combate: los elegidos primero (entran) y luego los demás (esperan en
## el borde como refuerzo), cada grupo en su orden.
static func battle_order(ally_count: int, chosen: Array[int]) -> Array[int]:
	var out: Array[int] = chosen.duplicate()
	out.sort()
	for i: int in ally_count:
		if not out.has(i):
			out.append(i)
	return out


## Última party guardada (claves).
static func last_choice() -> Array:
	return GameState.last_party


## Guarda la elección (claves de los elegidos) en GameState.
static func save_choice(allies: Array, chosen: Array[int]) -> void:
	var keys: Array[String] = ally_keys(allies)
	var out: Array[String] = []
	for i: int in chosen:
		if i >= 0 and i < keys.size():
			out.append(keys[i])
	GameState.last_party = out
