extends Node

func _ready() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := "res://assets/art/prerendered/m01_sunset_palms/staging/window_v1/window_review.glb"
	assert(document.append_from_file(ProjectSettings.globalize_path(path), state) == OK)
	var model := document.generate_scene(state)
	assert(model != null)
	add_child(model)
	# Compatibility rendering needs explicit alpha for thin glass;
	# glTF transmission alone looked opaque in the inspected viewport.
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.get_active_material(surface)
			if original != null and "Separate glass" in original.resource_name:
				var glass := StandardMaterial3D.new()
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.albedo_color = Color(.18, .26, .3, .22)
				glass.roughness = .1
				mesh_instance.set_surface_override_material(surface, glass)
	var curtains: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if node.get_blend_shape_count() > 0:
			curtains.append(node)
	assert(curtains.size() == 2)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert(players.size() == 1)
	var player := players[0] as AnimationPlayer
	var animations := player.get_animation_list()
	var tested := 0
	for animation_name in animations:
		if animation_name == "RESET":
			continue
		player.play(animation_name)
		player.seek(0, true)
		var before: Array[float] = []
		for curtain in curtains:
			before.append(curtain.get_blend_shape_value(0))
		player.seek(player.get_animation(animation_name).length * .5, true)
		for index in curtains.size():
			if absf(curtains[index].get_blend_shape_value(0) - before[index]) > .5:
				tested += 1
	assert(tested >= 2)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	camera.position = Vector3(3, 2.6, 5)
	add_child(camera)
	camera.look_at(Vector3(0, 1.1, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.0
	add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(.035, .045, .055)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.65, .7, .75)
	world.environment.ambient_light_energy = .25
	add_child(world)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture := get_viewport().get_texture().get_image()
	assert(capture.save_png(ProjectSettings.globalize_path("res://build/m01_window_godot_review.png")) == OK)
	print("M01_WINDOW_ANIMATION: GLB imported; 2 curtain morphs respond to AnimationPlayer; preview only")
	get_tree().quit()
