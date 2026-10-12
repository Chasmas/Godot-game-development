extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var placeholder := Node.new(); get_tree().root.add_child(placeholder); get_tree().current_scene = placeholder
	Game.campaign_mode = false; Game.replay_mission("m01_checkout")
	for _frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	var desk: Furniture
	for node in level.get_tree().get_nodes_in_group("furniture"):
		if node is Furniture and level.is_ancestor_of(node) and (node as Furniture).kind == "desk" and (node as Furniture).global_position.distance_to(Vector2(952, 344)) <= 2.0:
			desk = node as Furniture; break
	assert(desk != null)
	var visual := desk.get_node_or_null("NativeM01OfficeDesk") as Sprite2D
	assert(visual != null and visual.texture != null and visual.visible)
	assert(visual.find_children("*", "CollisionObject2D", true, false).is_empty())
	assert(is_zero_approx(desk.self_modulate.a))
	var proof: Dictionary = Engine.get_meta("m01_office_desk_review", {})
	assert(int(proof.get("count", 0)) == 1 and bool(proof.get("collision_preserved", false)) and bool(proof.get("imagegen_blender", false)))
	if DisplayServer.get_name() != "headless":
		level.hud.hide()
		for control in get_tree().root.find_children("*", "Control", true, false): (control as Control).hide()
		level.camera.set_process(false); level.camera.set_physics_process(false); level.camera.global_position = desk.global_position; level.camera.zoom = Vector2(7, 7)
		for _frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_office_desk_runtime.png")
	print("M01 OFFICE DESK REVIEW: ImageGen-to-Blender visual replacement, original collision preserved")
	Game.request_quit(0)
