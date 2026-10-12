extends Node

## Records current production GlassWindow bodies before a visual replacement is
## considered.  This deliberately leaves their drawing and break behavior live.

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_window_inventory_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120:
		await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	var rows: Array = []
	for node in get_tree().get_nodes_in_group("glass"):
		if not node is GlassWindow or not level.is_ancestor_of(node):
			continue
		var window := node as GlassWindow
		assert(not window.broken and window.collision_layer == Layers.GLASS)
		var shape := window.get_child(0) as CollisionShape2D
		assert(shape != null and shape.shape is RectangleShape2D)
		assert((shape.shape as RectangleShape2D).size.is_equal_approx(window.size))
		rows.append({"position":[window.global_position.x,window.global_position.y],
			"size_px":[window.size.x,window.size.y],"orientation":"horizontal" if window.size.x >= window.size.y else "vertical"})
	assert(not rows.is_empty())
	var report := FileAccess.open("user://m01_window_runtime_inventory.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed":true,"window_count":rows.size(),"windows":rows,
		"scope":"Current M01 GlassWindow collision bodies and intact state. No staging asset installed."}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	print("M01 WINDOW INVENTORY: %d live breakable windows recorded" % rows.size())
	Game.request_quit(0)
