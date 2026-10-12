extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_service_capture_save.json"
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
	level.camera.global_position = Vector2(128, 472)
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
		if counter.has_node("NativeM01ReceptionCounter"): native_count += 1
		var has_collision_shape := false
		for child in counter.get_children():
			if child is CollisionShape2D: has_collision_shape = true
		counter_layers.append({"layer": counter.collision_layer, "has_collision_shape": has_collision_shape})
		if has_collision_shape and counter.collision_layer == Layers.LOW: collision_count += 1
	assert(counter_count == 2, "M01 reception desk footprint changed; expected two L-counter bodies")
	assert(native_count == counter_count, "Native reception visual did not cover every lobby counter body")
	assert(collision_count == counter_count, "Reception counter collision must remain on its original LOW bodies")
	var washer_count := 0
	var native_washer_count := 0
	var washer_collision_count := 0
	for node in level.get_tree().get_nodes_in_group("furniture"):
		if not node is Furniture or not level.is_ancestor_of(node): continue
		var washer := node as Furniture
		var washer_pos := washer.global_position
		if washer.kind != "washer" or washer_pos.x < 72.0 or washer_pos.x > 120.0 or washer_pos.y < 440.0 or washer_pos.y > 504.0: continue
		washer_count += 1
		if washer.has_node("NativeM01LaundryWasher"): native_washer_count += 1
		var has_washer_collision := false
		for child in washer.get_children():
			if child is CollisionShape2D: has_washer_collision = true
		if has_washer_collision and washer.collision_layer == Layers.LOW: washer_collision_count += 1
	assert(washer_count == 2, "M01 laundry footprint changed; expected two washer banks")
	assert(native_washer_count == washer_count, "Native laundry visual did not cover every washer bank")
	assert(washer_collision_count == washer_count, "Laundry washers must retain their original LOW collision bodies")
	if DisplayServer.get_name().to_lower() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_service_runtime_capture.png")
	var report := FileAccess.open("user://m01_service_runtime_capture.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed": true, "camera_world_position": [128,472], "camera_zoom": 2.4, "scope": "Live M01 service/laundry camera; no staging layer loaded.", "counter_bodies": counter_count, "native_counter_visuals": native_count, "preserved_counter_collision_bodies": collision_count, "counter_layers": counter_layers, "washer_bodies": washer_count, "native_washer_visuals": native_washer_count, "preserved_washer_collision_bodies": washer_collision_count}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	print("M01 SERVICE RUNTIME CAPTURE DONE")
	Game.request_quit(0)

