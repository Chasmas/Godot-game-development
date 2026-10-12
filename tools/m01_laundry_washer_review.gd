extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for _frame in 120:
		await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	var washers: Array[Furniture] = []
	for node in level.get_tree().get_nodes_in_group("furniture"):
		if node is Furniture and level.is_ancestor_of(node):
			var washer := node as Furniture
			if washer.kind == "washer" and washer.global_position.x >= 72.0 and washer.global_position.x <= 120.0 and washer.global_position.y >= 440.0 and washer.global_position.y <= 504.0:
				washers.append(washer)
	assert(washers.size() == 2)
	for washer in washers:
		var visual := washer.get_node_or_null("NativeM01LaundryWasher") as Sprite2D
		assert(visual != null and visual.texture != null and visual.visible)
		assert(visual.texture.get_image().get_used_rect().size.x > 0)
		assert(visual.find_children("*", "CollisionObject2D", true, false).is_empty())
		assert(is_zero_approx(washer.self_modulate.a))
	var proof: Dictionary = Engine.get_meta("m01_laundry_washer_review", {})
	assert(int(proof.get("count", 0)) == 2 and bool(proof.get("collision_preserved", false)) and bool(proof.get("imagegen_blender", false)))
	if DisplayServer.get_name() != "headless":
		level.hud.hide()
		for control in get_tree().root.find_children("*", "Control", true, false):
			(control as Control).hide()
		level.camera.set_process(false)
		level.camera.set_physics_process(false)
		level.camera.global_position = washers[0].global_position.lerp(washers[1].global_position, .5)
		level.camera.zoom = Vector2(8, 8)
		for _frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_laundry_washer_runtime.png")
	print("M01 LAUNDRY WASHER REVIEW: 2 ImageGen-to-Blender visual replacements, original collision preserved")
	Game.request_quit(0)
