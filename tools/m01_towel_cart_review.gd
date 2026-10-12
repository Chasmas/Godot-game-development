extends Node

var failures: Array[String] = []

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	check(level != null, "M01 booted")
	if level == null:
		_finish()
		return
	Dialogue._end(false)
	Dialogue.set_process(false)
	level.player.input_enabled = false
	level.player.set_physics_process(false)
	for enemy in level.enemies: enemy.set_physics_process(false)
	var decor := level.get_node_or_null("Decor") as Node2D
	check(decor != null, "M01 Decor root exists")
	var rows: Array = []
	var anchors: Array[Sprite2D] = []
	if decor != null:
		for node in decor.get_children():
			if node is Sprite2D and str(node.get_meta("decor_asset_id", "")) == "motel_towel_cart":
				anchors.append(node)
	check(anchors.size() == 8, "M01 retains eight authored towel-cart anchors")
	for anchor in anchors:
		var visual := anchor.get_node_or_null("NativeM01TowelCart") as Sprite2D
		check(visual != null, "towel-cart anchor has native visual")
		if visual == null: continue
		check(visual.texture != null, "native towel-cart visual has approved texture")
		check(visual.find_children("*", "CollisionObject2D", true, false).is_empty(), "native towel-cart visual adds no collider")
		check(is_zero_approx(anchor.self_modulate.a), "legacy towel-cart sprite is hidden behind native visual")
		rows.append({"position": [anchor.global_position.x, anchor.global_position.y], "standing_anchor": bool(visual.get_meta("standing_anchor", false)), "legacy_scale": [anchor.scale.x, anchor.scale.y]})
	if DisplayServer.get_name() != "headless" and not anchors.is_empty():
		level.hud.hide()
		for control in get_tree().root.find_children("*", "Control", true, false): (control as Control).hide()
		level.camera.set_process(false)
		level.camera.set_physics_process(false)
		level.camera.global_position = anchors[0].global_position
		level.camera.zoom = Vector2(7.0, 7.0)
		for frame in 10: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_towel_cart_runtime.png")
	var report := FileAccess.open("res://build/m01_towel_cart_runtime_review.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_approved": failures.is_empty(), "expected_placements": 8, "placements": rows, "scope": "M01 native towel-cart visuals only; legacy decor transforms retained and no collision or navigation changes introduced."}, "  "))
	report.close()
	Dialogue.set_process(true)
	_finish()

func check(ok: bool, label: String) -> void:
	if ok: print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures.append(label)

func _finish() -> void:
	print("M01 TOWEL CART REVIEW: %d failures" % failures.size())
	Game.request_quit(1 if not failures.is_empty() else 0)