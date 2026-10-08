extends Node
## Review shot of Cass rolling (3D afterimages).
func _ready() -> void:
	Engine.set_meta("autoplay", true)
	Engine.set_meta("trailer", true)
	Game.force_intro_calls = false
	await get_tree().process_frame
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	Game.start_mission("m01_checkout")
	for i in 900:
		if Dialogue.active: Dialogue._end()
		await get_tree().physics_frame
	var p := get_tree().get_first_node_in_group("player") as Player
	var level := get_tree().get_first_node_in_group("level") as Level
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Node2D).process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector2(220, 728)
	p.input_enabled = true
	for i in 30:
		await get_tree().process_frame
	level.camera.zoom_bias = 2.0
	p._last_move = Vector2.RIGHT
	p._start_dash()
	for i in 7:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		push_warning("Roll capture skipped: headless renderer has no visual texture")
		get_tree().quit()
		return
	var texture := get_viewport().get_texture()
	if not texture:
		push_warning("Roll capture skipped: no viewport texture")
		get_tree().quit()
		return
	var img := texture.get_image()
	var vs := Vector2(img.get_size())
	var at := p.get_global_transform_with_canvas().origin * vs / get_viewport().get_visible_rect().size
	img.get_region(Rect2i(Vector2i(at - Vector2(300, 180)), Vector2i(600, 360))).save_png(OS.get_environment("ROLL_OUT"))
	print("roll capture done")
	get_tree().quit()
