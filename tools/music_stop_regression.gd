extends Node

func _ready() -> void:
	Music.play("menu", true, 0.0)
	await get_tree().process_frame
	Music.play("vcr", true, 5.0)
	await get_tree().process_frame
	var failures := 0
	if Music._outgoing.is_empty():
		failures += 1
		push_error("Test did not create an outgoing crossfade")
	Music.stop(0.0)
	for child in Music.get_children():
		if child is AudioStreamPlayer and (child.playing or child.stream != null):
			failures += 1
			push_error("Immediate stop leaves a music stream active")
	if not Music._outgoing.is_empty() or not Music._players.is_empty():
		failures += 1
		push_error("Immediate stop retains crossfade players")
	await get_tree().process_frame
	Music.play("menu", true, 0.0)
	if Music._players.is_empty() or not Music._players[0].playing:
		failures += 1
		push_error("Music cannot restart after immediate stop")
	Music.stop(0.0)
	await get_tree().create_timer(0.1).timeout
	print("MUSIC STOP REGRESSION: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
