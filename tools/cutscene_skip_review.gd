extends Node

const CutsceneScript = preload("res://scripts/narrative/cutscene.gd")

func _ready() -> void:
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	assert(CutsceneScript.is_skip_event(escape), "ESC must skip a cutscene")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	assert(not CutsceneScript.is_skip_event(space), "Space must remain available to advance dialogue")
	print("CUTSCENE SKIP REVIEW PASSED: ESC skips and Space advances dialogue")
	get_tree().quit()
