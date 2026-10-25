class_name SleepRules
extends RefCounted
## Dormir (bosques-y-relacion.md, "Dormir y Pensamiento"; dueño: "en villas y refugios y si pasa el
## tiempo, solo se debe dormir de noche, dormir de dia consume Luz. Gietos detesta el descanso.").
## Lógica pura:
## - Se duerme donde se pasa el riutash a cubierto (AdventureRules.is_riutash_shelter): un refugio,
##   la plaza de una villa o junto al Nujio de una villa.
## - De noche (Riumna): se salta hasta el riutash del amanecer, gratis. Puede haber visión de
##   Pensamiento (FarQuests.vision_for).
## - De día (Gietos): se salta hasta el riutash del atardecer y cuesta Luz suelta (day_cost). Sin
##   Luz suficiente no se puede. Sin visiones.
## - El salto (sleep) avanza primero el mundo (`advance_world`, p. ej. el Ofomni descarriado) y
##   después WorldClock, que pasa el riutash refugiado (quien lo escucha, la exploración, cura y hace
##   caducar los pagos). En una villa, además, los PV quedan al máximo.
## No dibuja: la exploración pone el fundido y la pantalla de Pensamiento. Números en
## data/combat/balance.json (bloque sleep).

## Segundos de más al saltar, para que el riutash pase seguro.
const WAKE_EPSILON: float = 0.001


static func config() -> Dictionary:
	return AdventureRules.balance().get("sleep", {})


## Se puede dormir en la casilla: refugio, plaza de villa o junto al Nujio de una villa.
static func can_sleep_at(chunk: ChunkData, cell: Vector2i) -> bool:
	return AdventureRules.is_riutash_shelter(chunk, cell)


## Es de noche: el sueño lleva a Pensamiento y no cuesta Luz.
static func is_night() -> bool:
	return GameState.clock_momento == TimeConfig.RIUMNA


## Segundos de reloj que se saltan: hasta el próximo riutash (el del amanecer de noche, el del
## atardecer de día).
static func seconds_to_wake() -> float:
	return maxf(0.0, TimeConfig.duration(GameState.clock_momento) - GameState.clock_elapsed)


## Luz que cuesta dormir de día `seconds` segundos: 1 por cada day_seconds_per_luz (redondeo hacia
## arriba), como mucho day_luz_max.
static func day_cost(seconds: float) -> int:
	var per: float = maxf(1.0, float(config().get("day_seconds_per_luz", 120)))
	return mini(int(config().get("day_luz_max", 4)), ceili(maxf(0.0, seconds) / per))


## Luz que cuesta dormir ahora (0 de noche).
static func cost_now() -> int:
	return 0 if is_night() else day_cost(seconds_to_wake())


static func can_afford() -> bool:
	return GameState.luz >= cost_now()


## Duerme: paga la Luz (de día), avanza el mundo `advance_world` (Callable(seconds)) y el reloj
## hasta el riutash, y en una villa (`in_villa`) deja los PV al máximo. Devuelve { "night",
## "seconds", "cost", "day" } (day: el día en que se durmió) o {} si no alcanza la Luz.
static func sleep(in_villa: bool, advance_world: Callable = Callable()) -> Dictionary:
	if not can_afford():
		return {}
	var night: bool = is_night()
	var seconds: float = seconds_to_wake()
	var cost: int = cost_now()
	var day: int = GameState.day
	if cost > 0:
		AdventureRules.set_luz(GameState.luz - cost)
	if advance_world.is_valid():
		advance_world.call(seconds)
	# Un pelo más: la suma en coma flotante podría quedarse a nada del riutash.
	WorldClock.advance(seconds + WAKE_EPSILON)
	if in_villa:
		AdventureRules.rest()
	return { "night": night, "seconds": seconds, "cost": cost, "day": day }
