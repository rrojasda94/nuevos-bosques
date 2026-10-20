extends Node2D
## Escena raíz. Solo arranque y cambio de escenas; nada de lógica de juego.


func _ready() -> void:
	GameState.new_game()
	EventBus.tick.connect(_on_tick)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)


func _on_tick(ticks: int) -> void:
	$Label.text = "NUEVOS BOSQUES\ntick %d" % ticks


func _on_scene_change_requested(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
