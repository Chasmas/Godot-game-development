extends Node
func _ready() -> void:
	Engine.set_meta("autoplay", true)
	Engine.set_meta("trailer", true)
	Game.force_intro_calls = false
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.start_mission("m01_checkout")
	for i in 900:
		if Dialogue.active: Dialogue._end()
		var player := get_tree().get_first_node_in_group("player") as Player
		if player: player.god_mode = true
		await get_tree().physics_frame
	var p := get_tree().get_first_node_in_group("player") as Player
	var level := get_tree().get_first_node_in_group("level") as Level
	p.set_physics_process(false)
	p.input_enabled = false
	p.visible = true
	p.global_position = Vector2(248, 728)
	p.give_weapon(&"rifle")
	p.visual.set_aim(0.0)
	p.visual.update_move(Vector2.ZERO, 0.016)
	level.camera.target = p
	level.camera.zoom_bias = 1.2
	level.camera.snap_to_target()
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		push_warning("Cast ingame capture skipped: headless renderer has no visual texture")
	else:
		var texture := get_viewport().get_texture()
		if texture:
			var out := OS.get_environment("CAST_PREVIEW_OUT")
			if not out.is_empty(): texture.get_image().save_png(out)
		else:
			push_warning("Cast ingame capture skipped: no viewport texture")
	print("Cass rendered in mission; cast active=", p.visual.cast_sprite != null)
	get_tree().quit()
