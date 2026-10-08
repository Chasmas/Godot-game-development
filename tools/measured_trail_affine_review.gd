extends Node
const TextureFit = preload("res://tools/melee_texture_fit.gd")
func _ready() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/melee_trail_review/actual_weapon_paths_16.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 430)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var visuals := []
	var trails := []
	var histories := []
	var residuals := []
	var table_fit := OS.get_environment("MELEE_FIT_TABLE") == "1"
	var capture_directory := "table_motion" if table_fit else "affine_motion"
	var phase_steps := 14 if OS.get_environment("MELEE_REVIEW_60FPS") == "1" else 65
	for row in 2:
		var weapon := "bat"
		for direction in 8:
			var heading_index := row * 8 + direction
			var cell := Node2D.new()
			cell.position = Vector2(80 + direction * 160, 165 + row * 210)
			cell.scale = Vector2.ONE * 3.0
			viewport.add_child(cell)
			var visual := CharacterVisual.new()
			cell.add_child(visual)
			visual.setup("cass")
			visual.set_process(false)
			visual.set_weapon(DB.weapon(StringName(weapon)))
			visual.set_aim((heading_index + 0.5) * TAU / 16.0)
			visual._cast_velocity = Vector2.from_angle(visual.aim_angle + PI * 0.5) * 118.0
			for warmup in 24:
				visual._process_cast(1.0 / 120.0)
			visual.swing(false, weapon == "knife")
			visual._swing_t = visual._swing_dur * 0.62
			visuals.append(visual)
			var trail := Sprite2D.new()
			trail.texture = load("res://build/melee_trail_review/measured_dense/%s/%s/005.png" % [weapon, str(heading_index * 22.5).trim_suffix(".0")])
			trail.scale = Vector2.ONE * 80.0 / 256.0
			trail.z_index = 25
			cell.add_child(trail)
			trails.append(trail)
			histories.append([])
			var label := Label.new()
			label.position = Vector2(12 + direction * 160, 183 + row * 210)
			label.text = "%s %s degrees" % [weapon, str(heading_index * 22.5 + 11.25)]
			viewport.add_child(label)
	DirAccess.make_dir_recursive_absolute("res://build/melee_trail_review/measured_dense/" + capture_directory)
	for frame in phase_steps:
		var phase := minf(float(frame) / (phase_steps - 1), 0.995)
		for direction in 16:
			var visual: CharacterVisual = visuals[direction]
			visual._swing_t = maxf(0.0, (phase - 1.0 / (phase_steps - 1)) * visual._swing_dur)
			visual.position += visual._cast_velocity * visual._swing_dur / (phase_steps - 1)
			visual._process_cast(visual._swing_dur / (phase_steps - 1))
			var trail: Sprite2D = trails[direction]
			var pose := clampi(roundi((visual.cast_sprite as CastModel)._progress * 64.0), 0, 64)
			trail.texture = load("res://build/melee_trail_review/measured_dense/bat/%s/%03d.png" % [str(direction * 22.5).trim_suffix(".0"), pose])
			var baked_points: Array = source.samples[direction].points
			var tip: Array = baked_points[pose].tip
			var baked_head := Vector2(tip[0], tip[1])
			var actual_head := (visual.muzzle_tip_global() - visual.global_position) / visual.global_scale
			histories[direction].append({"pose": pose, "tip": actual_head})
			var source_vectors := []
			var target_vectors := []
			for history in histories[direction].slice(maxi(0, histories[direction].size() - 9)):
				if history.pose < pose - 8:
					continue
				var baked_tip: Array = baked_points[history.pose].tip
				source_vectors.append(Vector2(baked_tip[0], baked_tip[1]) - baked_head)
				target_vectors.append(history.tip - actual_head)
			var fit_source := source_vectors
			var fit_target := target_vectors
			if table_fit:
				fit_source = []
				fit_target = []
				var neighbor: Array = source.samples[(direction + 1) % 16].points
				var neighbor_tip: Array = neighbor[pose].tip
				var predicted_head := baked_head.lerp(Vector2(neighbor_tip[0], neighbor_tip[1]), 0.5)
				for sample_pose in range(maxi(0, pose - 8), pose + 1):
					var first: Array = baked_points[sample_pose].tip
					var second: Array = neighbor[sample_pose].tip
					var base_point := Vector2(first[0], first[1])
					fit_source.append(base_point - baked_head)
					fit_target.append(base_point.lerp(Vector2(second[0], second[1]), 0.5) - predicted_head)
			var basis: Transform2D = TextureFit.fit(fit_source, fit_target)
			var error := 0.0
			for sample in source_vectors.size():
				error = maxf(error, basis.basis_xform(source_vectors[sample]).distance_to(target_vectors[sample]))
			residuals.append({"phase":phase,"heading":direction * 22.5 + 11.25,"error_px":error,"translation_fallback":basis == Transform2D.IDENTITY})
			trail.transform = Transform2D(basis.x * 80.0 / 256.0, basis.y * 80.0 / 256.0, visual.position + actual_head - basis.basis_xform(baked_head))
			trail.modulate.a = 0.0 if phase < 0.22 else 1.0 - clampf((phase - 0.62) / 0.38, 0.0, 1.0)
		for settle in 2:
			await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://build/melee_trail_review/measured_dense/%s/%03d.png" % [capture_directory, frame])
	var audit := FileAccess.open("res://build/melee_trail_review/measured_dense/bounded_residuals_table.json" if table_fit else "res://build/melee_trail_review/measured_dense/bounded_residuals_60fps.json" if phase_steps == 14 else "res://build/melee_trail_review/measured_dense/bounded_residuals.json", FileAccess.WRITE)
	audit.store_string(JSON.stringify(residuals,"  "))
	audit.close()
	print("AFFINE TRAIL REVIEW: captured live bounded fit at 16 midpoint headings")
	Game.request_quit()
