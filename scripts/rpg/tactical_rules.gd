class_name TacticalRules
extends RefCounted
## Reglas puras de las acciones del combate táctico (combate-tactico.md, ADR 0016; PR T3): por dónde
## llega un golpe (frente, flanco, espalda), evasión, precisión, bonos de daño por posición y alcance
## cuerpo a cuerpo con desnivel. Solo funciones estáticas sin estado: TacticalBattle las usa para
## ejecutar las acciones y la escena (T4) y la IA (T5) para mostrar o decidir.
## Números en data/combat/balance.json, bloque tactical.actions (`cfg` aquí):
## - Evasión de frente = evasion_base + evasion_per_agi × AGI; de flanco × flank_factor (redondeo hacia
##   abajo: 15 → 7); de espalda × back_factor (0). Después, −height_evasion por cada nivel que el
##   atacante esté por encima y +height_evasion por cada nivel por debajo; nunca negativa.
## - Precisión = 100 − evasión, entre hit_min y hit_max.
## - Bono de daño: flank_bonus de flanco, back_bonus de espalda y height_bonus por nivel a favor.
## - Cuerpo a cuerpo: casilla vecina ortogonal y desnivel (en valor absoluto) ≤ Salto del atacante.

## Por dónde llega el golpe respecto a la orientación del defensor.
enum Relation { FRONT, FLANK, BACK }


## Por dónde llega un golpe desde `attacker_cell` a un defensor en `defender_cell` que mira hacia
## `defender_facing`. Si no son vecinas, se usa la dirección dominante (TacticalBoard.facing_toward).
static func relation(defender_cell: Vector2i, defender_facing: int, attacker_cell: Vector2i) -> Relation:
	var toward: int = TacticalBoard.facing_toward(defender_cell, attacker_cell, defender_facing as TacticalBoard.Facing)
	if toward == defender_facing:
		return Relation.FRONT
	if toward == (defender_facing + 2) % 4:
		return Relation.BACK
	return Relation.FLANK


## Evasión (%) del defensor según su AGI, por dónde le atacan y el desnivel (`height_diff` = nivel del
## atacante − nivel del defensor).
static func evasion(agi: int, rel: Relation, height_diff: int, cfg: Dictionary) -> int:
	var front: int = int(cfg.get("evasion_base", 5)) + int(cfg.get("evasion_per_agi", 2)) * agi
	var base: int = front
	match rel:
		Relation.FLANK:
			base = floori(front * float(cfg.get("flank_factor", 0.5)))
		Relation.BACK:
			base = floori(front * float(cfg.get("back_factor", 0.0)))
	return maxi(0, base - int(cfg.get("height_evasion", 10)) * height_diff)


## Probabilidad de acertar (%) contra una evasión.
static func hit_chance(evasion_pct: int, cfg: Dictionary) -> int:
	return clampi(100 - evasion_pct, int(cfg.get("hit_min", 5)), int(cfg.get("hit_max", 100)))


## Daño extra por posición: flanco, espalda y niveles a favor (los niveles en contra no restan).
static func position_bonus(rel: Relation, height_diff: int, cfg: Dictionary) -> int:
	var bonus: int = 0
	match rel:
		Relation.FLANK:
			bonus += int(cfg.get("flank_bonus", 1))
		Relation.BACK:
			bonus += int(cfg.get("back_bonus", 2))
	return bonus + int(cfg.get("height_bonus", 1)) * maxi(height_diff, 0)


## Se llega cuerpo a cuerpo de `from` a `to`: vecinas ortogonales y desnivel ≤ `jump`. Las escaleras
## no cuentan: el golpe se da por encima del borde.
static func can_melee(board: TacticalBoard, from: Vector2i, to: Vector2i, jump: int) -> bool:
	if not TacticalBoard.are_adjacent(from, to) or not board.in_bounds(from) or not board.in_bounds(to):
		return false
	return absi(board.level_at(from) - board.level_at(to)) <= jump


## Distancia en casillas (Manhattan), para el alcance del apoyo (Vendar, Animar).
static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
