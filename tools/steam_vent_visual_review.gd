extends Node
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m02_dog_days")
	Game.attempts = 2
	for frame in 90: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	level.player.god_mode = true
	level.player.input_enabled = false
	level.player.set_physics_process(false)
	for enemy in level.enemies: enemy.set_physics_process(false)
	var vents: Array[Node] = []
	for child in level.get_node("Decor").get_children():
		if child.get_script() == load("res://scripts/levels/steam_vent.gd"):
			vents.append(child)
	if vents.size() != 1:
		push_error("Expected one authored runtime steam vent, got %d" % vents.size())
		SaveManager.data = saved
		Game.request_quit(1)
		return
	var vent := vents[0] as Node2D
	vent.set_process(false)
	level.player.global_position = vent.global_position + Vector2(-24,0)
	level.camera.snap_to_target()
	level.camera.set_process(false)
	level.camera.limit_left = -100000
	level.camera.limit_top = -100000
	level.camera.limit_right = 100000
	level.camera.limit_bottom = 100000
	level.camera.global_position = vent.global_position
	level.camera.offset = Vector2.ZERO
	level.camera.zoom = Vector2(3,3)
	level.hud.visible = false
	for phase in [0.0,1.5,3.0,6.5]:
		vent.elapsed = phase
		vent.queue_redraw()
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/steam_wisp_review/yermo_%.1f.png" % phase)
		print("STEAM REVIEW phase=", phase)
	SaveManager.data = saved
	Game.request_quit(0)
