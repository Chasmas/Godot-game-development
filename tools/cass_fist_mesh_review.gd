extends Node

func _ready() -> void:
	var source := "res://build/cass_fist_review/volume_candidate_v4/fist_review.glb"
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(source, state) != OK:
		push_error("Cannot load fist review GLB")
		Game.request_quit(1)
		return
	var model := document.generate_scene(state)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 600)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(model)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("25252a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.35
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.light_energy = 0.9
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.17
	camera.near = 0.001
	viewport.add_child(camera)
	var failures := 0
	var surfaces := 0
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		surfaces += mesh.mesh.get_surface_count()
		var bounds: AABB = mesh.get_aabb()
		if not bounds.size.is_finite() or bounds.size.length() > 0.30 or bounds.size.length() < 0.03:
			failures += 1
	if surfaces == 0:
		failures += 1
	var out := "res://build/cass_fist_review/volume_candidate_v4/godot"
	DirAccess.make_dir_recursive_absolute(out)
	# Blender Z-up converts through glTF to Godot Y-up: (x, z, -y).
	var target := Vector3(0, -0.01, -0.05)
	var views := {"palm": Vector3(0.19, -0.22, -0.20), "dorsal": Vector3(0.16, 0.25, -0.16), "profile": Vector3(-0.26, -0.10, -0.09)}
	for name in views:
		camera.look_at_from_position(views[name], target)
		light.look_at_from_position(views[name] * 1.3, target)
		for frame in 3:
			await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if viewport.get_texture().get_image().save_png(out + "/" + name + ".png") != OK:
				failures += 1
	var file := FileAccess.open(out + "/review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"source": source, "sha256": FileAccess.get_sha256(source), "surfaces": surfaces, "failures": failures, "runtime_promoted": false, "visual_approved": false, "scope": "GLTF load, mesh scale and isolated GPU views; no rig or gameplay integration"}, "\t"))
	print("FIST MESH GODOT REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
