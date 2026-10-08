extends SceneTree

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var cases := []
	for blocked in [false, true]:
		var stage := Node3D.new()
		root.add_child(stage)
		var actor := CharacterBody3D.new()
		actor.safe_margin = 0.001
		stage.add_child(actor)
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.1
		capsule.height = 0.8
		collision.shape = capsule
		collision.position.y = 0.4
		actor.add_child(collision)
		if blocked:
			var wall := StaticBody3D.new()
			stage.add_child(wall)
			wall.position = Vector3(0, 0.4, 0.15)
			var wall_collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1, 0.8, 0.04)
			wall_collision.shape = box
			wall.add_child(wall_collision)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(args[0], state) != OK:
			quit(3)
			return
		var model := document.generate_scene(state)
		actor.add_child(model)
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var motion: Node3D = model.find_child("DOBERMAN_WORLD_MOTION", true, false)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("start")
		await physics_frame
		await physics_frame
		var previous := Vector3.ZERO
		var desired_total := Vector3.ZERO
		var collisions := 0
		var maximum_carrier_residual := 0.0
		for frame in 19:
			player.seek(float(frame) / 30.0, true)
			player.advance(0.0)
			var sampled := motion.position
			var delta := sampled - previous
			previous = sampled
			desired_total += delta
			if actor.move_and_collide(delta) != null:
				collisions += 1
			motion.position = Vector3.ZERO
			maximum_carrier_residual = maxf(maximum_carrier_residual, motion.position.length())
			await physics_frame
		cases.append({"wall_present": blocked, "requested_travel_m": desired_total.length(),
			"achieved_travel_m": actor.position.length(), "collision_count": collisions,
			"actor_front_z": actor.position.z + capsule.radius,
			"wall_near_face_z": 0.13 if blocked else null,
			"maximum_motion_carrier_residual_m": maximum_carrier_residual})
		stage.queue_free()
		await physics_frame
	var passed: bool = abs(float(cases[0].achieved_travel_m) - 0.0923076923) < 0.00001
	# Contact positions are checked against the explicitly configured recovery
	# margin, rather than claiming an exact zero-tolerance geometric contact.
	var contact_tolerance_m := 0.001
	passed = passed and int(cases[1].collision_count) > 0 and float(cases[1].actor_front_z) <= 0.13 + contact_tolerance_m
	passed = passed and float(cases[1].achieved_travel_m) < float(cases[0].achieved_travel_m)
	var report := {"runtime_approved": false, "animation_approved": false,
		"source_glb_sha256": FileAccess.get_sha256(args[0]), "cases": cases,
		"collision_probe_passed": passed,
		"contact_tolerance_m": contact_tolerance_m,
		"scope": "Isolated CharacterBody3D capsule and static wall with extracted GLB start motion. Production 2D collisions, visual limb clearance, blocked-animation handling and input responsiveness remain unverified."}
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if passed else 4)
