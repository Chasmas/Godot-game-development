extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://scenes/boot.tscn") != OK:
		quit(2)
		return
	for frame in 120:
		await process_frame
	var game := root.get_node_or_null("Game")
	if game == null or not game.has_method("request_quit"):
		push_error("Game shutdown entry point unavailable")
		quit(3)
		return
	print("BOOT_SHUTDOWN: requesting normal game exit after 120 frames")
	game.request_quit()
