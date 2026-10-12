extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_reception_capture_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	level.hud.hide()
	for child in level.get_children():
		if child is IntroCall or child is LevelIntro: child.hide()
	level.camera.target = null
	level.camera.set_process(false)
	level.camera.global_position = Vector2(968, 480)
	level.camera.zoom = Vector2(2.4, 2.4)
	for frame in 8: await get_tree().process_frame
	var counter_count := 0
	var native_count := 0
	var collision_count := 0
	var counter_layers: Array = []
	for node in level.get_tree().get_nodes_in_group("furniture"):
		if not node is Furniture or not level.is_ancestor_of(node): continue
		var counter := node as Furniture
		var p := counter.global_position
		if counter.kind != "counter" or p.x < 880.0 or p.x > 1000.0 or p.y < 440.0 or p.y > 500.0: continue
		counter_count += 1
		var visual := counter.get_node_or_null("NativeM01ReceptionCounter") as Sprite2D
		if visual != null and visual.texture != null and visual.visible and visual.find_children("*", "CollisionObject2D", true, false).is_empty(): native_count += 1
		var has_collision_shape := false
		for child in counter.get_children():
			if child is CollisionShape2D: has_collision_shape = true
		counter_layers.append({"layer": counter.collision_layer, "has_collision_shape": has_collision_shape})
		if has_collision_shape and counter.collision_layer == Layers.LOW: collision_count += 1
	assert(counter_count == 2, "M01 reception desk footprint changed; expected two L-counter bodies")
	assert(native_count == counter_count, "Native reception visual did not cover every lobby counter body")
	assert(collision_count == counter_count, "Reception counter collision must remain on its original LOW bodies")
	var proof: Dictionary = Engine.get_meta("m01_reception_counter_review", {})
	assert(bool(proof.get("imagegen_blender", false)), "Reception must load the ImageGen-to-Blender visual")
	var wall_details := level.get_node_or_null("Decor/NativeM01ReceptionWallDetails") as Sprite2D
	var wall_details_present := wall_details != null and wall_details.texture != null and bool(wall_details.get_meta("native_m01_reception_wall_details", false))
	assert(wall_details_present, "M01 reception key/mail wall details must use the approved Blender visual")
	if DisplayServer.get_name().to_lower() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_reception_runtime_capture.png")
	var report := FileAccess.open("user://m01_reception_runtime_capture.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed": true, "camera_world_position": [968,480], "camera_zoom": 2.4, "scope": "Live M01 reception counter/lobby camera; no staging layer loaded.", "counter_bodies": counter_count, "native_visuals": native_count, "preserved_low_collision_bodies": collision_count, "counter_layers": counter_layers, "reception_wall_details_present": wall_details_present}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	print("M01 RECEPTION RUNTIME CAPTURE DONE")
	Game.request_quit(0)
