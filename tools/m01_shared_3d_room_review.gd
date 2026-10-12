extends Node3D

func _ready() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file("res://assets/art/prerendered/m01_sunset_palms/staging/guest_room_shared_3d_v1/room.glb", state) == OK)
	var room := document.generate_scene(state)
	add_child(room)
	var cameras := room.find_children("*", "Camera3D", true, false)
	assert(cameras.size() == 1)
	var camera := cameras[0] as Camera3D
	camera.current = true
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.025, 0.025, 0.04)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.65, 0.73, 1.0)
	world.environment.ambient_light_energy = 0.45
	add_child(world)
	for light in room.find_children("*", "Light3D", true, false):
		# Blender watt-to-candela export is not Godot's compatibility intensity.
		light.light_energy = 0.65
		light.shadow_enabled = true
		if light is OmniLight3D: light.omni_range = 2.5
	var bounce := DirectionalLight3D.new()
	bounce.light_color = Color(1.0, 0.78, 0.60)
	bounce.light_energy = 0.45
	bounce.rotation_degrees = Vector3(-55, -25, 0)
	add_child(bounce)
	var window_fill := OmniLight3D.new()
	window_fill.position = Vector3(-2.55, 1.4, -0.5)
	window_fill.light_color = Color(0.20, 0.50, 1.0)
	window_fill.light_energy = 0.5
	window_fill.omni_range = 3.0
	add_child(window_fill)
	var actor := (load("res://assets/art/cast3d_rt/cass/cass.glb") as PackedScene).instantiate() as Node3D
	add_child(actor)
	var animations := actor.find_children("*", "AnimationPlayer", true, false)
	assert(not animations.is_empty())
	var player := animations[0] as AnimationPlayer
	player.play("idle")
	for test in [{"label":"aisle", "position":Vector3(0.9, 0, 0.65)},
		{"label":"behind_bed", "position":Vector3(-0.6, 0, -2.15)},
		{"label":"front_bed", "position":Vector3(-0.6, 0, -0.05)}]:
		actor.position = test.position
		for frame in 20: await get_tree().process_frame
		var floor := camera.unproject_position(actor.position)
		var ray_start := camera.project_ray_origin(floor)
		var ray_direction := camera.project_ray_normal(floor)
		assert(absf(ray_direction.y) > 0.01)
		var ground_intersection := ray_start + ray_direction * (-ray_start.y / ray_direction.y)
		assert(ground_intersection.distance_to(actor.position) < 0.001)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_shared_3d_%s.png" % test.label)
	# Trial footprint only: validate the visual/2D bridge before production fit.
	var projection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/prerendered/m01_sunset_palms/staging/guest_room_gameplay_layers_v2/projection.json"))
	var bed_bounds: Array = []
	for piece in projection.pieces:
		if piece.name == "motel_bed placement": bed_bounds = piece.visual_bounds_metres
	assert(bed_bounds.size() == 2)
	var low := Vector2(bed_bounds[0][0], -bed_bounds[1][1]) * 16.0
	var high := Vector2(bed_bounds[1][0], -bed_bounds[0][1]) * 16.0
	var bed_body := StaticBody2D.new()
	bed_body.position = (low + high) * 0.5
	var bed_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = high - low
	bed_shape.shape = rectangle
	bed_body.add_child(bed_shape)
	add_child(bed_body)
	var furniture_bodies: Dictionary = {}
	for piece in projection.pieces:
		if not (str(piece.name).begins_with("nightstand placement") or str(piece.name).begins_with("tv_dresser placement") or str(piece.name).begins_with("armchair_runtime_review placement")): continue
		var bounds: Array = piece.visual_bounds_metres
		var lower := Vector2(bounds[0][0], -bounds[1][1]) * 16.0
		var upper := Vector2(bounds[1][0], -bounds[0][1]) * 16.0
		var obstacle := StaticBody2D.new()
		obstacle.position = (lower + upper) * 0.5
		var shape := CollisionShape2D.new()
		var footprint := RectangleShape2D.new()
		footprint.size = upper-lower
		shape.shape = footprint
		obstacle.add_child(shape)
		add_child(obstacle)
		furniture_bodies[piece.name] = obstacle
	assert(furniture_bodies.size() == 4)
	var body := Player.new()
	add_child(body)
	body.setup(load("res://data/characters/cass.tres") as CharacterData)
	body.set_physics_process(false)
	body.hide()
	body.position = Vector2(0.9, 0.65) * 16.0
	await get_tree().physics_frame
	for step in 30:
		await get_tree().physics_frame
		assert(body.move_and_collide(Vector2(0,-1)) == null, "Aisle must remain clear")
	var collision := body.move_and_collide(Vector2(-30,0))
	assert(collision != null and collision.get_collider() == bed_body, "Bed must block the trial 2D body")
	assert(body.position.x >= high.x + Player.RADIUS - 0.02)
	var bed_contact := body.position
	body.position = Vector2(0.9, -1.225) * 16.0
	var cabinet_contact := body.move_and_collide(Vector2(0,-32))
	assert(cabinet_contact != null and cabinet_contact.get_collider() == furniture_bodies["nightstand placement.001"], "Bedside cabinet must block northward travel")
	body.position = Vector2(-0.6, 1.3) * 16.0
	var dresser_contact := body.move_and_collide(Vector2(0,32))
	assert(dresser_contact != null and dresser_contact.get_collider() == furniture_bodies["tv_dresser placement"], "Dresser must block entry-side travel")
	body.position = bed_contact
	var saved_contact := body.position
	body.position = Vector2(-0.3, 0.6) * 16.0
	body.velocity = Vector2.ZERO
	body.input_enabled = false
	var movement_start := body.position
	for step in 10:
		await get_tree().physics_frame
		body._movement(Vector2.RIGHT, 1.0/60.0)
		body.move_and_slide()
	assert(body.position.x > movement_start.x + 1.0, "Real player controller must travel")
	for step in 20:
		await get_tree().physics_frame
		body._movement(Vector2.ZERO, 1.0/60.0)
		body.move_and_slide()
	assert(body.velocity.length() < 0.01, "Real controller must brake to rest")
	body.position = saved_contact
	actor.position = Vector3(body.position.x/16.0, 0, body.position.y/16.0)
	for direction in 8:
		var target := actor.position + Vector3(cos(direction*PI/4),0,sin(direction*PI/4))
		var cursor := camera.unproject_position(target)
		var start := camera.project_ray_origin(cursor)
		var ray := camera.project_ray_normal(cursor)
		assert((start + ray * (-start.y/ray.y)).distance_to(target) < 0.001)
	for frame in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_shared_3d_collision.png")
	var camera_origin := camera.global_position
	var camera_basis := camera.global_basis
	var pivot := Vector3(0, 0.15, -0.15)
	var angle_results: Array = []
	for yaw in [0.0, 20.0]:
		camera.global_position = pivot + Basis(Vector3.UP, deg_to_rad(yaw)) * (camera_origin-pivot)
		if yaw == 0.0: camera.global_basis = camera_basis
		else: camera.look_at(pivot, Vector3.UP)
		var minimum_alignment := 1.0
		for direction in 8:
			var desired := Vector2(cos(direction*PI/4), sin(direction*PI/4))
			var origin_screen := camera.unproject_position(actor.position)
			var cursor := origin_screen + desired * 50.0
			var start := camera.project_ray_origin(cursor)
			var ray := camera.project_ray_normal(cursor)
			var intersection := start + ray * (-start.y/ray.y)
			var ground_direction := (intersection-actor.position).normalized()
			var projected := (camera.unproject_position(actor.position+ground_direction)-origin_screen).normalized()
			minimum_alignment = minf(minimum_alignment, projected.dot(desired))
		assert(minimum_alignment > 0.999, "Screen-relative ground directions must remain aligned")
		for frame in 10: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := "res://build/m01_shared_3d_yaw_%d.png" % int(yaw)
		get_viewport().get_texture().get_image().save_png(capture)
		angle_results.append({"yaw_degrees":yaw, "minimum_screen_direction_alignment":minimum_alignment, "capture":capture})
	var report := FileAccess.open("res://build/m01_shared_3d_camera_review.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_promoted":false, "screen_direction_checks_per_angle":8, "angles":angle_results}, "\t"))
	# Separate scene/material quality from the global VHS overlay during review.
	PostFX.rect.hide()
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_shared_3d_clean_baseline.png")
	var filtered_materials := 0
	var material_inventory: Dictionary = {}
	for mesh in room.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source_material = mesh.get_active_material(surface)
			if source_material is StandardMaterial3D:
				if source_material.resource_name in ["ImageGen motel carpet", "Shared ImageGen motel bedspread"] and source_material.albedo_texture:
					source_material.albedo_texture.get_image().save_png("res://build/imported_%s.png" % source_material.resource_name.to_snake_case().replace(" ", "_"))
				material_inventory[source_material.resource_name] = {"transparency":source_material.transparency, "alpha":source_material.albedo_color.a, "filter":source_material.texture_filter, "roughness":source_material.roughness, "texture":source_material.albedo_texture.resource_path if source_material.albedo_texture else ""}
				filtered_materials += 1
	var preparation: Dictionary = preload("res://scripts/player/cast_gltf_materials.gd").prepare(room, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	assert(preparation.prepared_surfaces == filtered_materials and preparation.generated_mipmaps > 0)
	var entry_fill := OmniLight3D.new()
	entry_fill.position = Vector3(0, 2.1, 1.65)
	entry_fill.light_color = Color(0.75, 0.82, 1.0)
	entry_fill.light_energy = 0.32
	entry_fill.omni_range = 3.3
	add_child(entry_fill)
	for frame in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_shared_3d_material_review.png")
	var material_report := FileAccess.open("res://build/m01_shared_3d_material_review.json", FileAccess.WRITE)
	material_report.store_string(JSON.stringify({"runtime_promoted":false, "filtered_surfaces":filtered_materials, "filter":"linear_mipmap_anisotropic", "entry_fill_energy":0.32, "postfx_disabled_for_review":true, "materials":material_inventory, "preparation":preparation}, "\t"))
	var visibility_samples: Array = []
	for sample in [
		{"label":"entry", "position":Vector3(0.9,0,1.7)},
		{"label":"bed_foot", "position":Vector3(0.9,0,0.1)},
		{"label":"bedside", "position":Vector3(0.9,0,-1.1)},
		{"label":"bed_overlap_occlusion_only", "position":Vector3(-0.6,0,-2.15)},
		{"label":"bathroom", "position":Vector3(2.1,0,-1.4)}]:
		actor.position = sample.position
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := "res://build/m01_visibility_%s.png" % sample.label
		get_viewport().get_texture().get_image().save_png(capture)
		visibility_samples.append({"label":sample.label, "position":[actor.position.x,actor.position.y,actor.position.z], "capture":capture})
	var visibility_report := FileAccess.open("res://build/m01_room_visibility_review.json", FileAccess.WRITE)
	visibility_report.store_string(JSON.stringify({"runtime_promoted":false, "scope":"Static occlusion samples, no locomotion or navigability approval", "yaw_degrees":20, "samples":visibility_samples}, "\t"))
	actor.position = Vector3(0.9,0,-1.1)
	var occlusion = preload("res://scripts/systems/visual_occlusion_fade.gd").new()
	occlusion.setup(room)
	var occluder_names: Array = occlusion.update(camera,actor.global_position,1.0/60.0)
	assert(occluder_names.has("Stationary walnut jamb"))
	var jamb: MeshInstance3D
	for mesh in occlusion._meshes:
		if str(mesh.name) == "Stationary walnut jamb": jamb = mesh
	assert(jamb != null)
	assert(float(occlusion._amounts[jamb]) > 0.0 and float(occlusion._amounts[jamb]) < 1.0, "Fade must start gradually")
	for step in 6: occlusion.update(camera,actor.global_position,1.0/60.0)
	assert(is_equal_approx(float(occlusion._amounts[jamb]),1.0))
	var occluder_report := FileAccess.open("res://build/m01_room_occluders.json", FileAccess.WRITE)
	occluder_report.store_string(JSON.stringify({"runtime_promoted":false, "method":"local AABB broadphase followed by mesh triangle intersections", "occluders":occluder_names}, "\t"))
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_visibility_partition_fade.png")
	actor.position = Vector3(0.9,0,1.7)
	var entry_occluders: Array = occlusion.update(camera,actor.global_position,1.0/60.0)
	assert(not entry_occluders.has("Stationary walnut jamb"), "Jamb must restore at entry")
	body.position = Vector2(0.9,1.7)*16.0
	var traversal_samples: Array = []
	var jamb_frames := 0
	for step in 45:
		await get_tree().physics_frame
		assert(body.move_and_collide(Vector2(0,-1)) == null, "Actual-radius aisle traversal must stay clear")
		actor.position = Vector3(body.position.x/16.0,0,body.position.y/16.0)
		var blockers: Array = occlusion.update(camera,actor.global_position,1.0/60.0)
		if blockers.has("Stationary walnut jamb"): jamb_frames += 1
		traversal_samples.append({"step":step,"position":[actor.position.x,actor.position.z],"occluders":blockers})
	assert(jamb_frames > 0 and jamb_frames < 45, "Traversal must enter and leave different visibility states")
	var traversal_report := FileAccess.open("res://build/m01_room_occlusion_traversal.json",FileAccess.WRITE)
	traversal_report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Real Player collision body moved one pixel per physics frame; not gait/input validation","jamb_frames":jamb_frames,"samples":traversal_samples},"\t"))
	actor.position = Vector3(0.9,0,1.7)
	for step in 12: occlusion.update(camera,actor.global_position,1.0/60.0)
	assert(is_zero_approx(float(occlusion._amounts[jamb])), "Fade must return to opaque without forced restore")
	for surface in jamb.mesh.get_surface_count():
		assert(jamb.get_surface_override_material(surface) == occlusion._originals[jamb][surface])
	occlusion.restore()
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_visibility_restored.png")
	print("M01 SHARED 3D REVIEW: real Cass movement/braking; furnished aisle; bed/cabinet/dresser trial collisions; eight aim directions passed")
	Game.request_quit(0)
