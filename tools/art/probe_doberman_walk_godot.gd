extends SceneTree

func _initialize() -> void:
	call_deferred("_probe")

func _probe() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(2)
		return
	var model_path := "res://native_walk.glb" if args.has("--native") else "res://walk.glb"
	var scene: Node3D = load(model_path).instantiate()
	root.add_child(scene)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var name := player.get_animation_list()[0]
	var animation := player.get_animation(name)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(name)
	player.seek(0.0, true)
	player.advance(0.0)
	var start: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		start.append(skeleton.get_bone_pose(bone))
	player.seek(animation.length, true)
	player.advance(0.0)
	var translation_error := 0.0
	var basis_error := 0.0
	for bone in skeleton.get_bone_count():
		var finish := skeleton.get_bone_pose(bone)
		translation_error = maxf(translation_error, start[bone].origin.distance_to(finish.origin))
		for axis in 3:
			basis_error = maxf(basis_error, start[bone].basis[axis].distance_to(finish.basis[axis]))
	var report := {"runtime_approved": false, "animation_approved": false,
		"source_glb_sha256": FileAccess.get_sha256(model_path),
		"clip": name, "length_seconds": animation.length, "bones": skeleton.get_bone_count(),
		"tracks": animation.get_track_count(), "loop_translation_difference_m": translation_error,
		"loop_basis_column_difference": basis_error,
		"scope": "Imported skeleton endpoint check; no gameplay or vertex contact approval"}
	FileAccess.open(args[0], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if absf(animation.length-1.0)<0.0001 and translation_error<0.00001 and basis_error<0.00001 else 3)
