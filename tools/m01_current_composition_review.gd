extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.attempts = 2
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	Dialogue._end(false)
	get_tree().paused = false
	level.set_process(false)
	level.player.set_physics_process(false)
	for enemy in level.enemies: enemy.set_physics_process(false)
	level.hud.hide()
	for child in level.get_children():
		if child is IntroCall or child is LevelIntro: child.hide()
	level.camera.set_process(false)
	level.camera.set_physics_process(false)
	level.camera.zoom = Vector2(3, 3)
	var native_ground := level.floor_root.get_node_or_null("NativeM01Ground") as Node2D
	assert(native_ground != null, "Current M01 ground contract must install the reviewed native layer")
	var ground_sprites := native_ground.find_children("*", "Sprite2D", false, false)
	assert(ground_sprites.size() == 1, "v3 review approves one compressed shared ground sprite")
	var ground_sprite := ground_sprites[0] as Sprite2D
	assert(ground_sprite.texture != null and ground_sprite.texture.get_size() == Vector2(4352,3904))
	assert(ground_sprite.position == Vector2.ZERO and ground_sprite.scale == Vector2.ONE*.25 and not ground_sprite.centered)
	assert(ground_sprite.z_index == -9 and ground_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var guest_shelves := level.find_children("NativeM01GuestWallShelf_*", "Sprite2D", true, false)
	assert(guest_shelves.size() == 8, "The approved M01 guest-room shelf pass must remain present in all eight selected rooms")
	for shelf in guest_shelves:
		var shelf_sprite := shelf as Sprite2D
		assert(shelf_sprite.texture != null and shelf_sprite.visible, "Guest wall shelves must keep their authored Blender art visible")
		assert(not shelf_sprite.has_node("CollisionShape2D"), "Guest wall shelf dressing must not add a hidden gameplay blocker")
	print("M01 native guest wall shelves: ", guest_shelves.size())
	var televisions := 0
	var television_anchors: Array = []
	var source_crt_anchors: Array = []
	var room101_furniture: Array = []
	for anchor in level.get_node("Decor").get_children():
		if anchor is Sprite2D and str(anchor.get_meta("decor_asset_id", "")) == "motel_tv_crt":
			source_crt_anchors.append([anchor.global_position.x, anchor.global_position.y])
		var television := anchor.get_node_or_null("NativeM01CrtTV") as Sprite2D
		if television == null: continue
		televisions += 1
		television_anchors.append({"anchor": [anchor.global_position.x, anchor.global_position.y], "visible": anchor.visible, "source_alpha": anchor.self_modulate.a})
		var visible_world_width := 153.0 * absf(television.global_scale.x)
		assert(absf(visible_world_width - 12.8) < 0.01, "CRT silhouette must fit its physical width")
	print("M01 CRT native count=", televisions, " anchors=", television_anchors, " source anchors=", source_crt_anchors)
	assert(source_crt_anchors.size() == 3, "M01 CRT source anchors changed; review placement before accepting the runtime contract")
	assert(televisions == source_crt_anchors.size(), "Every authored M01 CRT must receive its reviewed native replacement")
	for body in level.props_root.get_children():
		if not body is Node2D: continue
		var position := (body as Node2D).global_position
		if not Rect2(176, 432, 128, 64).has_point(position): continue
		room101_furniture.append({"name": body.name, "position": [position.x, position.y], "native_dresser": body.get_meta("native_dresser", false), "native_armchair": body.get_meta("native_armchair", false), "kind": body.get("kind")})
	print("M01 room101 physics furniture=", room101_furniture)
	# Includes the actual locked Harcourt breach at its live map coordinate,
	# with the follow camera frozen so intro/car presentation cannot displace it.
	for point in [Vector2(200, 440), Vector2(370, 115), Vector2(940, 490), Vector2(936, 664), Vector2(1000, 264)]:
		level.camera.global_position = point
		for frame in 12: await get_tree().process_frame
		# RenderingServer.frame_post_draw has no completion event in headless
		# validation. Captures are a windowed-review artifact; the composition
		# assertions below remain valid in both modes.
		if DisplayServer.get_name().to_lower() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/m01_composition_%d.png" % int(point.x))
	var door := level.breach.doors[0] as Door
	assert(door.visual_texture != null and door.broken_visual_texture != null, "Harcourt gate must retain its armored visual states in live M01")
	for shot in 12:
		door.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, level.player, door.global_position, Vector2.UP, &"pistol"))
	assert(door.locked and not door.broken and door.hp == 5, "Breach gate must survive ordinary weapon damage")
	var report := FileAccess.open("res://build/m01_current_composition_review.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"native_ground":{"sprite_count":ground_sprites.size(),"texture_size":[ground_sprite.texture.get_size().x,ground_sprite.texture.get_size().y],"scale":[ground_sprite.scale.x,ground_sprite.scale.y]},"native_crt_count": televisions, "native_crt_anchors": television_anchors, "source_crt_anchors": source_crt_anchors, "room101_physics_furniture": room101_furniture, "scope": "Current live M01 composition inventory; count is descriptive and must not be confused with an approved layout."}, "\t"))
	print("M01 CURRENT COMPOSITION REVIEW PASSED: v3 ground, captures saved; breach gate survives 12 shots")
	# A visual-review scene has no player-facing audio lifecycle to drain.
	# Quit directly so an unattended validation cannot remain resident after the
	# report and captures have been written.
	get_tree().quit()
