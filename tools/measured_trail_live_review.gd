extends Node
func _ready() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/melee_trail_review/actual_weapon_paths_16.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 220)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var visuals := []
	var trails := []
	for row in 1:
		var weapon := "bat" if row == 0 else "knife"
		for direction in 8:
			var cell := Node2D.new()
			cell.position = Vector2(80 + direction * 160, 165 + row * 210)
			cell.scale = Vector2.ONE * 3.0
			viewport.add_child(cell)
			var visual := CharacterVisual.new()
			cell.add_child(visual)
			visual.setup("cass")
			visual.set_process(false)
			visual.set_weapon(DB.weapon(StringName(weapon)))
			visual.set_aim((direction + 0.5) * TAU / 8.0)
			visual._cast_velocity = Vector2.from_angle(visual.aim_angle + PI * 0.5) * 118.0
			for warmup in 24:
				visual._process_cast(1.0 / 120.0)
			visual.swing(false, weapon == "knife")
			visual._swing_t = visual._swing_dur * 0.62
			visuals.append(visual)
			var trail := Sprite2D.new()
			trail.texture = load("res://build/melee_trail_review/measured_dense/%s/%s/005.png" % [weapon, str(direction * 45 + 22.5)])
			trail.scale = Vector2.ONE * 80.0 / 256.0
			trail.z_index = 25
			cell.add_child(trail)
			trails.append(trail)
			var label := Label.new()
			label.position = Vector2(12 + direction * 160, 183 + row * 210)
			label.text = "%s %s degrees" % [weapon, str(direction * 45 + 22.5)]
			viewport.add_child(label)
	DirAccess.make_dir_recursive_absolute("res://build/melee_trail_review/measured_dense/live_motion")
	for frame in 65:
		var phase := minf(frame / 64.0, 0.995)
		for direction in 8:
			var visual: CharacterVisual = visuals[direction]
			visual._swing_t = maxf(0.0, (phase - 1.0 / 64.0) * visual._swing_dur)
			visual.position += visual._cast_velocity * visual._swing_dur / 64.0
			visual._process_cast(visual._swing_dur / 64.0)
			var trail: Sprite2D = trails[direction]
			var pose := clampi(roundi((visual.cast_sprite as CastModel)._progress * 64.0), 0, 64)
			trail.texture = load("res://build/melee_trail_review/measured_dense/bat/%s/%03d.png" % [str(direction * 45 + 22.5), pose])
			var tip: Array = source.samples[direction * 2 + 1].points[pose].tip
			trail.global_position = visual.muzzle_tip_global() - Vector2(tip[0], tip[1]) * visual.global_scale
			trail.modulate.a = 0.0 if phase < 0.22 else 1.0 - clampf((phase - 0.62) / 0.38, 0.0, 1.0)
		for settle in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://build/melee_trail_review/measured_dense/live_motion/%03d.png" % frame)
	print("LIVE TRAIL REVIEW: captured moving Cass at 8 intermediate headings")
	Game.request_quit()
