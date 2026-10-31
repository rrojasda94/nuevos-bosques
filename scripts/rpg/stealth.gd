class_name Stealth
extends RefCounted
## Sigilo del Adoc (sigilo-y-robo.md, propuestas provisionales de #131 y #132; colarse y arma
## enfundada según ajustes-playtest-0.5.md, puntos 1b, 3 y 4a, ADR 0017). Palabras del dueño:
## "hay articulos que te permiten "sneak" en los bosques. Estos articulos son mascaras de diferentes
## formas, algunos talismanes"; "debería poderse entrar como sneaking pero los botarramas u otros
## unicos si te ven te pillan. Si estas muy bien equipado no deberían notarte a menos que pases por
## su lado". Lógica pura sobre GameState.equipped, GameState.weapon_drawn y el catálogo:
## - Camuflaje: la máscara y el talismán equipados suman su `camouflage` (casillas que se restan al
##   vision_radius de los Únicos), con el tope camouflage_max, menos el sheathed_camo_penalty del
##   arma enfundada. Con el arma en la mano (AdventureRules.is_armed), corriendo (`running`, si
##   run_breaks_camouflage) o con el camuflaje roto (te han visto: GameState.stealth_exposed durante
##   exposed_seconds) no cuenta.
## - Detección (detects): un vigía te ve siempre a close_detect casillas o menos (Chebyshev); más
##   lejos, si estás dentro de su visión menos tu camuflaje; sin nada que oculte (camuflaje 0), a su
##   visión × unmasked_vision_factor.
## - Colarse (border_outcome): al tocar la frontera cerrada de un Bosque, si ningún vigía (sus
##   Botarramas y sus Únicos del mundo cargado) te ve, se cruza sin menú y el Bosque queda "colado"
##   (GameState.sneaked_bosques) mientras sigas dentro: no está pagado ni forzado, no te caza
##   mientras no te vean y no da permiso para el fruto. Si te ve un Botarramas, o llevas el arma en
##   la mano, o ya te persiguen, sale el menú del borde; si te ve otro Único, te persigue.
## - Velocidad: los talismanes de viaje suman `speed_bonus` (fracción, con el tope speed_bonus_max):
##   el paso dura STEP_TIME / (1 + bonus).
## - Desventajas: `def_penalty` resta DEF mientras se lleva; `max_uses` = cruces colados hasta que se
##   rompe (GameState.item_uses).
## - Bosque enojado: con camuflaje alto (visión de un Botarramas base ≤ hidden_vision) o velocidad,
##   sus cazadores tardan stealth_hunt_factor veces más (BosqueStates.stealth_hunt_factor).
## No emite señales ni abre diálogos: lo hacen AdventureRules (sneak_into), BosqueBorder y la
## exploración. Números en data/combat/balance.json (bloque stealth) y en data/items/items.json.

## Resultado de tocar una frontera cerrada (border_outcome).
const CROSS_SNEAK: StringName = &"sneak"
const CROSS_MENU: StringName = &"menu"
const CROSS_SEEN: StringName = &"seen"

## El Adoc corre ahora (Shift con movimiento). Lo fija la exploración (set_running); no se guarda.
static var running: bool = false

const SLOTS: Array[StringName] = [InventoryLogic.SLOT_MASK, InventoryLogic.SLOT_TALISMAN]


static func config() -> Dictionary:
	return AdventureRules.balance().get("stealth", {})


## Objetos de sigilo equipados (máscara y talismán), sin las ranuras vacías.
static func worn(equipped: Dictionary = GameState.equipped) -> Array[StringName]:
	var out: Array[StringName] = []
	for slot: StringName in SLOTS:
		var id: StringName = InventoryLogic.equipped_in(equipped, slot)
		if id != &"":
			out.append(id)
	return out


## Camuflaje de lo equipado, sumado y con tope, sin contar el arma ni la exposición.
static func gear_camouflage(equipped: Dictionary = GameState.equipped) -> int:
	var total: int = 0
	for id: StringName in worn(equipped):
		total += Items.camouflage(id)
	return clampi(total, 0, int(config().get("camouflage_max", 0)))


## Camuflaje que resta el arma equipada y enfundada (0 sin arma o con ella en la mano).
static func sheathed_penalty() -> int:
	if not AdventureRules.has_weapon() or AdventureRules.is_armed():
		return 0
	return Items.sheathed_camo_penalty(AdventureRules.weapon())


## Correr anula el camuflaje (run_breaks_camouflage).
static func run_breaks_camouflage() -> bool:
	return bool(config().get("run_breaks_camouflage", true))


## Camuflaje que actúa ahora: el del equipo menos el del arma enfundada (sin bajar de 0), salvo con
## el arma en la mano, corriendo o con el camuflaje roto (te han visto hace poco). 0 = sin camuflaje.
static func camouflage() -> int:
	if AdventureRules.is_armed() or is_exposed() or (running and run_breaks_camouflage()):
		return 0
	return maxi(0, gear_camouflage() - sheathed_penalty())


## Fija si el Adoc corre. Devuelve true si ha cambiado (para recalcular la visión de los Únicos).
static func set_running(value: bool) -> bool:
	if running == value:
		return false
	running = value
	return true


## El Adoc va oculto: lleva camuflaje y funciona.
static func is_hidden() -> bool:
	return camouflage() > 0


## Visión de un Único con `vision` casillas frente al camuflaje `camo` (0 = no ve más que encima).
static func vision_against(vision: int, camo: int) -> int:
	return maxi(0, vision - camo)


## El camuflaje está roto (te han visto) durante los segundos que quedan.
static func is_exposed() -> bool:
	return GameState.stealth_exposed > 0.0


## Te han visto: el camuflaje se rompe exposed_seconds.
static func expose() -> void:
	GameState.stealth_exposed = float(config().get("exposed_seconds", 20.0))


## Pasa el tiempo. Devuelve true si el camuflaje acaba de volver.
static func tick(delta: float) -> bool:
	if GameState.stealth_exposed <= 0.0:
		return false
	GameState.stealth_exposed = maxf(0.0, GameState.stealth_exposed - delta)
	return GameState.stealth_exposed <= 0.0


## Segundos que el Único que te ve de cerca tarda en echarse encima (para poder escapar).
static func seen_grace() -> float:
	return float(config().get("seen_grace_seconds", 0.8))


## Visión con que se cuenta como camuflaje alto (Bosque enojado).
static func hidden_vision() -> int:
	return int(config().get("hidden_vision", 2))


# --- Detección y colarse (ajustes-playtest-0.5.md, punto 3) ---------------------------------------

## Casillas a las que un vigía te ve siempre ("pasar a su lado").
static func close_detect() -> int:
	return int(config().get("close_detect", 2))


static func unmasked_vision_factor() -> float:
	return float(config().get("unmasked_vision_factor", 2.0))


## Visión real de un vigía con `vision` casillas frente al camuflaje `camo`: menos el camuflaje si lo
## hay; sin nada que oculte (camo 0: sin máscara, corriendo o con el arma en la mano),
## × unmasked_vision_factor.
static func effective_vision(vision: int, camo: int) -> int:
	if camo > 0:
		return vision_against(vision, camo)
	return roundi(maxi(0, vision) * unmasked_vision_factor())


## Un vigía con `vision` casillas a `dist` casillas (Chebyshev) te ve con el camuflaje `camo`.
static func detects(dist: int, vision: int, camo: int) -> bool:
	return dist <= close_detect() or dist <= effective_vision(vision, camo)


## El vigía { cell, vision } ve la casilla `player_cell` con el camuflaje `camo`.
static func watcher_detects(watcher: Dictionary, player_cell: Vector2i, camo: int) -> bool:
	return detects(MonsterSteering.chebyshev(watcher.cell, player_cell), int(watcher.vision), camo)


## Índice del vigía que te ve (los Botarramas, `guardian` = true, primero), o -1 si nadie.
## `watchers`: [{ cell: Vector2i, vision: int, guardian: bool }].
static func first_detector(watchers: Array, player_cell: Vector2i, camo: int) -> int:
	var other: int = -1
	for i: int in watchers.size():
		if not watcher_detects(watchers[i], player_cell, camo):
			continue
		if bool(watchers[i].get("guardian", false)):
			return i
		if other < 0:
			other = i
	return other


## Ningún vigía te ve: la frontera cerrada se cruza sin menú.
static func can_cross_unseen(watchers: Array, player_cell: Vector2i, camo: int) -> bool:
	return first_detector(watchers, player_cell, camo) < 0


## Qué pasa al tocar la frontera cerrada del Bosque que vigilan `watchers` (ver first_detector), con
## el camuflaje `camo`, el arma en la mano (`weapon_drawn`) y alguien persiguiéndote (`chased`):
## { kind, index }. kind: CROSS_MENU (el menú del borde: arma en la mano, te ve un Botarramas o ya
## te persiguen), CROSS_SEEN (te ve otro Único y te persigue; `index` dice cuál) o CROSS_SNEAK
## (nadie te ve: te cuelas). Si te ven al tocar el borde, gana el menú (casos límite de la ficha).
static func border_outcome(watchers: Array, player_cell: Vector2i, camo: int, weapon_drawn: bool,
		chased: bool) -> Dictionary:
	if weapon_drawn:
		return { "kind": CROSS_MENU, "index": -1 }
	var i: int = first_detector(watchers, player_cell, camo)
	if i >= 0:
		return { "kind": CROSS_MENU if bool(watchers[i].get("guardian", false)) else CROSS_SEEN, "index": i }
	return { "kind": CROSS_MENU if chased else CROSS_SNEAK, "index": -1 }


## Camuflaje alto: un Botarramas sin extras (vision_radius base) se queda con hidden_vision o menos.
static func hides_well() -> bool:
	var base: int = int(AdventureRules.monster_config(&"botarramas").get("vision_radius", 0))
	return is_hidden() and vision_against(base, camouflage()) <= hidden_vision()


# --- Velocidad y desventajas ------------------------------------------------------------------------

## Velocidad extra de lo equipado (fracción: 0.3 = un 30% más rápido), con tope.
static func speed_bonus(equipped: Dictionary = GameState.equipped) -> float:
	var total: float = 0.0
	for id: StringName in worn(equipped):
		total += Items.speed_bonus(id)
	return clampf(total, 0.0, float(config().get("speed_bonus_max", 0.0)))


## Segundos por casilla con el bonus de velocidad (base: PlayerWalker.STEP_TIME).
static func step_time(base: float, equipped: Dictionary = GameState.equipped) -> float:
	return base / (1.0 + speed_bonus(equipped))


## DEF que resta lo equipado (máscaras pesadas).
static func def_penalty(equipped: Dictionary = GameState.equipped) -> int:
	var total: int = 0
	for id: StringName in worn(equipped):
		total += Items.def_penalty(id)
	return total


## Usos que le quedan a un objeto que se rompe (-1 si no se rompe).
static func uses_left(id: StringName) -> int:
	var max_uses: int = Items.max_uses(id)
	if max_uses <= 0:
		return -1
	return maxi(0, max_uses - int(GameState.item_uses.get(String(id), 0)))


## Un cruce colado gasta un uso de cada objeto equipado que se rompe. Los que se agotan se quitan
## del equipo (se pierden). Devuelve sus ids.
static func spend_uses() -> Array[StringName]:
	var broken: Array[StringName] = []
	for slot: StringName in SLOTS:
		var id: StringName = InventoryLogic.equipped_in(GameState.equipped, slot)
		if id == &"" or Items.max_uses(id) <= 0:
			continue
		var used: int = int(GameState.item_uses.get(String(id), 0)) + 1
		if used >= Items.max_uses(id):
			GameState.item_uses.erase(String(id))
			GameState.equipped[String(slot)] = ""
			broken.append(id)
		else:
			GameState.item_uses[String(id)] = used
	return broken


# --- Pantalla I -------------------------------------------------------------------------------------

## Efectos del objeto en una línea, para su descripción ("ATQ +2. ", "Camuflaje 6. DEF −2. "...).
static func effects_text(id: StringName) -> String:
	var parts: PackedStringArray = []
	if Items.atk_bonus(id) > 0:
		parts.append(Texts.get_text("item_effect_atk") % Items.atk_bonus(id))
	if Items.camouflage(id) > 0:
		parts.append(Texts.get_text("item_effect_camouflage") % Items.camouflage(id))
	if Items.speed_bonus(id) > 0.0:
		parts.append(Texts.get_text("item_effect_speed") % roundi(Items.speed_bonus(id) * 100.0))
	if Items.def_penalty(id) > 0:
		parts.append(Texts.get_text("item_effect_def_penalty") % Items.def_penalty(id))
	if Items.max_uses(id) > 0:
		parts.append(Texts.get_text("item_effect_uses") % uses_left(id))
	return "" if parts.is_empty() else " ".join(parts) + " "
