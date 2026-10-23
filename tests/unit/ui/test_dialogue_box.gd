extends GutTest
## Caja de diálogo con máquina de escribir: la lógica (DialogueQueue) y el componente con eventos
## inyectados (DialogueBox).

const BOX_SCENE: PackedScene = preload("res://scenes/ui/dialogue_box.tscn")


func _press(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func test_normalize_accepts_text_or_dictionary() -> void:
	assert_eq(DialogueQueue.normalize("Hola"), { "speaker": "", "text": "Hola" })
	var d: Dictionary = DialogueQueue.normalize({ "speaker": "Sfida", "text": "Brille tu Luz", "luz": 3 })
	assert_eq(d.speaker, "Sfida")
	assert_eq(d.luz, 3, "conserva las claves extra (barras del combate)")
	assert_eq(DialogueQueue.normalize({ "text": "x" }).speaker, "")


func test_queue_types_completes_and_advances_in_order() -> void:
	var q := DialogueQueue.new()
	assert_true(q.start(["uno", "dos"]))
	assert_true(q.is_active)
	assert_true(q.is_typing)
	assert_eq(q.current.text, "uno")
	assert_eq(q.visible_chars, 0)
	assert_false(q.tick(0.05, 20.0, 3), "1 letra de 3")
	assert_eq(q.visible_chars, 1)
	assert_eq(q.press(), DialogueQueue.Press.COMPLETED, "pulsar escribiendo completa")
	assert_false(q.is_typing)
	assert_eq(q.visible_chars, -1)
	assert_eq(q.press(), DialogueQueue.Press.NEXT, "pulsar después pasa a la siguiente")
	assert_eq(q.current.text, "dos")
	assert_true(q.tick(1.0, 45.0, 3), "se completa sola al llegar a todas las letras")
	assert_eq(q.press(), DialogueQueue.Press.FINISHED)
	assert_false(q.is_active)
	assert_eq(q.press(), DialogueQueue.Press.IGNORED)


func test_queue_empty_start_finishes() -> void:
	var q := DialogueQueue.new()
	assert_false(q.start([]))
	assert_false(q.is_active)


func test_box_emits_line_started_and_finished() -> void:
	var box: DialogueBox = BOX_SCENE.instantiate()
	box.handle_input = false
	add_child_autofree(box)
	watch_signals(box)
	box.show_lines([{ "speaker": "Sfida", "text": "Brille tu Luz, adoc." }, "Segunda"])
	assert_true(box.visible)
	assert_true(box.is_open())
	assert_signal_emit_count(box, "line_started", 1)
	assert_eq(box.get_node("Speaker").text, "Sfida")
	assert_eq(box.get_node("Text").visible_characters, 0, "empieza a escribir")
	assert_false(box.handle(_press(&"move_up")), "otras acciones no avanzan")
	assert_true(box.handle(_press(&"interact")), "E completa")
	assert_eq(box.get_node("Text").visible_characters, -1)
	assert_signal_emit_count(box, "line_started", 1)
	box.handle(_press(&"ui_accept"))
	assert_signal_emit_count(box, "line_started", 2)
	assert_eq(box.get_node("Text").text, "Segunda")
	assert_false(box.get_node("Speaker").visible, "sin hablante no se muestra el nombre")
	box.handle(_press(&"ui_cancel"))
	box.handle(_press(&"ui_accept"))
	assert_signal_emitted(box, "finished")
	assert_false(box.is_open())
	assert_false(box.visible, "hide_when_done la oculta")


func test_box_ask_emits_choice_and_cancel_picks_last() -> void:
	var box: DialogueBox = BOX_SCENE.instantiate()
	box.handle_input = false
	add_child_autofree(box)
	watch_signals(box)
	box.ask({ "speaker": "Sfida", "text": "¿Saldrás a su encuentro?" }, ["Acepto", "Aún no"])
	assert_true(box.is_open())
	box.handle(_press(&"ui_down"))
	box.handle(_press(&"ui_accept"))
	assert_signal_emitted_with_parameters(box, "choice", [1])
	assert_false(box.is_open())
	var other: DialogueBox = BOX_SCENE.instantiate()
	other.handle_input = false
	add_child_autofree(other)
	watch_signals(other)
	other.ask("¿Seguro?", ["Sí", "No"])
	other.handle(_press(&"ui_cancel"))
	assert_signal_emitted_with_parameters(other, "choice", [1])


func test_box_arrow_points_to_line_direction() -> void:
	var box: DialogueBox = BOX_SCENE.instantiate()
	box.handle_input = false
	add_child_autofree(box)
	var arrow: Polygon2D = box.get_node("Arrow")
	box.show_lines([{ "text": "Hacia Villa Honda: sur.", "arrow": Vector2i.DOWN }, "Sin flecha"])
	assert_true(arrow.visible)
	assert_almost_eq(arrow.rotation, PI / 2.0, 0.001, "sur = abajo en pantalla")
	box.handle(_press(&"ui_accept"))
	box.handle(_press(&"ui_accept"))
	assert_false(arrow.visible)
