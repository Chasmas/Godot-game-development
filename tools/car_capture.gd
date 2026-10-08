extends Node
## Review shots of the hero car arrival: the drive in, her climbing out, the
## door. Saves a frame every CAR_STEP seconds (default 0.25) into CAR_OUT_DIR.
## CAR_DEPART=1 instead films the getaway (she walks to the car and drives off).
##   CAR_OUT_DIR=C:/tmp_shots/car godot --path . res://tools/car_capture.tscn --display-driver windows --audio-driver Dummy

func _ready() -> void:
	Engine.set_meta("autoplay", true)
	Game.force_intro_calls = false
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	var staged_source := OS.get_environment("CAR_EXIT_REVIEW_MODEL")
	if staged_source != "":
		var staged_doc := GLTFDocument.new()
		var staged_state := GLTFState.new()
		assert(staged_doc.append_from_file(staged_source,staged_state) == OK)
		var staged_body := staged_doc.generate_scene(staged_state)
		var staged_scene := PackedScene.new()
		assert(staged_scene.pack(staged_body) == OK)
		staged_scene.take_over_path(CastModel.RT_PATH % ["cass","cass"])
		staged_body.free()
	Game.start_mission("m01_checkout")
	var out := OS.get_environment("CAR_OUT_DIR")
	if out == "":
		out = "C:/tmp_shots/car"
	DirAccess.make_dir_recursive_absolute(out)
	var step := float(OS.get_environment("CAR_STEP")) if OS.get_environment("CAR_STEP") != "" else 0.25
	var level: Level = null
	while level == null:
		await get_tree().process_frame
		level = get_tree().get_first_node_in_group("level") as Level
	var candidate := OS.get_environment("CAR_EXIT_REVIEW_MODEL")
	if candidate != "":
		var car_model: CarModel = level.hero_car._car3d
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(candidate,state) == OK)
		car_model.driver.free()
		car_model.driver = doc.generate_scene(state)
		car_model.car.add_child(car_model.driver)
		car_model._driver_anim = car_model.driver.find_children("*","AnimationPlayer",true,false)[0]
	var depart := OS.get_environment("CAR_DEPART") == "1"
	if depart:
		# let the arrival finish, then send her back to the car
		for i in 600:
			if Dialogue.active: Dialogue._end()
			await get_tree().physics_frame
		var p := get_tree().get_first_node_in_group("player") as Player
		p.global_position = level.hero_car.global_position + Vector2(0, 70)
		level.hero_car.depart(p)
	var shots := 0
	var t := 0.0
	while shots < int(7.0 / step):
		if Dialogue.active: Dialogue._end()
		await get_tree().process_frame
		t += get_process_delta_time()
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl and pl.visual.cast_sprite and OS.get_environment("CAR_LOG") == "1":
			var cs := pl.visual.cast_sprite
			var ap: AnimationPlayer = cs.get("_player") if cs is CastModel else null
			print("t=%.2f vis=%s clip=%s ap=%s pos=%.2f alpha=%.1f vmod=%.1f rig=%.2f roll=%.2f" % [shots * step + t, pl.visible, cs.clip,
				ap.current_animation if ap else "-", ap.current_animation_position if ap and ap.current_animation != "" else -1.0,
				cs.self_modulate.a, pl.visual.modulate.a, pl.visual.rig.rotation, pl.visual._roll_t])
		if t >= step:
			t = 0.0
			await RenderingServer.frame_post_draw
			var shot := get_viewport().get_texture().get_image()
			shot.save_png("%s/f%03d.png" % [out, shots])
			# the car itself, 2x: the camera leads ahead of it while driving
			if is_instance_valid(level.hero_car):
				var vs := Vector2(shot.get_size())
				var at := level.hero_car.get_global_transform_with_canvas().origin * vs / get_viewport().get_visible_rect().size
				var half := Vector2(240, 160)
				var rect := Rect2i(Vector2i((at - half).clamp(Vector2.ZERO, vs - half * 2.0)), Vector2i(half * 2.0))
				var crop := shot.get_region(rect)
				crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
				crop.save_png("%s/car%03d.png" % [out, shots])
			shots += 1
	print("car capture: ", shots, " frames")
	get_tree().quit()
