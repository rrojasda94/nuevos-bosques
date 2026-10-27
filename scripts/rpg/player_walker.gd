class_name PlayerWalker
extends RefCounted
## Residuo de la exploración vieja (borrada en M17b): el jugador es PlayerController. Solo reenvía
## su hoja, su placeholder y STEP_TIME a quien aún los pide con este nombre (el combate táctico, la
## exploración y el sigilo, que otras tareas tenían abiertos al borrar el mundo viejo).
## ponytail: borrar en cuanto tactical_battle_scene.gd, battle.gd, world_exploration.gd y stealth.gd
## usen PlayerController.

const STEP_TIME: float = PlayerController.STEP_TIME
const TILE_SIZE: int = PlayerController.TILE_SIZE
const SHEET_PATH: String = PlayerController.SHEET_PATH
const SHEET_ROWS: Array[Vector2i] = PlayerController.SHEET_ROWS
const SHEET_FRAMES: int = PlayerController.SHEET_FRAMES


static func back_texture() -> Texture2D:
	return PlayerController.back_texture()


static func _make_texture(dir: Vector2i) -> Texture2D:
	return PlayerController._make_texture(dir)


static func add_outline(img: Image, color: Color) -> void:
	PlayerController.add_outline(img, color)
