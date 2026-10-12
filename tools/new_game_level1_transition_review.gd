extends Node

## Exercises the shipped New Game route through both opening cutscenes and
## into M01.  This guards against assets that load from loose files but fail
## once they are packed into the Windows executable.

const CUTSCENE_SCRIPT := "res://scripts/narrative/cutscene.gd"
const LEVEL_SCRIPT := "res://scripts/levels/level.gd"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_become_root")

func _become_root() -> void:
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	call_deferred("_review")

func _await_scene(script_path: String, limit := 720) -> Node:
	for _frame in limit:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current and current.get_script() and current.get_script().resource_path == script_path:
			return current
	return null

func _await_cutscene(cutscene_id: String, limit := 720) -> Node:
	for _frame in limit:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current and current.get_script() and current.get_script().resource_path == CUTSCENE_SCRIPT and str(current.get("id")) == cutscene_id:
			return current
	return null

func _review() -> void:
	Game.new_game()
	var prologue := await _await_scene(CUTSCENE_SCRIPT)
	assert(prologue != null, "New Game must open the prologue cutscene")
	prologue.call("_skip")
	var apartment := await _await_cutscene("apartment_1988")
	assert(apartment != null, "Skipping the prologue must open the apartment cutscene")
	apartment.call("_skip")
	var level := await _await_scene(LEVEL_SCRIPT)
	assert(level != null, "Skipping both opening cutscenes must load M01")
	assert(level.mission != null and level.mission.id == &"m01_checkout", "M01 must resolve its mission data")
	assert(is_instance_valid(level.player), "M01 must spawn a valid player")
	assert(ArtLib.sprite("pyro_charge") != null, "The explosive charge art must be available through packed resources")
	print("NEW GAME LEVEL 1 TRANSITION REVIEW PASSED: M01 and Cass load after both opening cutscenes")
	get_tree().quit()
