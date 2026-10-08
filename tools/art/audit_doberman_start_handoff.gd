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
	var trotting := args.has("--trot")
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
	player.play("start_trot" if trotting else "start")
	player.seek(0.6, true)
	player.advance(0.0)
	var travel := motion.position
	var ending := points(mesh, skeleton)
	player.play("trot" if trotting else "walk")
	player.seek(0.4 if trotting else 0.0, true)
	player.advance(0.0)
	model.position += travel
	var uncorrected := difference(ending, points(mesh, skeleton))
	# The actor receives the completed travel once. Clear the animation carrier
	# because immutable zero tracks may have been stripped on direct GLTF load.
	motion.position = Vector3.ZERO
	var corrected := difference(ending, points(mesh, skeleton))
	var report := {"runtime_approved": false, "animation_approved": false,
		"target_clip": "trot" if trotting else "walk", "target_phase_seconds": 0.4 if trotting else 0.0,
		"source_glb_sha256": FileAccess.get_sha256(args[0]), "vertices": ending.size(),
		"extracted_travel_m": travel.length(),
		"handoff_mesh_difference_without_carrier_reset_m": uncorrected,
		"handoff_mesh_difference_with_carrier_reset_m": corrected,
		"scope": "CPU full-mesh start-end/walk-start comparison with zero breath morph and explicit one-time world travel extraction. No collision, continuous velocity or gameplay approval."}
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	var expected_travel := 0.1363636364 if trotting else 0.0923076923
	quit(0 if corrected < 0.0001 and abs(travel.length() - expected_travel) < 0.00001 else 4)
