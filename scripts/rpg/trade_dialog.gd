class_name TradeDialog
extends RefCounted
## Diálogo del trueque (P5, ajustes-playtest-0.5.md 5b) sobre una DialogueBox: saludo del artesano
## con la Luz que llevas y la lista de lo que ofrece hoy con su precio (Trade.offer); al elegir un
## objeto, con qué pagar (Luz u ofrenda de la bolsa, Trade.pay_options); al pagar, Trade.buy y el
## aviso. Sin fondos, con la bolsa llena o con el límite del día, un texto claro. Las reglas están
## en Trade; aquí solo se arman las preguntas. La exploración lo crea una vez y lo abre con E.

var _dialogue: DialogueBox
var _npc: StringName = &""
var _villa: String = ""


func _init(dialogue: DialogueBox) -> void:
	_dialogue = dialogue


## Abre el trueque con el NPC `npc_id` de la villa del chunk `villa_coord`.
func open(npc_id: StringName, villa_coord: Vector2i) -> void:
	_npc = npc_id
	_villa = Trade.villa_key(villa_coord)
	if Trade.limit_reached(_npc, _villa):
		_say(Texts.get_text("trade_limit"))
		return
	var offer: Array[Dictionary] = Trade.offer(_npc, _villa)
	if offer.is_empty():
		_say(Texts.get_text("trade_nothing"))
		return
	_dialogue.choice.connect(_on_item.bind(offer), CONNECT_ONE_SHOT)
	_dialogue.ask(_line(prompt_text(_npc)), item_options(offer))


## Texto de la primera pregunta: el saludo del NPC y la Luz que llevas.
static func prompt_text(npc_id: StringName) -> String:
	var greeting: String = ""
	var lines: Array = NpcDialogue.data(npc_id).get("greeting", {}).get("lines", [])
	if not lines.is_empty():
		greeting = str(lines[0].get("text", "")) + "\n"
	return greeting + Texts.get_text("trade_luz_line") % GameState.luz


## Opciones de la lista: "<objeto> (<precio>)" por cada uno y "Nada" al final (cancelar).
static func item_options(offer: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in offer:
		out.append(Texts.get_text("trade_item_option") % [Items.display_name(e.id), int(e.price)])
	out.append(Texts.get_text("trade_leave"))
	return out


## Opciones de pago: "Luz (6)", "<ofrenda> (5) + 1 Luz"... y "Dejarlo" al final (cancelar).
static func pay_labels(options: Array[Dictionary], price: int) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in options:
		if p.kind == Trade.PAY_LUZ:
			out.append(Texts.get_text("trade_pay_luz") % price)
		elif int(p.luz) > 0:
			out.append(Texts.get_text("trade_pay_ofrenda_luz") % [Items.display_name(p.id), int(p.value), int(p.luz)])
		else:
			out.append(Texts.get_text("trade_pay_ofrenda") % [Items.display_name(p.id), int(p.value)])
	out.append(Texts.get_text("trade_cancel"))
	return out


## Texto del resultado de Trade.buy (OK: "Recibes: <objeto>.").
static func result_text(result: StringName, item_id: StringName, price: int) -> String:
	match result:
		Trade.OK:
			return Texts.get_text("trade_done") % Items.display_name(item_id)
		Trade.LIMIT:
			return Texts.get_text("trade_limit")
		Trade.BAG_FULL:
			return Texts.get_text("trade_bag_full")
		Trade.NO_FUNDS:
			return Texts.get_text("trade_no_funds") % [Items.display_name(item_id), price, GameState.luz]
	return Texts.get_text("trade_nothing")


func _on_item(index: int, offer: Array[Dictionary]) -> void:
	if index < 0 or index >= offer.size():
		return
	var item: StringName = offer[index].id
	var price: int = int(offer[index].price)
	var pays: Array[Dictionary] = Trade.pay_options(price)
	if pays.is_empty():
		_say(result_text(Trade.NO_FUNDS, item, price))
		return
	_dialogue.choice.connect(_on_pay.bind(item, price, pays), CONNECT_ONE_SHOT)
	_dialogue.ask(_line(Texts.get_text("trade_pay_prompt") % [Items.display_name(item), price]), pay_labels(pays, price))


func _on_pay(index: int, item: StringName, price: int, pays: Array[Dictionary]) -> void:
	if index < 0 or index >= pays.size():
		return
	var result: StringName = Trade.buy(_npc, _villa, item, pays[index])
	_say(result_text(result, item, price))


func _line(text: String) -> Dictionary:
	return { "speaker": NpcDialogue.display_name(_npc), "text": text }


func _say(text: String) -> void:
	_dialogue.show_lines([_line(text)])
