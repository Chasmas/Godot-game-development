extends Node
## Review shots of Cass firing (muzzle flash, tracer, laser at the barrel tip)
## and of the weapon dropped on the floor. Non-headless:
##   FIRE_WEAPON=rifle FIRE_OUT=C:/tmp_shots/fire godot --path . res://tools/fire_capture.tscn --display-driver windows --audio-driver Dummy

func _ready() -> void:
	Engine.set_meta("autoplay", true)
	Engine.set_meta("trailer", true)
	Game.force_intro_calls = false
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.start_mission("m01_checkout")
	for i in 600:
		if Dialogue.active: Dialogue._end()
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl: pl.god_mode = true
		await get_tree().physics_frame
	var out := OS.get_environment("FIRE_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	var weapon := StringName(OS.get_environment("FIRE_WEAPON") if OS.get_environment("FIRE_WEAPON") != "" else "rifle")
	var level := get_tree().get_first_node_in_group("level") as Level
	var p := get_tree().get_first_node_in_group("player") as Player
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Node2D).process_mode = Node.PROCESS_MODE_DISABLED
	p.input_enabled = false
	p.global_position = Vector2(248, 728)
	p.give_weapon(weapon)
	p.add_upgrade(&"laser", true)
	level.camera.target = p
	level.camera.zoom_bias = 2.0
	level.camera.snap_to_target()
	var n := 0
	for a in [0.0, -0.8, PI * 0.5, PI]:
		p.aim_dir = Vector2.from_angle(a)
		p.aim_point = p.global_position + p.aim_dir * 120.0
		for i in 20:
			await get_tree().process_frame
		p._try_shoot(p.current())
		await RenderingServer.frame_post_draw
		_save(p, "%s/fire_%d.png" % [out, n])
		n += 1
	# the gun on the floor
	p._throw_current()
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(p, "%s/drop.png" % out)
	print("fire capture done")
	get_tree().quit()

func _save(p: Node2D, path: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("Fire capture skipped: headless renderer has no visual texture")
		return
	var texture := get_viewport().get_texture()
	if not texture:
		push_warning("Fire capture skipped: no viewport texture")
		return
	var img := texture.get_image()
	var vs := Vector2(img.get_size())
	var at := p.get_global_transform_with_canvas().origin * vs / get_viewport().get_visible_rect().size
	var half := Vector2(220, 160)
	var r := Rect2i(Vector2i((at - half).clamp(Vector2.ZERO, vs - half * 2.0)), Vector2i(half * 2.0))
	img.get_region(r).save_png(path)
