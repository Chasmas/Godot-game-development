extends Node
## Review shots of one boss through its fight, at game scale, cropped round it:
## before the fight (Harcourt seated, smoking), fighting, phase two, the final
## fall. Non-headless:
##   BOSS_MISSION=m01_checkout BOSS_OUT=C:/tmp_shots/boss/m01 godot --path . res://tools/boss_capture.tscn --display-driver windows --audio-driver Dummy

func _shot(level: Level, boss: Node2D, out: String, tag: String) -> void:
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		push_warning("Boss capture skipped: headless renderer has no visual texture")
		return
	var texture := get_viewport().get_texture()
	if not texture:
		push_warning("Boss capture skipped: no viewport texture")
		return
	var img := texture.get_image()
	var vs := Vector2(img.get_size())
	var at := boss.get_global_transform_with_canvas().origin * vs / get_viewport().get_visible_rect().size
	var half := Vector2(200, 160)
	var r := Rect2i(Vector2i((at - half).clamp(Vector2.ZERO, vs - half * 2.0)), Vector2i(half * 2.0))
	var crop := img.get_region(r)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s_%s.png" % [out, tag])
	print("boss shot ", tag, " cast=", (boss as Enemy).visual.cast_sprite != null, " clip=", (boss as Enemy).visual.cast_sprite.clip if (boss as Enemy).visual.cast_sprite else "-")

func _wait(n: int) -> void:
	for i in n:
		if Dialogue.active: Dialogue._end()
		await get_tree().process_frame

func _ready() -> void:
	Engine.set_meta("autoplay", true)
	Engine.set_meta("trailer", true)
	Game.force_intro_calls = false
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.start_mission(OS.get_environment("BOSS_MISSION"))
	var out := OS.get_environment("BOSS_OUT")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	for i in 600:
		if Dialogue.active: Dialogue._end()
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl: pl.god_mode = true
		await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	var p := get_tree().get_first_node_in_group("player") as Player
	var boss := level.boss as BossNightManager
	if boss == null:
		print("boss capture: no boss in this mission")
		get_tree().quit()
		return
	# the rest of the floor stays out of it
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != boss:
			(e as Node2D).process_mode = Node.PROCESS_MODE_DISABLED
			(e as Node2D).visible = false
	p.input_enabled = false
	p.global_position = boss.global_position + Vector2(90, 40)
	level.camera.target = boss
	level.camera.snap_to_target()
	await _wait(30)
	await _shot(level, boss, out, "1_before")
	boss.activate()
	await _wait(90)
	await _shot(level, boss, out, "2_fight")
	boss._start_phase_two()
	await _wait(60)
	await _shot(level, boss, out, "3_phase2")
	var info := DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT)
	info.from_player = true
	boss._final_down(info)
	await _wait(90)
	await _shot(level, boss, out, "4_down")
	boss.resolve(true, p)
	await _wait(90)
	await _shot(level, boss, out, "5_dead")
	print("boss capture done")
	get_tree().quit()
