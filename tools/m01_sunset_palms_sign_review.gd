extends Node
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var placeholder := Node.new(); get_tree().root.add_child(placeholder); get_tree().current_scene = placeholder
	Game.campaign_mode = false; Game.replay_mission("m01_checkout")
	for _frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	var matches: Array[Node2D] = []
	for node in level.get_node("Decor").get_children():
		if node is Node2D and node.has_node("NativeM01SunsetPalmsSign"):
			matches.append(node)
	assert(matches.size() == 1)
	var sign := matches[0]
	var visual := sign.get_node("NativeM01SunsetPalmsSign") as Sprite2D
	assert(visual.texture != null and visual.visible and bool(sign.get("native_visual_override")))
	assert(visual.find_children("*", "CollisionObject2D", true, false).is_empty())
	var mount := str(sign.get("mount"))
	if mount.begins_with("wall_"):
		var board_size: Vector2 = sign.call("board_size")
		var y := int(floor(sign.global_position.y / 16.0)) - (1 if mount == "wall_s" else 0)
		var x0 := int(floor((sign.global_position.x - board_size.x * .5) / 16.0))
		var x1 := int(ceil((sign.global_position.x + board_size.x * .5) / 16.0))
		for x in range(x0, x1):
			assert(level.builder.ch(x, y) == "#", "Sunset Palms sign must mount on solid facade, never a window")
	elif mount == "pylon":
		assert(sign.find_children("NativeM01SunsetPalmsPylon_*", "Line2D", false, false).size() == 2, "Pylon-mounted sign must have two painted support posts")
	else:
		assert(false, "Sunset Palms sign requires a wall facade or roadside pylon")
	var proof: Dictionary = Engine.get_meta("m01_sunset_palms_sign_review", {})
	assert(int(proof.get("count", 0)) == 1 and not bool(proof.get("collision_added", true)))
	if DisplayServer.get_name() != "headless":
		level.hud.hide()
		for control in get_tree().root.find_children("*", "Control", true, false): (control as Control).hide()
		level.camera.set_process(false); level.camera.set_physics_process(false)
		level.camera.global_position = sign.global_position
		level.camera.zoom = Vector2(6, 6)
		for _frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_sunset_palms_sign_runtime.png")
	print("M01 SUNSET PALMS SIGN REVIEW: Blender visual and native flicker anchor present")
	Game.request_quit(0)
