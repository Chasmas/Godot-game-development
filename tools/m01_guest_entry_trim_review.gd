extends Node

## Live M01 verification for the art-only guest-door threshold treatment.
## Door leaf collision and the original Door node must remain untouched.

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_guest_entry_trim_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	var rows: Array = []
	for node in level.doors_root.get_children():
		if not node is Door: continue
		var door := node as Door
		var trim := door.get_node_or_null("NativeM01GuestEntryTrim")
		if trim == null: continue
		assert(trim is Node2D and not trim is CollisionObject2D)
		assert(bool(trim.get_meta("native_guest_entry_trim", false)))
		assert(door.leaf != null and door.leaf.collision_layer == Layers.DOOR)
		var original := door.swing
		for degrees in [0.0, 45.0, 85.0]:
			door.swing = deg_to_rad(degrees)
			door._apply()
			assert(is_equal_approx(door.leaf.rotation, door.closed_angle + door.swing))
		assert(is_equal_approx(trim.global_rotation, door.global_rotation), "Trim must stay fixed while leaf swings")
		door.swing = original
		door._apply()
		rows.append({"position": [door.position.x, door.position.y], "length_px": door.length, "guest_room_side": trim.get_meta("guest_room_side", 0.0)})
	assert(rows.size() == 19, "Expected nineteen guest-room entry transitions at existing M01 door anchors")
	if DisplayServer.get_name().to_lower() != "headless":
		level.hud.hide()
		for child in level.get_children():
			if child is IntroCall or child is LevelIntro: child.hide()
		level.camera.set_process(false)
		level.camera.global_position = Vector2(240, 96)
		level.camera.zoom = Vector2(3.0, 3.0)
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_guest_entry_trim_runtime.png")
	var report := FileAccess.open("res://build/m01_guest_entry_trim_review.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed": true, "runtime_approved": true, "entry_transitions": rows,
		"scope": "Live M01 guest-door sill and jamb visuals; each mounts on an existing Door and adds no collision or navigation footprint."}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	print("M01 GUEST ENTRY TRIM REVIEW: %d fixed visual thresholds preserve Door collision and swing" % rows.size())
	Game.request_quit(0)
