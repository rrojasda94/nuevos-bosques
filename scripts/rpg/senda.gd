class_name Senda
extends RefCounted
## Senda del Adoc y estado de bando (moralidad-y-progresion.md; dos-caminos.md, sección 1).
## - La Senda va de min a max (−100 … +100) y empieza en 0. Mide el trato con los Bosques y sus
##   Únicos. La mueven los actos de balance.json (bloque senda.acts), que se enganchan donde ya
##   ocurren (AdventureRules, FruitRules, AdocEncounters, FarQuests): vencer a un Botarramas o a un
##   Único, robar, sacar un fruto, pagar, dejar ofrendas, ayudar a otro adoc, salvar un Bosque...
## - Se ve como un icono de tres estados (violenta, neutral, respetuosa), nunca como número.
## - Bando: fiel, en_duda o garelino. De fiel pasa solo a en_duda con la Senda en doubt_at o menos y
##   vuelve a fiel con faithful_at o más (histéresis). Garelino solo se alcanza con el encuentro de
##   historia (otro PR, set_bando) y la Senda ya no lo cambia.
## Escribe en GameState y avisa por EventBus (senda_changed, bando_changed). No conoce la UI.

enum Icon { VIOLENT, NEUTRAL, RESPECTFUL }

const FIEL: StringName = &"fiel"
const EN_DUDA: StringName = &"en_duda"
const GARELINO: StringName = &"garelino"
const BANDOS: Array[StringName] = [FIEL, EN_DUDA, GARELINO]

## Actos (claves de senda.acts).
const GUARDIAN_DEFEATED: StringName = &"guardian_defeated"
const UNICO_DEFEATED: StringName = &"unico_defeated"
const OFFEND: StringName = &"offend"
const THEFT: StringName = &"theft"
const FRUIT_TAKEN_OUT: StringName = &"fruit_taken_out"
const PAY_LUZ: StringName = &"pay_luz"
const PAY_OFRENDA: StringName = &"pay_ofrenda"
const OFRENDA_LEFT: StringName = &"ofrenda_left"
const ADOC_HELPED: StringName = &"adoc_helped"
const BOSQUE_SAVED: StringName = &"bosque_saved"
const FAR_QUEST_DONE: StringName = &"far_quest_done"


static func config() -> Dictionary:
	return AdventureRules.balance().get("senda", {})


static func min_value() -> int:
	return int(config().get("min", -100))


static func max_value() -> int:
	return int(config().get("max", 100))


## Lo que mueve la Senda un acto (0 si no está en los datos).
static func act_delta(act: StringName) -> int:
	return int((config().get("acts", {}) as Dictionary).get(String(act), 0))


## Suma `delta` a la Senda, con los topes, y actualiza el bando. Si el icono cambia, lo avisa en el
## HUD ("Tu Senda se vuelve violenta."). Devuelve lo que cambió de verdad.
static func change(delta: int) -> int:
	var before: int = GameState.senda
	GameState.senda = clampi(before + delta, min_value(), max_value())
	var moved: int = GameState.senda - before
	if moved != 0:
		EventBus.senda_changed.emit(GameState.senda, moved)
		var now: Icon = icon_for(GameState.senda)
		if now != icon_for(before):
			EventBus.notice_requested.emit(Texts.get_text(["senda_now_violent", "senda_now_neutral", "senda_now_respectful"][now]))
	update_bando()
	return moved


## Aplica un acto `times` veces (p. ej. un fruto por cada uno sacado). Devuelve lo que cambió.
static func record(act: StringName, times: int = 1) -> int:
	return change(act_delta(act) * maxi(0, times))


## Icono de una Senda: violenta (≤ violent_at), respetuosa (≥ respectful_at) o neutral.
static func icon_for(value: int) -> Icon:
	if value <= int(config().get("violent_at", -30)):
		return Icon.VIOLENT
	if value >= int(config().get("respectful_at", 30)):
		return Icon.RESPECTFUL
	return Icon.NEUTRAL


static func icon() -> Icon:
	return icon_for(GameState.senda)


## Nombre del icono para la UI ("violenta", "neutral", "respetuosa").
static func icon_name(value: Icon) -> String:
	return Texts.get_text(["senda_violent", "senda_neutral", "senda_respectful"][value])


# --- Bando (dos-caminos.md) ----------------------------------------------------------------------

static func _bando_cfg() -> Dictionary:
	return config().get("bando", {})


static func doubt_at() -> int:
	return int(_bando_cfg().get("doubt_at", -40))


static func faithful_at() -> int:
	return int(_bando_cfg().get("faithful_at", -20))


## Bando que corresponde a la Senda `value` desde `current` (pura): fiel -> en_duda con doubt_at o
## menos; en_duda -> fiel con faithful_at o más; garelino no cambia por la Senda.
static func bando_for(current: StringName, value: int) -> StringName:
	if current == FIEL and value <= doubt_at():
		return EN_DUDA
	if current == EN_DUDA and value >= faithful_at():
		return FIEL
	return current


## Recalcula el bando con la Senda actual. Devuelve si cambió.
static func update_bando() -> bool:
	return set_bando(bando_for(GameState.bando, GameState.senda))


## Fija el bando (el encuentro de historia lo usará para pasar a garelino). false si no es un bando
## válido o ya era ese.
static func set_bando(bando: StringName) -> bool:
	if not BANDOS.has(bando) or GameState.bando == bando:
		return false
	GameState.bando = bando
	EventBus.bando_changed.emit(bando)
	EventBus.notice_requested.emit(Texts.get_text("bando_now_%s" % bando))
	return true


static func bando_name(bando: StringName) -> String:
	return Texts.get_text("bando_%s" % bando)
