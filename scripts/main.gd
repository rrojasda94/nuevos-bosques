extends Node2D
## Escena raíz. Solo arranque y cambio de escenas; nada de lógica de juego.


func _ready() -> void:
	GameState.new_game()
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.end_day_requested.connect($DayManager.end_day)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)


func _on_day_ended(day: int) -> void:
	$Label.text = "NARDARAM\nDía %d" % day


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		EventBus.end_day_requested.emit()


func _on_scene_change_requested(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
