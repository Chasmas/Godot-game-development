extends Node

## Isolated live-camera review for the generated M01 guest-room prop family.
## It never promotes staging assets; normal M01 uses no assets from this
## directory until its runtime contract is explicitly created.

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	var runtime_mode := OS.get_environment("M01_ACCENTS_RUNTIME") == "1"
	if not runtime_mode: Engine.set_meta("review_m01_room_accents", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_guest_room_accents_review_save.json"
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
	var rooms: Array = Dressing._find_rooms(level.builder)
	var guest_rooms: Array = []
	for room in rooms:
		if room.kind == "guest_room": guest_rooms.append(room)
	var rows: Array = []
	for child in level.get_children():
		var prefix := "NativeGuestRoomAccent_" if runtime_mode else "CandidateGuestRoomAccent_"
		if not child is Sprite2D or not str(child.name).begins_with(prefix): continue
		assert(bool(child.get_meta("staging_accent", false)) != runtime_mode, "Review mode must use the matching accent family")
		assert(child.texture != null and child.visible and child.scale.x > 0.0)
		var room = null
		var anchor_cell := Vector2i(floori(child.position.x / 16.0), floori(child.position.y / 16.0))
		for candidate in guest_rooms:
			if candidate.cells.has(anchor_cell):
				room = candidate
				break
		assert(room != null, "Guest-room accent anchor must remain in a guest room")
		var spill := 0
		var pixels := 0
		var image: Image = child.texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a < .05: continue
				pixels += 1
				var projected: Vector2 = child.position + ((Vector2(x + .5, y + .5) - Vector2(image.get_size()) * .5) * child.scale).rotated(child.rotation)
				var cell := Vector2i(floori(projected.x / 16.0), floori(projected.y / 16.0))
				if not room.cells.has(cell): spill += 1
		if spill > 0:
			print("M01 ACCENT ALPHA SPILL: %s at %s has %d pixels outside room" % [child.name, child.position, spill])
		assert(pixels > 0 and spill == 0, "Accent alpha must not cross its anchored guest-room boundary")
		rows.append({"kind": child.get_meta("accent_kind", ""), "source_kind": child.get_meta("source_dressing_kind", ""), "position": [child.position.x, child.position.y], "visible_pixels": pixels, "alpha_pixels_outside_room": spill})
	assert(not rows.is_empty(), "Guest-room accent family must replace at least one authored dressing entry")
	var botanicals: Array = []
	var wall_art := level.get_node_or_null("Decor/WallArt") as WallArt
	assert(wall_art != null)
	for item in wall_art.items:
		if str(item.kind) == "m01_botanical":
			var p: Vector2 = item.pos
			botanicals.append([p.x, p.y])
	assert(botanicals.size() == 10, "Every M01 guest room needs its botanical wall lithograph")
	var bedside_lamps: Array = []
	for node in level.get_node("Decor").get_children():
		if not node is Sprite2D: continue
		var anchor := node as Sprite2D
		if str(anchor.get_meta("decor_asset_id", "")) != "motel_bedside_lamp": continue
		var lamp := anchor.get_node_or_null("NativeM01BedsideLamp") as Sprite2D
		assert(lamp != null and lamp.texture != null and lamp.visible, "Every authored bedside lamp needs its native visual")
		assert(lamp.find_children("*", "CollisionObject2D", true, false).is_empty(), "Native bedside lamp must remain visual-only")
		assert(is_zero_approx(anchor.self_modulate.a), "Native bedside lamp must hide only the former source sprite")
		bedside_lamps.append([anchor.global_position.x, anchor.global_position.y])
	assert(bedside_lamps.size() == 8, "M01 guest-room bedside lamp anchors changed; expected eight")
	var guest_acs: Array = []
	for child in level.get_children():
		if child is Node2D and str(child.name).begins_with("NativeM01GuestAC_"):
			assert(bool(child.get_meta("native_guest_ac", false)), "Guest AC must be the explicit native visual")
			assert(not child is CollisionObject2D, "Guest AC upgrade must not add a collision body")
			guest_acs.append([child.position.x, child.position.y])
	assert(guest_acs.size() == 8, "M01 guest-room AC fixture anchors changed; expected eight authored wall slots")
	var door_plates: Array = []
	for child in level.get_children():
		if child is Node2D and str(child.name).begins_with("NativeM01GuestDoorPlate_"):
			assert(bool(child.get_meta("native_guest_door_plate", false)), "Guest door plaque must be the explicit native visual")
			assert(not child is CollisionObject2D, "Guest door plaque must not add collision")
			door_plates.append({"position": [child.position.x, child.position.y], "room_number": child.get_meta("room_number", 0)})
	assert(door_plates.size() == 3, "M01 guest-room entry plaque anchors changed; expected three corridor-side wall slots")
	var entry_trims: Array = []
	for node in level.doors_root.get_children():
		if not node is Door: continue
		var door := node as Door
		var trim := door.get_node_or_null("NativeM01GuestEntryTrim")
		if trim == null: continue
		assert(trim is Node2D and not trim is CollisionObject2D, "Guest entry trim must remain visual-only")
		assert(bool(trim.get_meta("native_guest_entry_trim", false)), "Guest entry trim must use the explicit native visual")
		assert(door.leaf != null and door.leaf.collision_layer == Layers.DOOR, "Guest entry trim must preserve the existing door collision leaf")
		entry_trims.append({"position": [door.position.x, door.position.y], "length_px": door.length, "guest_room_side": trim.get_meta("guest_room_side", 0.0)})
	assert(entry_trims.size() == 19, "M01 guest-room entry trim anchors changed; expected nineteen existing door transitions")
	for layer in level.get_children():
		if layer is Dressing.ClutterLayer:
			for item in layer.items:
				if not str(item[0]) in ["suitcase", "shoes", "tray"]: continue
				var cell := Vector2i(floori((item[1] as Vector2).x / 16.0), floori((item[1] as Vector2).y / 16.0))
				assert(not guest_rooms.any(func(room): return room.cells.has(cell)), "Equivalent legacy guest-room accent must be removed before floor baking")
	if DisplayServer.get_name().to_lower() != "headless":
		level.hud.hide()
		for child in level.get_children():
			if child is IntroCall or child is LevelIntro: child.hide()
		level.camera.set_process(false)
		level.camera.global_position = Vector2(176, 112)
		level.camera.zoom = Vector2(3.0, 3.0)
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_guest_room_accents_runtime.png" if runtime_mode else "res://build/m01_guest_room_accents_staging.png")
	var report_path := "res://build/m01_guest_room_accents_runtime_review.json" if runtime_mode else "res://build/m01_guest_room_accents_staging_review.json"
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed": true, "runtime_approved": runtime_mode, "accents": rows, "botanical_wall_art": botanicals, "bedside_lamps": bedside_lamps, "expected_bedside_lamps": 8, "guest_wall_ac_units": guest_acs, "expected_guest_wall_ac_units": 8, "guest_door_plaques": door_plates, "expected_guest_door_plaques": 3, "guest_entry_trims": entry_trims, "expected_guest_entry_trims": 19, "scope": "Live M01 %s capture. Generated props replace equivalent existing floor dressing only; native lamps, AC fixtures, door plaques and guest entry trims retain existing gameplay anchors and add no collision or navigation footprint." % ("runtime" if runtime_mode else "candidate")}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	Dialogue.set_process(true)
	print("M01 GUEST ROOM ACCENTS REVIEW: %d %s props contained in authored guest rooms" % [rows.size(), "runtime" if runtime_mode else "staging"])
	Game.request_quit(0)
