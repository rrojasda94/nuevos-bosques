extends Node2D
## Escena raíz. Solo arranque y cambio de escenas; nada de lógica de juego.
## Vertical slice: arranca directamente en la exploración de Aventura.


func _ready() -> void:
	GameState.new_game()
	EventBus.end_day_requested.connect($DayManager.end_day)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	$Exploration.start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		EventBus.end_day_requested.emit()


func _on_scene_change_requested(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
