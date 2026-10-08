extends SceneTree

const DURATION := 2.4

func _initialize() -> void:
	call_deferred("_prepare")

func _snapshot(skeleton: Skeleton3D, mesh: MeshInstance3D) -> Dictionary:
	var poses: Array[Transform3D] = []
	for index in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_pose(index))
	return {"poses": poses, "breath": mesh.get_blend_shape_value(0)}

func _prepare() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var source: PackedScene = load("res://dog.glb")
	var scene := source.instantiate()
	root.add_child(scene)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var clip_name := player.get_animation_list()[0]
	var clip := player.get_animation(clip_name)
	var imported_length := clip.length
	var last_key := 0.0
	for track in clip.get_track_count():
		for key in clip.track_get_key_count(track):
			last_key = maxf(last_key, clip.track_get_key_time(track, key))
	# Independently verify the exported source duration and imported endpoint.
	var source_audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1].get_base_dir().path_join("export_audit.json")))
	var source_duration: float = source_audit.animations[0].duration_seconds
	if absf(source_duration - DURATION) > 0.001 or absf(last_key - DURATION) > 0.001:
		push_error("Unexpected source endpoint; refuse to trim animation")
		quit(3)
		return
	clip.length = DURATION
	clip.loop_mode = Animation.LOOP_NONE
	player.play(clip_name)
	player.seek(0.0, true)
	var start := _snapshot(skeleton, mesh)
	player.seek(DURATION, true)
	var end := _snapshot(skeleton, mesh)
	var translation_seam := 0.0
	var rotation_seam := 0.0
	for index in skeleton.get_bone_count():
		var a: Transform3D = start.poses[index]
		var b: Transform3D = end.poses[index]
		translation_seam = maxf(translation_seam, a.origin.distance_to(b.origin))
		rotation_seam = maxf(rotation_seam, a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()))
	var breath_seam: float = absf(start.breath - end.breath)
	if translation_seam > 0.00001 or rotation_seam > 0.001 or breath_seam > 0.00001:
		push_error("Loop endpoint mismatch; refuse to save candidate")
		quit(4)
		return
	clip.loop_mode = Animation.LOOP_LINEAR
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			if clip.track_get_key_time(track, key) > DURATION + 0.00001:
				clip.track_remove_key(track, key)
	player.seek(0.0, true)
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result == OK:
		result = ResourceSaver.save(packed, args[0])
	var report := {"runtime_approved": false, "imported_length_seconds": imported_length,
		"last_imported_key_seconds": last_key, "source_duration_seconds": source_duration, "corrected_length_seconds": clip.length,
		"loop_translation_seam_m": translation_seam, "loop_rotation_seam_rad": rotation_seam,
		"loop_breath_seam": breath_seam, "save_error": result,
		"scope": "Imported bone and morph endpoint comparison; exported vertex deformation and visual playback pending"}
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if result == OK and translation_seam < 0.00001 and rotation_seam < 0.001 and breath_seam < 0.00001 else 4)
