class_name Stealth
extends RefCounted
## Sigilo del Adoc (sigilo-y-robo.md, propuestas provisionales de #131 y #132). Palabras del dueño:
## "hay articulos que te permiten "sneak" en los bosques. Estos articulos son mascaras de diferentes
## formas, algunos talismanes"; "sneak puede darse usando una mascara solamente o algun otro
## artefacto que camufle la Luz del jugador". Lógica pura sobre GameState.equipped y el catálogo:
## - Camuflaje: la máscara y el talismán equipados suman su `camouflage` (casillas que se restan al
##   vision_radius de los Únicos), con el tope camouflage_max. Llevar un arma en la mano principal
##   lo anula (la Luz del arma te delata) y, cuando un Único te ve de cerca, se rompe durante
##   exposed_seconds (GameState.stealth_exposed).
## - Colarse: con camuflaje, sin arma y si los Botarramas del Bosque vecino se quedan con visión
##   sneak_max_vision o menos, se cruza su frontera cerrada sin pagar. El Bosque queda "colado"
##   (GameState.sneaked_bosques) mientras sigas dentro: no está pagado ni forzado, no te caza
##   mientras no te vean y no da permiso para el fruto.
## - Velocidad: los talismanes de viaje suman `speed_bonus` (fracción, con el tope speed_bonus_max):
##   el paso dura STEP_TIME / (1 + bonus).
## - Desventajas: `def_penalty` resta DEF mientras se lleva; `max_uses` = cruces colados hasta que se
##   rompe (GameState.item_uses).
## - Bosque enojado: con camuflaje alto (visión de un Botarramas base ≤ hidden_vision) o velocidad,
##   sus cazadores tardan stealth_hunt_factor veces más (BosqueStates.stealth_hunt_factor).
## No emite señales ni abre diálogos: lo hace AdventureRules (sneak_into) y la exploración. Números
## en data/combat/balance.json (bloque stealth) y en data/items/items.json.

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


## Camuflaje que actúa ahora: el del equipo, salvo con un arma en la mano o con el camuflaje roto
## (te han visto hace poco). 0 = sin camuflaje.
static func camouflage() -> int:
	if AdventureRules.is_armed() or is_exposed():
		return 0
	return gear_camouflage()


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


## Visión que deja colarse: la de los Botarramas del Bosque, ya con el camuflaje, debe ser esta o menos.
static func sneak_max_vision() -> int:
	return int(config().get("sneak_max_vision", 1))


## Visión con que se cuenta como camuflaje alto (Bosque enojado).
static func hidden_vision() -> int:
	return int(config().get("hidden_vision", 2))


## Se puede colar en el Bosque `bosque_id` ahora: va oculto (con camuflaje, sin arma, sin que le
## hayan visto) y la visión de sus Botarramas queda en sneak_max_vision o menos.
static func can_sneak_into(bosque_id: int) -> bool:
	if bosque_id < 0 or not is_hidden():
		return false
	var base: int = int(AdventureRules.monster_config(&"botarramas").get("vision_radius", 0))
	return AdventureRules.vision_radius(bosque_id, base) <= sneak_max_vision()


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
