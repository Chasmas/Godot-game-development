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
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	var machines: Array[BreakableProp] = []
	for node in level.props_root.get_children():
		if node is BreakableProp and (node as BreakableProp).kind == "ice":
			machines.append(node)
	check(machines.size() == 2, "M01 retains two ice BreakableProp instances")
	var rows: Array = []
	for machine in machines:
		var visual := machine.get_node_or_null("NativeM01IceMachine") as Sprite2D
		check(visual != null, "intact ice machine has native M01 visual")
		if visual == null: continue
		check(visual.texture != null, "native ice visual has its approved texture")
		check(visual.find_children("*", "CollisionObject2D", true, false).is_empty(), "native ice visual adds no collider")
		var image := visual.texture.get_image()
		check(image.get_used_rect().size.x > 0, "native ice texture has transparent-alpha content")
		var collision_nodes := machine.find_children("*", "CollisionShape2D", false, false)
		var collision := collision_nodes[0] as CollisionShape2D if not collision_nodes.is_empty() else null
		check(collision != null and collision.shape is RectangleShape2D, "legacy ice collision shape remains")
		var layer_before := machine.collision_layer
		check(layer_before == Layers.PROP, "legacy ice collision stays on PROP layer")
		rows.append({"position": [machine.global_position.x, machine.global_position.y], "collision_layer": layer_before, "intact_visual": visual.visible, "texture_size": [image.get_width(), image.get_height()]})
	if DisplayServer.get_name() != "headless" and not machines.is_empty():
		level.hud.hide()
		for control in get_tree().root.find_children("*", "Control", true, false):
			(control as Control).hide()
		level.camera.set_process(false)
		level.camera.set_physics_process(false)
		level.camera.global_position = machines[0].global_position
		level.camera.zoom = Vector2(7.0, 7.0)
		for frame in 10: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_ice_machine_runtime.png")
	if not machines.is_empty():
		var tested := machines[0]
		var tested_visual := tested.get_node_or_null("NativeM01IceMachine") as Sprite2D
		var layer_before := tested.collision_layer
		tested._break(DamageInfo.make(DamageInfo.Type.MELEE, level.player, tested.global_position, Vector2.RIGHT), true)
		for frame in 2: await get_tree().process_frame
		check(tested.is_broken, "ice machine still receives its original damage transition")
		check(tested_visual != null and not tested_visual.visible, "native intact visual hides after break")
		check(tested.collision_layer == layer_before, "broken ice machine preserves its original solid collision layer")
	var report := FileAccess.open("res://build/m01_ice_machine_runtime_review.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_approved": failures.is_empty(), "expected_placements": 2, "placements": rows, "damage_transition_checked": not machines.is_empty(), "scope": "M01 native intact ice visuals; original BreakableProp collision, health, sound, and broken drawing retained."}, "  "))
	report.close()
	Dialogue.set_process(true)
	_finish()

func check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		failures.append(label)

func _finish() -> void:
	print("M01 ICE MACHINE REVIEW: %d failures" % failures.size())
	Game.request_quit(1 if not failures.is_empty() else 0)
