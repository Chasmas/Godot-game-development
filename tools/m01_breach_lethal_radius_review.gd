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
	assert(level != null and level.breach != null and level.player != null)
	Dialogue._end(false)
	var breach := level.breach
	var mid := Vector2.ZERO
	for door in breach.doors:
		mid += (door as Node2D).global_position
	mid = mid / breach.doors.size() + Vector2(12, 0)
	level.player.god_mode = false
	level.player.armor_hits = 0
	level.player.global_position = mid
	breach.detonate()
	await get_tree().process_frame
	assert(not level.player.alive, "Cass must die inside the breach explosion lethal radius")
	print("M01 BREACH LETHAL-RADIUS REVIEW PASSED")
	Game.request_quit(0)
