extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() > 4:
		quit(2)
		return
	var results := []
	var continuous := args.has("--continuous")
	var animated_stop := args.has("--animated-stop")
	for blocked in [false, true]:
		var stage := Node2D.new()
		root.add_child(stage)
		var actor := CharacterBody2D.new()
		actor.safe_margin = 0.01
		stage.add_child(actor)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 5.5
		shape.shape = circle
		actor.add_child(shape)
		if blocked:
			var wall := StaticBody2D.new()
			wall.position = Vector2(7, 0)
			stage.add_child(wall)
			var wall_shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(1, 30)
			wall_shape.shape = rectangle
			wall.add_child(wall_shape)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(args[0], state) != OK:
			quit(3)
			return
		var model := document.generate_scene(state)
		root.add_child(model)
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var carrier: Node3D = model.find_child("DOBERMAN_WORLD_MOTION", true, false)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("start")
		await physics_frame
		await physics_frame
		var previous := Vector3.ZERO
		var stopped_frame := -1
		var stop_samples := 0
		var stop_drift := 0.0
		var stop_clip := ""
		for frame in 19:
			player.seek(float(frame) / 30.0, true)
			player.advance(0.0)
			var sampled := carrier.position
			var delta := sampled - previous
			previous = sampled
			var collision := actor.move_and_collide(Vector2(delta.z, -delta.x) * 16.0)
			carrier.position = Vector3.ZERO
			if collision != null:
				stopped_frame = frame
				if animated_stop:
					stop_clip = "stop_%02d" % (frame + 1)
					if not player.has_animation(stop_clip):
						push_error("No authored stop for collision frame: " + stop_clip)
						quit(5)
						return
					var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
					skeleton.reset_bone_poses()
					player.play(stop_clip)
					var stopped_position := actor.position
					for stop_frame in 19:
						player.seek(float(stop_frame) / 30.0, true)
						player.advance(0.0)
						carrier.position = Vector3.ZERO
						stop_drift = maxf(stop_drift, actor.position.distance_to(stopped_position))
						stop_samples += 1
						await physics_frame
					skeleton.reset_bone_poses()
				player.play("idle")
				player.seek(0.0, true)
				player.advance(0.0)
				carrier.position = Vector3.ZERO
				break
			await physics_frame
		var walking_frames := 0
		if continuous and stopped_frame < 0:
			player.play("walk")
			for frame in 90:
				player.seek(float(frame % 30) / 30.0, true)
				player.advance(0.0)
				carrier.position = Vector3.ZERO
				var collision := actor.move_and_collide(Vector2(0.3076923077 * 16.0 / 30.0, 0.0))
				if collision != null:
					stopped_frame = 19 + frame
					break
				walking_frames += 1
				await physics_frame
		results.append({"wall_present": blocked, "achieved_travel_px": actor.position.length(),
			"stop_clip": stop_clip, "stop_sampled_frames": stop_samples, "stop_actor_drift_px": stop_drift,
			"continuous_walk_frames": walking_frames,
			"blocked_frame": stopped_frame, "final_clip": player.current_animation,
			"carrier_residual_m": carrier.position.length(),
			"collider_front_x": actor.position.x + circle.radius,
			"wall_near_face_x": 6.5 if blocked else null})
		model.queue_free()
		stage.queue_free()
		await physics_frame
	var expected_travel := (0.0923076923 + (0.3076923077 * 3.0 if continuous else 0.0)) * 16.0
	var passed: bool = abs(float(results[0].achieved_travel_px) - expected_travel) < 0.001
	if continuous:
		passed = passed and int(results[0].continuous_walk_frames) == 90 and results[0].final_clip == "walk"
	if animated_stop:
		passed = passed and int(results[1].stop_sampled_frames) == 19 and float(results[1].stop_actor_drift_px) < 0.00001
	passed = passed and int(results[1].blocked_frame) >= 0 and results[1].final_clip == "idle"
	passed = passed and float(results[1].collider_front_x) <= 6.51 and float(results[1].carrier_residual_m) < 0.00001
	var report := {"runtime_approved": false, "animation_approved": false,
		"continuous_walk_enabled": continuous, "expected_free_travel_px": expected_travel,
		"animated_stop_enabled": animated_stop,
		"source_glb_sha256": FileAccess.get_sha256(args[0]), "passed": passed,
		"pixels_per_metre": 16, "contact_tolerance_px": 0.01, "cases": results,
		"scope": "Isolated CharacterBody2D contact prototype with dog-sized circle, GLB travel extraction and blocked idle reset. Production navigation, visual contact continuity and input handling remain unverified."}
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if passed else 4)
