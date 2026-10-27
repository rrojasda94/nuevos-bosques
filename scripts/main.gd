extends Node2D
## Escena raíz. Solo arranque y cambio de escenas; nada de lógica de juego.
## Vertical slice: arranca directamente en una partida nueva de Aventura en el Mundo 2.0
## (WorldExploration, ADR 0014). Sin menú principal: F5 guarda y F9 carga (slot rápido).


func _ready() -> void:
	GameState.new_game()
	EventBus.end_day_requested.connect($DayManager.end_day)
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	await $Exploration.start()
	$Exploration.warn_old_save()


func _on_scene_change_requested(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
