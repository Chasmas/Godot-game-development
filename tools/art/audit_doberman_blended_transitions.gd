extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		quit(2)
		return
	var samples := []
	var natural := args.has("--natural")
	for direction in ["idle_to_walk", "walk_to_idle"]:
		for phase in [0.0, 0.25, 0.5, 0.75]:
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
			if args.has("--restore-static"):
				var idle := player.get_animation("idle")
				var walk := player.get_animation("walk")
				for track in walk.get_track_count():
					var path := walk.track_get_path(track)
					var kind := walk.track_get_type(track)
					if idle.find_track(path, kind) >= 0 or kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
						continue
					var bone := skeleton.find_bone(path.get_subname(0))
					if bone < 0:
						quit(5)
						return
					var added := idle.add_track(kind)
					idle.track_set_path(added, path)
					var value: Variant
					if kind == Animation.TYPE_POSITION_3D:
						value = skeleton.get_bone_pose_position(bone)
					elif kind == Animation.TYPE_ROTATION_3D:
						value = skeleton.get_bone_pose_rotation(bone)
					else:
						value = skeleton.get_bone_pose_scale(bone)
					idle.track_insert_key(added, 0.0, value)
					idle.track_insert_key(added, idle.length, value)
			var arrays := mesh.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var soles: Array[int] = []
			for index in vertices.size():
				var p := vertices[index]
				if p.y < 0.06 and absf(p.x) > 0.025 and absf(p.z) > 0.13:
					soles.append(index)
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for clip in ["idle", "walk"]:
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			player.play("idle" if direction == "idle_to_walk" else "walk")
			if natural:
				player.advance(1.2 if direction == "idle_to_walk" else phase)
			else:
				player.seek(1.2 if direction == "idle_to_walk" else phase, true)
				player.advance(0.0)
			player.play("walk" if direction == "idle_to_walk" else "idle", 0.2)
			if direction == "idle_to_walk" and not natural:
				player.seek(phase, false)
			var previous := PackedVector3Array()
			var track_modes := []
			if samples.is_empty():
				for clip in ["idle", "walk"]:
					var animation := player.get_animation(clip)
					for track in animation.get_track_count():
						track_modes.append({"clip": clip, "path": str(animation.track_get_path(track)),
							"type": animation.track_get_type(track), "interpolation": animation.track_get_interpolation_type(track)})
			var minimum_height := INF
			var maximum_step := 0.0
			var steps := []
			for frame in 13:
				player.advance(0.0 if frame == 0 else 1.0 / 60.0)
				await process_frame
				skeleton.force_update_all_bone_transforms()
				var transforms: Array[Transform3D] = []
				for binding in mesh.skin.get_bind_count():
					var name := mesh.skin.get_bind_name(binding)
					var bone := skeleton.find_bone(name) if name != &"" else mesh.skin.get_bind_bone(binding)
					if bone < 0 or bone >= skeleton.get_bone_count():
						push_error("Invalid skin binding")
						quit(4)
						return
					transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(binding))
				var points := PackedVector3Array()
				for index in soles:
					var point := Vector3.ZERO
					for influence in 4:
						var slot := index * 4 + influence
						point += transforms[joints[slot]] * vertices[index] * weights[slot]
					minimum_height = minf(minimum_height, point.y)
					points.append(point)
				if not previous.is_empty():
					var frame_step := 0.0
					for index in points.size():
						frame_step = maxf(frame_step, points[index].distance_to(previous[index]))
					maximum_step = maxf(maximum_step, frame_step)
					steps.append(frame_step)
				previous = points
			samples.append({"direction": direction, "walk_phase_seconds": phase,
				"minimum_sole_height_m": minimum_height,
				"maximum_sole_local_step_m": maximum_step, "steps_m": steps, "frames": 13,
				"target_walk_phase_seconds": 0.0 if natural else phase})
			if not track_modes.is_empty():
				FileAccess.open(args[1].get_base_dir().path_join("transition_track_modes.json"), FileAccess.WRITE).store_string(JSON.stringify(track_modes, "  "))
			model.free()
	var report := {"runtime_approved": false, "animation_approved": false,
		"source_glb_sha256": FileAccess.get_sha256(args[0]), "blend_seconds": 0.2,
		"natural_playback_without_seek": natural,
		"restore_static_idle_channels": args.has("--restore-static"),
		"samples": samples, "scope": "Actual AnimationPlayer crossfade; CPU sole skin heights and local displacement. No world travel, stance classification, morph skin or visual validation."}
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit()
