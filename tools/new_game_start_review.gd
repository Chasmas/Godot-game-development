extends Node

const CUTSCENE_SCRIPT := "res://scripts/narrative/cutscene.gd"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_become_root")

func _become_root() -> void:
	# The test itself has to survive Game.change_scene(), just like an autoload.
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	call_deferred("_review")

func _review() -> void:
	# Headless tools use the isolated dev save, so this executes the exact title
	# screen New Game path without touching player progress.
	await get_tree().process_frame
	Game.new_game()
	var cutscene: Node = null
	for _frame in 360:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current and current.get_script() and current.get_script().resource_path == CUTSCENE_SCRIPT:
			cutscene = current
			break
	assert(cutscene != null, "New Game must enter the prologue cutscene")
	# Let Cutscene._ready() complete its real-time 1.4-second opening beat.
	await get_tree().create_timer(1.8, true, false, true).timeout
	assert(is_instance_valid(cutscene), "Prologue must remain alive after New Game startup")
	assert(Dialogue.active, "Prologue dialogue must start after its intro beat")
	assert(Dialogue.finished.is_connected(cutscene._on_finished), "Prologue must receive its finished callback")
	assert(Dialogue.event.is_connected(cutscene._on_event), "Prologue must receive its event callback")
	Dialogue._end(false)
	get_tree().paused = false
	print("NEW GAME START REVIEW PASSED: prologue loads, starts dialogue, and owns its callbacks")
	get_tree().quit()
