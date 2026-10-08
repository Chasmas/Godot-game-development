extends Node
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var old_data := SaveManager.data.duplicate(true)
	var old_gore = SaveManager.settings.get("gore", 2)
	SaveManager.settings["gore"] = 2
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.start_mission("m01_checkout")
	Game.attempts = 2
	for frame in 90: await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	player.god_mode = true
	player.input_enabled = false
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies: enemy.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://build/combat_death_map_review")
	var captured := 0
	for enemy in enemies:
		if captured >= 3: break
		if not enemy is Enemy or not enemy.is_alive(): continue
		player.global_position = enemy.global_position + Vector2(32, 20)
		var level = player.get_parent()
		if level is Level: level.camera.snap_to_target()
		var info := DamageInfo.make(DamageInfo.Type.MELEE, player, enemy.global_position, Vector2.LEFT, &"chainsaw", &"melee")
		info.heavy = true
		enemy.take_damage(info)
		for frame in 100: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/combat_death_map_review/death_%d.png" % captured)
		captured += 1
	SaveManager.data = old_data
	SaveManager.settings["gore"] = old_gore
	print("MAP DEATH VISUAL: ", captured, " captures")
	Game.request_quit(0 if captured == 3 else 1)
