class_name BosqueHunt
extends RefCounted
## El Bosque envía Únicos tras el Adoc mientras está dentro sin haber pagado (feedback del dueño
## 0.3: "el bosque no recuerda que no pague mi tributo. no me vuelve a mandar mas únicos a
## atacarme una vez vencido el primero").
## - Dentro de un Bosque sin pagar (forzado, o cerrado), cada interval() segundos de reloj aparece
##   un cazador cerca, fuera de la vista inmediata, que persigue al Adoc: un Botarramas o un Ofomni
##   del Bosque, alternando desde uno elegido por seed.
## - interval = base_seconds − per_hostility_seconds × hostilidad, como mínimo min_seconds.
## - Como mucho max_hunters a la vez. Dejan de salir al pagar (apaciguar a uno paga el Bosque) o al
##   salir del Bosque; cambiar de chunk dentro del Bosque se los lleva detrás.
## Una instancia lleva la cacería en curso; no se guarda (al cargar no hay cazadores y el reloj de
## la cacería empieza de cero). Números en data/combat/balance.json (bloque bosque_hunt).

const SALT_KIND: int = 59

## Bosque de la cacería (-1: ninguna).
var bosque_id: int = -1
## Segundos desde el último cazador (o desde que empezó).
var elapsed: float = 0.0
## Cazadores enviados en esta estancia (para alternar el tipo y avisar del primero).
var sent: int = 0
## Tipo (id de datos) de cada cazador que sigue vivo.
var active: Array[StringName] = []


static func config() -> Dictionary:
	return AdventureRules.balance().get("bosque_hunt", {})


## Segundos entre cazadores con esa hostilidad.
static func interval(hostility: int) -> float:
	var cfg: Dictionary = config()
	return maxf(float(cfg.get("min_seconds", 30)),
		float(cfg.get("base_seconds", 90)) - float(cfg.get("per_hostility_seconds", 15)) * hostility)


static func max_hunters() -> int:
	return int(config().get("max_hunters", 2))


## El Bosque caza al Adoc: está dentro (`bosque`) y no lo ha pagado (el natal nunca caza).
static func is_hunting(bosque: int, home: int) -> bool:
	return bosque >= 0 and not AdventureRules.is_paid(bosque, home)


## Tipo del cazador número `n` (0, 1...) del Bosque: alterna los de `kinds` desde uno por seed.
static func hunter_kind(seed_value: int, bosque: int, n: int) -> StringName:
	var kinds: Array = config().get("kinds", ["botarramas", "ofomni"])
	return StringName(str(kinds[(ChunkGenerator.hash_ints([seed_value, bosque, SALT_KIND]) + n) % kinds.size()]))


func clear() -> void:
	bosque_id = -1
	elapsed = 0.0
	sent = 0
	active.clear()


## Pasa `delta` segundos con el Adoc en el Bosque `bosque`. Devuelve el tipo del cazador que el
## Bosque envía ahora, o &"" si ninguno. Si el Bosque ya no caza (pagado, o es otro), la cacería
## se acaba.
func tick(delta: float, bosque: int, home: int, seed_value: int) -> StringName:
	if not is_hunting(bosque, home):
		if bosque_id >= 0:
			clear()
		return &""
	if bosque != bosque_id:
		clear()
		bosque_id = bosque
	elapsed += delta
	if elapsed < interval(AdventureRules.hostility(bosque)):
		return &""
	elapsed = 0.0
	if active.size() >= max_hunters():
		return &""
	var kind: StringName = hunter_kind(seed_value, bosque, sent)
	sent += 1
	active.append(kind)
	return kind


## Un cazador vencido: deja hueco para el siguiente.
func hunter_defeated(kind: StringName) -> void:
	active.erase(kind)


## Es el primer cazador de esta estancia (para el aviso).
func is_first() -> bool:
	return sent == 1
