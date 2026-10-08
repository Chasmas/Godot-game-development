extends Node

var failures := 0
var dialogue_finished := false

func _ready() -> void:
	await get_tree().process_frame
	Dialogue.finished.connect(func(_id): dialogue_finished = true)
	Dialogue.start("prologue", false)
	Dialogue._goto("e")
	if not Dialogue._has_authored_voice or not Dialogue._line_voice.playing:
		failures += 1
		push_error("Shutdown fixture needs a playing authored voice")
	Audio.play("vhs_static")
	Audio.play_at("pistol", Vector2.ZERO)
	Music.play("title", true, 0.0)
	Music.play("apartment", true, 1.0)
	await get_tree().process_frame
	Game.request_quit()
	Game.request_quit() # repeated window/menu requests must not restart shutdown
	if dialogue_finished:
		failures += 1
		push_error("Quitting incorrectly completes the story dialogue")
	_check_players(get_tree().root)
	Audio.play("vhs_static")
	Music.play("title", true, 0.0)
	_check_players(get_tree().root)
	if not Music._players.is_empty() or not Music._outgoing.is_empty() or not Audio._cache.is_empty():
		failures += 1
		push_error("Shutdown retains pooled audio or restarts music")
	print("AUDIO SHUTDOWN REGRESSION: ", failures, " failures")
	if failures:
		get_tree().quit(1)

func _check_players(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if node.playing or node.stream != null:
			failures += 1
			push_error("Shutdown retains playback: " + str(node.get_path()))
	for child in node.get_children():
		_check_players(child)
