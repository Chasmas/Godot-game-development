extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(2)
		return
	var direct := args.has("--direct")
	var stopping := args.has("--blocked-stop")
	var starting := args.has("--start-contact") or stopping
	var trot_start := args.has("--trot-start")
	var model_path := "res://native_start.glb" if starting else "res://native_walk.glb"
	for arg in args:
		if arg.begins_with("--model="):
			model_path = arg.trim_prefix("--model=")
	var scene: Node3D
	if direct:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var result := document.append_from_file(model_path, state)
		if result != OK:
			quit(6)
			return
		scene = document.generate_scene(state)
	else:
		scene = load(model_path).instantiate()
	root.add_child(scene)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := mesh.skin
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if joints.size() != vertices.size() * 4 or weights.size() != joints.size():
		push_error("Expected four-influence skin")
		quit(3)
		return
	var metadata: Dictionary
	if starting:
		metadata = {"footfall_phase_offsets": {"front_positive_x": 0, "rear_negative_x": 1, "front_negative_x": 2, "rear_positive_x": 3} if stopping else {"front_negative_x": 0, "rear_positive_x": 1, "front_positive_x": 2, "rear_negative_x": 3}}
		if trot_start:
			metadata.footfall_phase_offsets = {"front_negative_x": 0, "rear_positive_x": 0, "front_positive_x": 1, "rear_negative_x": 1}
	else:
		metadata = JSON.parse_string(FileAccess.get_file_as_string(args[0].get_base_dir().get_base_dir().path_join("walk_audit.json")))
	var sole_ids := {}
	for key in metadata.footfall_phase_offsets:
		sole_ids[key] = []
	for index in vertices.size():
		var p := vertices[index]
		if p.y < 0.06 and absf(p.x) > 0.025 and absf(p.z) > 0.13:
			var key := ("front" if p.z > 0.0 else "rear") + ("_negative_x" if p.x < 0.0 else "_positive_x")
			sole_ids[key].append(index)
	var binding_bones: Array[int] = []
	for binding in skin.get_bind_count():
		var name := skin.get_bind_name(binding)
		var bone := skeleton.find_bone(name) if name != &"" else skin.get_bind_bone(binding)
		if bone < 0:
			quit(4)
			return
		binding_bones.append(bone)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(player.get_animation_list()[0])
	var previous := {}
	var maximum_slip := 0.0
	var minimum_height := INF
	var first: PackedVector3Array
	var seam := 0.0
	var initial_support := {}
	var duration := 0.6 if starting else float(metadata.duration_seconds)
	var sample_count := 19 if starting else int(round(duration * 30.0)) + 1
	for frame in sample_count:
		var time := float(frame) / 30.0
		player.seek(time, true)
		player.advance(0.0)
		skeleton.force_update_all_bone_transforms()
		var transforms: Array[Transform3D] = []
		for binding in skin.get_bind_count():
			transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(binding_bones[binding]) * skin.get_bind_pose(binding))
		var points := PackedVector3Array()
		points.resize(vertices.size())
		for index in vertices.size():
			var p := Vector3.ZERO
			for influence in 4:
				var slot := index * 4 + influence
				if weights[slot] > 0.0:
					p += (transforms[joints[slot]] * vertices[index]) * weights[slot]
			points[index] = p
			minimum_height = minf(minimum_height, p.y)
		if frame == 0:
			first = points.duplicate()
			for key in sole_ids:
				var lowest := INF
				for index in sole_ids[key]:
					lowest = minf(lowest, points[index].y)
				initial_support[key] = lowest < 0.001
		if frame == sample_count - 1 and not starting:
			for index in vertices.size():
				seam = maxf(seam, points[index].distance_to(first[index]))
		for key in sole_ids:
			var phase := time if starting else fposmod(time / duration + float(metadata.footfall_phase_offsets[key]), 1.0)
			var planted: bool
			if starting:
				var onset := 0.02 + float(metadata.footfall_phase_offsets[key]) * (0.22 if trot_start else 0.12)
				var swing_duration := 0.22 if trot_start else 0.16
				if stopping:
					planted = (time <= onset and initial_support[key]) or time >= onset + swing_duration
				else:
					planted = time <= onset or (time >= onset + swing_duration and (trot_start or key != "front_positive_x"))
			else:
				planted = phase < float(metadata.leg_stance_fractions[key])
			var soles := PackedVector3Array()
			for index in sole_ids[key]:
				var p := points[index]
				if not starting:
					p.z += float(metadata.matching_forward_speed_m_per_s) * time
				soles.append(p)
			if previous.has(key):
				var prior: Dictionary = previous[key]
				if planted and prior.planted and phase >= prior.phase:
					for index in soles.size():
						maximum_slip = maxf(maximum_slip, soles[index].distance_to(prior.soles[index]))
			previous[key] = {"phase": phase, "planted": planted, "soles": soles}
	var report := {"runtime_approved": false, "animation_approved": false,
		"source_glb_sha256": FileAccess.get_sha256(model_path),
		"mode": "direct_gltf" if direct else "imported_resource", "surface_format": mesh.mesh.surface_get_format(0),
		"animation_tracks": player.get_animation(player.get_animation_list()[0]).get_track_count(),
		"sampled_frames": sample_count, "moving_start": starting and not stopping, "blocked_stop": stopping, "vertices": vertices.size(), "maximum_planted_sole_slip_per_frame_m": maximum_slip,
		"minimum_full_cycle_mesh_height_m": minimum_height, "mesh_loop_seam_m": null if starting else seam,
		"scope": "CPU linear skin reconstruction from actual Godot arrays, skin bindings and animated skeleton in world coordinates; start includes object travel and authored stance schedule, walk uses external matched travel. No GPU vertex readback or gameplay approval"}
	FileAccess.open(args[0], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if maximum_slip < 0.0001 and minimum_height > -0.0001 and seam < 0.00001 else 5)
