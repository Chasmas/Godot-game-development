extends Node
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for _frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	var shelves: Array[Sprite2D] = []
	for node in level.get_children():
		if node is Sprite2D and bool(node.get_meta("native_m01_guest_wall_shelf", false)):
			shelves.append(node)
	assert(shelves.size() >= 4 and shelves.size() <= 8)
	var variants: Dictionary = {}
	for shelf in shelves:
		assert(shelf.texture != null and shelf.visible)
		assert(shelf.find_children("*", "CollisionObject2D", true, false).is_empty())
		variants[int(shelf.get_meta("native_m01_guest_wall_shelf_variant", -1))] = true
	assert(variants.size() == 3)
	var proof: Dictionary = Engine.get_meta("m01_guest_wall_shelf_review", {})
	assert(int(proof.get("count", 0)) == shelves.size() and not bool(proof.get("collision_added", true)))
	if DisplayServer.get_name() != "headless":
		level.hud.hide()
		for control in get_tree().root.find_children("*", "Control", true, false): (control as Control).hide()
		level.camera.set_process(false)
		level.camera.set_physics_process(false)
		level.camera.global_position = shelves[0].global_position
		level.camera.zoom = Vector2(7, 7)
		for _frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_guest_wall_shelf_runtime.png")
	print("M01 GUEST WALL SHELF REVIEW: ", shelves.size(), " Blender visual-only placements across ", variants.size(), " variants")
	Game.request_quit(0)
