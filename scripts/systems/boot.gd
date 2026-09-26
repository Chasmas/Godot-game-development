extends Node
## Entry point: settle autoloads, then the studio splash (which leads to the title).

const SPLASH_SCENE := "res://scenes/ui/splash_screen.tscn"

func _ready() -> void:
	await get_tree().process_frame
	Game.change_scene(SPLASH_SCENE, false)
