extends Node3D

func _ready() -> void:
	var cast_id := OS.get_environment("CAST_STRIDE_REVIEW")
	if cast_id.is_empty(): cast_id = "cass"
	assert(cast_id in ["cass","guard","civilian","boss"])
	var gait := OS.get_environment("CAST_STRIDE_GAIT")
	if gait.is_empty(): gait = "walk"
	assert(gait in ["walk","run","sneak"])
	var directory := "res://build/locomotion_candidates/%s/" % cast_id
	var profile := OS.get_environment("CAST_STRIDE_PROFILE")
	if profile == "grounded":directory += "grounded/"
	if gait != "walk": directory += gait + "/"
	var specification: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"review.json"))
	var duration := float(specification.duration_seconds)
	var stance_fraction := float(specification.stance_fraction)
	var samples := int((stance_fraction-.02)*duration*960)+1
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(directory+gait+"_contact_candidate.glb", state) == OK)
	var actor := document.generate_scene(state, 240.0) as Node3D
	add_child(actor)
	var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clips := player.get_animation_list()
	var clip := ""
	for name in clips:
		if name != "RESET": clip = name
	assert(not clip.is_empty())
	player.play(clip, 0)
	var native_speed := float(specification.stride_metres) / stance_fraction / duration
	var report := {"runtime_approved":false, "native_speed_px_s":native_speed*16.0, "stance":{}}
	var worst := 0.0
	for facing in 8:
		actor.rotation.y = facing*PI/4
		for reverse in [false,true]:
			for side in 2:
				var foot_name := "LeftFoot" if side == 0 else "RightFoot"
				var foot := skeleton.find_bone(foot_name)
				assert(foot >= 0)
				var start := Vector3.ZERO
				var drift := 0.0
				for frame in range(samples):
					var phase := frame/960.0
					if reverse: phase = (samples-1)/960.0-phase
					var time := phase + side*duration*0.5
					actor.position = actor.basis * Vector3(0,0,native_speed*time)
					player.seek(fposmod(time, duration), true)
					player.advance(0.000001)
					skeleton.force_update_all_bone_transforms()
					var contact := skeleton.global_transform * skeleton.get_bone_global_pose(foot).origin
					if frame == 0: start = contact
					drift = maxf(drift, contact.distance_to(start))
				worst = maxf(worst,drift)
				var label := "%s_%d_%s" % [foot_name,facing,"reverse" if reverse else "forward"]
				report.stance[label] = {"samples":samples,"drift_metres":drift,"crosses_loop_boundary":side==1 and stance_fraction>.5}
				assert(drift < 0.002, "Exported planted foot must remain stable at matched travel speed")
	print("STRIDE CONTACT ",cast_id," ",gait,": 32 directional stance sweeps; worst drift metres=",worst)
	report["cast"] = cast_id
	report["gait"] = gait
	if cast_id == "cass":
		report["controller"] = await _check_controller(actor,skeleton,player,specification,gait)
	var file := FileAccess.open(directory+"godot_contact_review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	if report.has("controller") and not bool(report.controller.get("passed",false)):
		get_tree().quit(1)
		return
	print("CASS STRIDE CONTACT REVIEW PASSED")
	Game.request_quit(0)

func _check_controller(actor: Node3D, skeleton: Skeleton3D, animation: AnimationPlayer, specification: Dictionary, gait: String) -> Dictionary:
	var controller := Player.new()
	add_child(controller)
	controller.setup(load("res://data/characters/cass.tres") as CharacterData)
	if specification.get("profile", "study") == "grounded":
		# Preview the proposed contact-matched stance pace on an isolated instance,
		# never by changing production CharacterData.  `_movement` applies the
		# global traversal scale and then the sneak multiplier.
		controller.data = controller.data.duplicate(true)
		var desired_speed := float(specification.get("native_speed_px_s", 20.0))
		var stance_multiplier := controller.data.sneak_mult if gait == "sneak" else (controller.data.sprint_mult if gait == "run" else 1.0)
		controller.data.move_speed = desired_speed / maxf(Player.TRAVERSAL_SPEED_SCALE * stance_multiplier, 0.001)
	controller.set_physics_process(false)
	controller.hide()
	controller.position = Vector2.ZERO
	actor.rotation = Vector3.ZERO
	var wall := StaticBody2D.new()
	wall.position = Vector2(0,60)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(80,4)
	shape.shape = rectangle
	wall.add_child(shape)
	add_child(wall)
	if gait == "run": Input.action_press("sprint")
	if gait == "sneak": Input.action_press("sneak")
	var distance := 0.0
	var phase := 0.0
	var contact_cache: Dictionary = {}
	var worst := 0.0
	var stopped_phase := -1.0
	var blocked := false
	var max_rate := 0.0
	var peak_speed := 0.0
	var worst_sample: Dictionary = {}
	var duration := float(specification.duration_seconds)
	var cycle_distance := float(specification.stride_metres)/float(specification.stance_fraction)
	var moving_frames := Engine.physics_ticks_per_second*5
	for frame in moving_frames+40:
		await get_tree().physics_frame
		var physics_delta := get_physics_process_delta_time()
		var before := controller.position
		controller._movement(Vector2.DOWN if frame < moving_frames else Vector2.ZERO,physics_delta)
		controller.move_and_slide()
		controller._travel_velocity = controller.get_real_velocity()
		var travelled := (controller.position-before).y/16.0
		distance += travelled
		phase = distance/cycle_distance
		max_rate = maxf(max_rate,absf(travelled)/physics_delta*duration/cycle_distance)
		peak_speed = maxf(peak_speed,absf(travelled)*16.0/physics_delta)
		actor.position = Vector3(controller.position.x/16.0,0,controller.position.y/16.0)
		animation.seek(fposmod(phase,1.0)*duration,true)
		animation.advance(0.000001)
		skeleton.force_update_all_bone_transforms()
		for side in 2:
			var cycle := fposmod(phase+side*.5,1.0)
			var foot := skeleton.find_bone("LeftFoot" if side==0 else "RightFoot")
			var contact := skeleton.global_transform*skeleton.get_bone_global_pose(foot).origin
			if cycle < float(specification.stance_fraction):
				if contact_cache.has(side) and absf(cycle-float(contact_cache[side].cycle))<.25:
					var error := contact.distance_to(contact_cache[side].contact)
					if error > worst:
						worst = error
						worst_sample = {"frame":frame,"side":side,"cycle":cycle,"previous_cycle":contact_cache[side].cycle}
				contact_cache[side] = {"cycle":cycle,"contact":contact}
			else: contact_cache.erase(side)
		if controller.get_slide_collision_count()>0: blocked = true
		if frame == moving_frames+30: stopped_phase = phase
	assert(controller.velocity.length()<0.001)
	assert(absf(phase-stopped_phase)<0.000001,"Stopped controller must freeze gait phase")
	print("CONTROLLER MEASUREMENT ",gait," contact=",worst," rate=",max_rate," distance=",distance," sample=",worst_sample)
	assert(distance>0.1)
	Input.action_release("sprint")
	Input.action_release("sneak")
	print("CONTROLLER PHASE ",gait,": contact error=",worst," peak playback rate=",max_rate," blocked=",blocked)
	controller.queue_free()
	wall.queue_free()
	return {"passed":worst<.003 and blocked,"contact_error_metres":worst,"peak_playback_rate":max_rate,"peak_steps_per_second":max_rate/duration*2.0,"peak_actual_speed_px_s":peak_speed,"wall_blocked":blocked,"stopped_phase_frozen":true,"distance_metres":distance,"runtime_approved":false,"speed_profile":specification.get("profile","study"),"configured_base_speed_px_s":controller.data.move_speed*Player.TRAVERSAL_SPEED_SCALE}
