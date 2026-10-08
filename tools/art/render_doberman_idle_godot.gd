extends SceneTree

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(args[0])
	var stage := SubViewport.new()
	stage.size = Vector2i(640, 480)
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	var preview := TextureRect.new()
	preview.texture = stage.get_texture()
	preview.size = Vector2(640, 480)
	root.add_child(preview)
	var walking := args.has("--walk")
	var model_path := "res://walk.glb" if walking else "res://idle_loop_candidate.tscn"
	if args.has("--native"):
		model_path = "res://native_walk.glb"
	var scene: Node3D
	if args.has("--native-idle") or args.has("--start-contact"):
		model_path = "res://native_start.glb" if args.has("--start-contact") else "res://native_idle.glb"
		for arg in args:
			if arg.begins_with("--model="):
				model_path = arg.trim_prefix("--model=")
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(model_path, state) != OK:
			quit(4)
			return
		scene = document.generate_scene(state)
	else:
		scene = load(model_path).instantiate()
	stage.add_child(scene)
	if args.has("--texture-mips"):
		for mesh in scene.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
				for field in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture"]:
					var texture: Texture2D = material.get(field)
					if texture == null:
						continue
					var pixels := texture.get_image()
					print("%s mipmaps before: %s" % [field, pixels.has_mipmaps()])
					if pixels.is_compressed():
						pixels.decompress()
					pixels.generate_mipmaps(field == "normal_texture")
					material.set(field, ImageTexture.create_from_image(pixels))
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				mesh.set_surface_override_material(surface, material)
	if args.has("--diagnose-normal-map") or args.has("--clay"):
		for mesh in scene.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
				material.normal_enabled = false
				if args.has("--clay"):
					material.albedo_texture = null
					material.albedo_color = Color(0.7, 0.7, 0.7)
					material.metallic_texture = null
					material.metallic = 0.0
					material.roughness_texture = null
					material.roughness = 0.8
				mesh.set_surface_override_material(surface, material)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.65
	stage.add_child(camera)
	camera.position = Vector3(-4.0 if args.has("--opposite") else 4.0, 0.44, 0.0)
	camera.look_at(Vector3(0.0, 0.44, 0.0))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.14, 0.16)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	environment.environment.ambient_light_energy = 0.5
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.5
	stage.add_child(light)
	if args.has("--studio"):
		environment.environment.ambient_light_sky_contribution = 0.0
		for setting in [[Vector3(15, 120, 0), 0.6], [Vector3(-35, 180, 0), 0.7]]:
			var fill := DirectionalLight3D.new()
			fill.rotation_degrees = setting[0]
			fill.light_energy = setting[1]
			stage.add_child(fill)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clip: StringName = player.get_animation_list()[0]
	for arg in args:
		if arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
	if not player.has_animation(clip):
		push_error("Missing requested clip: " + String(clip))
		quit(5)
		return
	player.play(clip)
	var count := 13 if args.has("--start-contact") else (30 if walking else 24)
	if args.has("--start-contact"):
		count = int(round(player.get_animation(clip).length * 30.0)) + 1
	var step := 1.0 / 30.0 if walking or args.has("--start-contact") else 0.1
	for index in count:
		player.seek(float(index) * step, true)
		player.advance(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var result := stage.get_texture().get_image().save_png(args[0].path_join(("walk_" if walking else "idle_")+"%03d.png" % index))
		if result != OK:
			quit(3)
			return
	print("%d Godot %s frames rendered" % [count, "walk" if walking else "idle"])
	var audit := {"runtime_approved": false, "source_path": model_path,
		"clip": clip,
		"source_sha256": FileAccess.get_sha256(model_path), "captured_frames": count,
		"camera": "negative_x_side" if args.has("--opposite") else "positive_x_side",
		"scope": "GPU render capture only; visual review and gameplay validation separate"}
	FileAccess.open(args[0].path_join("render_audit.json"), FileAccess.WRITE).store_string(JSON.stringify(audit, "  "))
	quit(0)
