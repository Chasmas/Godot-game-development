extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func points(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var transforms: Array[Transform3D] = []
	skeleton.force_update_all_bone_transforms()
	for binding in mesh.skin.get_bind_count():
		var name := mesh.skin.get_bind_name(binding)
		var bone := skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(binding)
		assert(bone >= 0)
		transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(binding))
	var result := PackedVector3Array()
	for index in vertices.size():
		var position := Vector3.ZERO
		for influence in 4:
			var slot := index * 4 + influence
			position += transforms[joints[slot]] * vertices[index] * weights[slot]
		result.append(position)
	return result

func difference(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var maximum := 0.0
	for index in a.size():
		maximum = maxf(maximum, a[index].distance_to(b[index]))
	return maximum

func _audit() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() > 3:
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
	var motion: Node3D = model.find_child("DOBERMAN_WORLD_MOTION", true, false)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var samples := []
	var passed := true
	var reset_static := args.has("--reset-static")
	for frame in [1, 4, 7, 10, 13, 16, 19]:
		model.position = Vector3.ZERO
		motion.position = Vector3.ZERO
		if reset_static:
			skeleton.reset_bone_poses()
		player.play("start")
		player.seek(float(frame - 1) / 30.0, true)
		player.advance(0.0)
		var travel := motion.position
		var source := points(mesh, skeleton)
		if reset_static:
			skeleton.reset_bone_poses()
		player.play("stop_%02d" % frame)
		player.seek(0.0, true)
		player.advance(0.0)
		model.position = travel
		motion.position = Vector3.ZERO
		var entrance := difference(source, points(mesh, skeleton))
		player.seek(0.6, true)
		player.advance(0.0)
		motion.position = Vector3.ZERO
		var ending := points(mesh, skeleton)
		if reset_static:
			skeleton.reset_bone_poses()
		player.play("idle")
		player.seek(0.0, true)
		player.advance(0.0)
		motion.position = Vector3.ZERO
		var exit_error := difference(ending, points(mesh, skeleton))
		samples.append({"source_frame": frame, "start_stop_mesh_difference_m": entrance,
			"stop_idle_mesh_difference_m": exit_error})
		passed = passed and entrance < 0.0001 and exit_error < 0.0001
	var report := {"runtime_approved": false, "animation_approved": false,
		"explicit_static_pose_reset": reset_static,
		"source_glb_sha256": FileAccess.get_sha256(args[0]), "passed": passed,
		"vertices": mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), "samples": samples,
		"scope": "Seven discrete full-mesh endpoint comparisons using actual Godot skin and combined clips, with explicit carrier reset and one-time travel transfer. Continuous blending, contacts during transitions, GPU appearance and gameplay remain pending."}
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if passed else 4)
