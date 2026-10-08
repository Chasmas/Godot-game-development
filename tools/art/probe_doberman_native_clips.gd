extends SceneTree

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(args[0], state) != OK:
		quit(3)
		return
	var model := document.generate_scene(state)
	root.add_child(model)
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var results := {}
	for clip in ["idle", "walk"]:
		player.play(clip)
		player.seek(0.0, true)
		player.advance(0.0)
		var start: Array[Transform3D] = []
		for bone in skeleton.get_bone_count():
			start.append(skeleton.get_bone_global_pose(bone))
		var initial_morph := mesh.get_blend_shape_value(0)
		player.seek(player.get_animation(clip).length, true)
		player.advance(0.0)
		var position_error := 0.0
		var basis_error := 0.0
		for bone in skeleton.get_bone_count():
			var ending := skeleton.get_bone_global_pose(bone)
			position_error = max(position_error, ending.origin.distance_to(start[bone].origin))
			for axis in 3:
				basis_error = max(basis_error, ending.basis[axis].distance_to(start[bone].basis[axis]))
		results[clip] = {"length_seconds": player.get_animation(clip).length,
			"loop_translation_difference_m": position_error, "loop_basis_column_difference": basis_error,
			"loop_morph_difference": abs(mesh.get_blend_shape_value(0) - initial_morph)}
	player.play("idle")
	player.seek(1.2, true)
	player.advance(0.0)
	var peak_breath := mesh.get_blend_shape_value(0)
	player.play("walk")
	player.seek(0.5, true)
	player.advance(0.0)
	var walk_breath := mesh.get_blend_shape_value(0)
	player.play("idle")
	player.seek(0.0, true)
	player.advance(0.0)
	var reset_breath := mesh.get_blend_shape_value(0)
	var report := {"runtime_approved": false, "animation_approved": false,
		"source_glb_sha256": FileAccess.get_sha256(args[0]), "clips": results,
		"idle_peak_breath": peak_breath, "walk_breath_after_idle": walk_breath,
		"idle_start_breath_after_walk": reset_breath,
		"scope": "Direct GLTF skeleton endpoints and morph reset; blended transition contact and visual validation pending"}
	if player.has_animation("start"):
		player.play("start")
		player.seek(0.0, true)
		player.advance(0.0)
		var origin := skeleton.global_position
		player.seek(player.get_animation("start").length, true)
		player.advance(0.0)
		report["start_world_translation_m"] = skeleton.global_position.distance_to(origin)
		report["start_duration_seconds"] = player.get_animation("start").length
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	var passed: bool = peak_breath > 0.99 and abs(walk_breath) < 0.00001 and abs(reset_breath) < 0.00001
	if player.has_animation("start"):
		passed = passed and abs(float(report.start_world_translation_m) - 0.09230769230769231) < 0.00001
	for clip in results:
		passed = passed and results[clip].loop_translation_difference_m < 0.00001 and results[clip].loop_basis_column_difference < 0.00001 and results[clip].loop_morph_difference < 0.00001
	quit(0 if passed else 4)
