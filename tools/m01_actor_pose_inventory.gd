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
	for frame in 120:
		await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	Dialogue._end(false)
	for node in get_tree().get_nodes_in_group("npcs") + get_tree().get_nodes_in_group("enemies"):
		if not node is Node2D: continue
		var visual := node.get("visual") as CharacterVisual
		var cast := visual.cast_sprite as CastModel if visual else null
		var pos := (node as Node2D).global_position
		print("M01 ACTOR pos=", pos, " type=", node.get_class(), " name=", node.name, " palette=", visual.palette if visual else "", " clip=", cast.clip if cast else "", " idle=", visual.idle_activity_pose if visual else "", " state=", node.get("state"))
	print("M01 ACTOR INVENTORY PASSED")
	Game.request_quit(0)
