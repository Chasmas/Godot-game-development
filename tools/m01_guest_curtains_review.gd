extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	var runtime_mode := OS.get_environment("M01_CURTAINS_RUNTIME") == "1"
	if not runtime_mode: Engine.set_meta("review_m01_guest_curtains", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_guest_curtains_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	Dialogue._end(false)
	Dialogue.set_process(false)
	level.player.input_enabled = false
	level.player.set_physics_process(false)
	for enemy in level.enemies: enemy.set_physics_process(false)
	var rooms: Array = Dressing._find_rooms(level.builder).filter(func(room): return room.kind == "guest_room")
	var rows: Array = []
	var first_window: GlassWindow = null
	for node in level.props_root.get_children():
		if not node is GlassWindow: continue
		var window := node as GlassWindow
		var dressing := window.get_node_or_null("NativeM01GuestCurtains") as Node2D
		if dressing == null: continue
		assert(bool(dressing.get_meta("guest_curtain_staging", false)) != runtime_mode)
		assert(window.size.x >= window.size.y and window.collision_layer == Layers.GLASS and not window.broken)
		assert(dressing.get_child_count() == 2)
		var room_side := float(dressing.get_meta("guest_curtain_room_side", 0.0))
		var target_room = null
		for distance in [8.0, 16.0, 24.0]:
			var p := window.global_position + Vector2(0, room_side * (window.size.y * .5 + distance))
			var cell := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
			for room in rooms:
				if room.cells.has(cell): target_room = room
			if target_room != null: break
		assert(target_room != null, "Curtain must face an authored guest room")
		var spill := 0
		for panel in dressing.get_children():
			assert(panel is Sprite2D)
			var sprite := panel as Sprite2D
			var image: Image = sprite.texture.get_image()
			var centre := Vector2(image.get_size()) * .5
			for y in image.get_height():
				for x in image.get_width():
					if image.get_pixel(x, y).a < .05: continue
					var local := Vector2(x + .5, y + .5) - centre
					if sprite.flip_h: local.x = -local.x
					if sprite.flip_v: local.y = -local.y
					var world := sprite.to_global(local)
					var cell := Vector2i(floori(world.x / 16.0), floori(world.y / 16.0))
					if not target_room.cells.has(cell): spill += 1
		if spill > 0:
			print("M01 CURTAIN ALPHA SPILL: window %s side %.0f has %d pixels outside room" % [window.global_position, room_side, spill])
		assert(spill == 0, "Curtain alpha must not cross the adjoining guest-room boundary")
		rows.append({"position": [window.global_position.x, window.global_position.y], "size_px": [window.size.x, window.size.y], "room_side": room_side, "alpha_pixels_outside_room": spill})
		if first_window == null: first_window = window
	assert(rows.size() > 0 and first_window != null)
	if DisplayServer.get_name().to_lower() != "headless":
		level.hud.hide()
		for child in level.get_children():
			if child is IntroCall or child is LevelIntro: child.hide()
		level.camera.set_process(false)
		level.camera.global_position = Vector2(176, 112)
		level.camera.zoom = Vector2(3.0, 3.0)
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_guest_curtains_runtime.png" if runtime_mode else "res://build/m01_guest_curtains_staging.png")
		level.camera.global_position = Vector2(112, 152)
		level.camera.zoom = Vector2(7.0, 7.0)
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_guest_curtains_runtime_close.png" if runtime_mode else "res://build/m01_guest_curtains_staging_close.png")
	first_window.shatter(Vector2.DOWN)
	assert(first_window.broken and first_window.collision_layer == Layers.LOW)
	assert(not (first_window.get_node("NativeM01GuestCurtains") as CanvasItem).visible, "Curtains must hide when the pane shatters")
	var report_data := {"passed": true, "runtime_approved": runtime_mode, "curtained_windows": rows, "shatter_hides_dressing": true, "scope": "M01 %s curtain review on existing breakable guest-room windows; visual dressing only." % ("runtime" if runtime_mode else "staging")}
	var report := FileAccess.open("user://m01_guest_curtains_review.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify(report_data, "  "))
	report.close()
	var workspace_report := FileAccess.open("res://build/m01_guest_curtains_%s_review.json" % ("runtime" if runtime_mode else "staging"), FileAccess.WRITE)
	assert(workspace_report != null)
	workspace_report.store_string(JSON.stringify(report_data, "  "))
	workspace_report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	Dialogue.set_process(true)
	print("M01 GUEST CURTAINS REVIEW: %d %s guest-room windows, contained dressing and shatter hide verified" % [rows.size(), "runtime" if runtime_mode else "staging"])
	Game.request_quit(0)
