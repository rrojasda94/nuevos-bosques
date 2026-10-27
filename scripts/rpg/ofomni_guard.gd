class_name OfomniGuard
extends RefCounted
## Ofomni que guardan su Bosque (sigilo-y-robo.md; feedback del dueño 0.3). Dos reglas, en lógica
## pura (sin nodos; MonsterField los dibuja y la exploración decide cuándo):
## - Persecución por robo: "tomar o comer mas de un fruto puede alertar a los ofomni a que te
##   sigan". Con un robo a la vista (sin camuflaje, siempre; camuflado, solo si un Único lo ve:
##   is_alerted) despiertan entre chase_count_min y chase_count_max `ofomni` (los apaciguables) del Bosque
##   robado, cerca y fuera de la vista inmediata, y persiguen al Adoc dentro de ese Bosque. Si sale
##   del Bosque, se rinden. Una instancia lleva la persecución en curso: no se guarda (al cargar
##   una partida no hay perseguidores).
## - Confinamiento de la primera misión: "en tu primera misión no puedes salir de tu bosque si no
##   haz activado la mision los ofomni de tu bosque te capturan y te llevan hasta tu villa central
##   nuevamente". Con la misión del sfida ofrecida y sin aceptar, acercarse a la frontera del
##   Bosque natal (confine_distance) hace que sus Ofomni devuelvan al Adoc a la plaza de la villa.
## Números en data/combat/balance.json (bloque ofomni_guard).

const SALT_CHASE: int = 37

## Bosque cuyos Ofomni persiguen ahora al Adoc (-1: nadie persigue).
var bosque_id: int = -1
## Ofomni que siguen persiguiendo.
var count: int = 0


static func config() -> Dictionary:
	return AdventureRules.balance().get("ofomni_guard", {})


# --- Persecución por robo ----------------------------------------------------------------------

func is_active() -> bool:
	return bosque_id >= 0 and count > 0


func clear() -> void:
	bosque_id = -1
	count = 0


## Un robo en `robbed` despierta a `n` Ofomni más. Si ya perseguían los de otro Bosque, la
## persecución pasa a la del nuevo; nunca hay más de chase_count_max a la vez. Devuelve cuántos
## Ofomni nuevos aparecen.
func alert(robbed: int, n: int) -> int:
	if robbed < 0 or n <= 0:
		return 0
	if robbed != bosque_id:
		clear()
		bosque_id = robbed
	var total: int = mini(int(config().get("chase_count_max", 2)), count + n)
	var added: int = total - count
	count = total
	return added


## El Adoc entra en un chunk del Bosque `entered`. Si la persecución era de otro Bosque, los
## Ofomni se rinden en la frontera. Devuelve true si se acaban de rendir.
func bosque_entered(entered: int) -> bool:
	if not is_active() or entered == bosque_id:
		return false
	clear()
	return true


## Un Ofomni perseguidor vencido: uno menos (al llegar a 0 la persecución acaba).
func chaser_defeated() -> void:
	count = maxi(0, count - 1)
	if count == 0:
		clear()


## El robo se ve y alerta a los Ofomni (sigilo-y-robo.md: "si robas algun objeto y estas sin
## proteccion o a la vista de otro Único"): sin camuflaje (`hidden` false), con probabilidad
## alert_chance (1.0 por ahora); camuflado, solo si un Único lo ve (`watched`). `roll`: número en
## [0, 1) para la probabilidad.
static func is_alerted(roll: float = 0.0, hidden: bool = false, watched: bool = false) -> bool:
	if hidden and not watched:
		return false
	return roll < float(config().get("alert_chance", 1.0))


## Cuántos Ofomni despiertan con un robo (chase_count_min..chase_count_max), determinista por
## seed, Bosque y número de robo (`nonce`).
static func chase_count(seed_value: int, robbed: int, nonce: int) -> int:
	var lo: int = int(config().get("chase_count_min", 1))
	var hi: int = maxi(lo, int(config().get("chase_count_max", 2)))
	return lo + ChunkGenerator.hash_ints([seed_value, robbed, nonce, SALT_CHASE]) % (hi - lo + 1)


## Casillas donde aparecen `n` perseguidores: cerca del jugador pero fuera de la vista inmediata
## (más allá de spawn_view en x o en y) y a spawn_max_distance o menos; se eligen las más cercanas,
## separadas entre sí. `can_use`: (Vector2i) -> bool, casilla válida (transitable, alcanzable y
## libre). Si no hay ninguna fuera de la vista, cualquier casilla válida a 4 o más. Determinista.
static func spawn_cells(player: Vector2i, n: int, can_use: Callable, area: Rect2i) -> Array[Vector2i]:
	var cfg: Dictionary = config()
	var view: Array = cfg.get("spawn_view", [10, 6])
	var max_d: int = int(cfg.get("spawn_max_distance", 14))
	var hidden: Array[Vector2i] = []
	var fallback: Array[Vector2i] = []
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			var d: int = MonsterSteering.chebyshev(c, player)
			if d < 4 or not can_use.call(c):
				continue
			var off: Vector2i = (c - player).abs()
			if d <= max_d and (off.x > int(view[0]) or off.y > int(view[1])):
				hidden.append(c)
			else:
				fallback.append(c)
	var pool: Array[Vector2i] = hidden if not hidden.is_empty() else fallback
	pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = MonsterSteering.chebyshev(a, player)
		var db: int = MonsterSteering.chebyshev(b, player)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	var out: Array[Vector2i] = []
	for c: Vector2i in pool:
		if out.size() >= n:
			break
		if out.all(func(o: Vector2i) -> bool: return MonsterSteering.chebyshev(o, c) >= 3):
			out.append(c)
	return out


# --- Confinamiento de la primera misión -----------------------------------------------------------

## La misión del sfida está ofrecida y sin aceptar: el Bosque natal no deja salir.
static func is_confined() -> bool:
	return QuestLogic.state_of(GameState.quests.get(QuestLogic.PRIMERA_MISION, {})) == QuestLogic.OFFERED

