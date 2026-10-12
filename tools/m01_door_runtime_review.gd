extends Node

## Fast, map-level door projection gate.  It deliberately does not replace
## production visuals; it proves the staged leaf projection can follow every
## current wooden Door without changing its live collision or interaction.

const CONTRACT := "res://assets/art/prerendered/m01_sunset_palms/staging/guest_door_v1/leaf_projection_contract.json"

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_door_runtime_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null and level.walls_root.has_node("NativeM01Walls"))
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	assert(not bool(contract.get("runtime_approved", false)))
	assert(float(contract.get("texture_scale_for_32px_leaf", 0.0)) > 0.0)
	var rows: Array = []
	for node in get_tree().get_nodes_in_group("door"):
		if not node is Door or node.metal: continue
		var door := node as Door
		assert(door.leaf != null and door.leaf.collision_layer == Layers.DOOR)
		var original := door.swing
		for degrees in [0.0, 45.0, 85.0]:
			door.swing = deg_to_rad(degrees)
			door._apply()
			# The leaf is a child positioned at the hinge, so its local rotation
			# includes the map-authored closed orientation as well as its swing.
			assert(is_equal_approx(door.leaf.rotation, door.closed_angle + door.swing))
			var expected := door.global_position + door.leaf_dir() * door.length
			assert(door.hit_point(expected + door.leaf_dir() * 32.0).distance_to(expected) < .02)
		door.swing = original
		door._apply()
		rows.append({"position":[door.position.x,door.position.y],"length_px":door.length,"closed_angle":door.closed_angle})
	assert(not rows.is_empty(), "M01 must retain wooden doors for the staged leaf projection")
	var report := FileAccess.open("user://m01_door_runtime_review.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed":true,"runtime_approved":false,"doors":rows,
		"scope":"Current M01 wooden Door swing, endpoint and collision geometry; staged leaf/debris art remains uninstalled pending visual lighting review."}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	print("M01 DOOR RUNTIME REVIEW: %d wooden doors verified at 0, 45 and 85 degrees" % rows.size())
	Game.request_quit(0)
