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
	assert(breach.doors.size() >= 1 and not breach.done and not breach.has_charge)
	for door in breach.doors:
		var d := door as Door
		assert(d.locked and d.metal and d.breach_only and not d.broken)
		assert(d.visual_texture != null and d.broken_visual_texture != null, "Harcourt gate must use its armored Blender visual states")
		var hp := d.hp
		for shot in 8:
			d.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, level.player, d.global_position, Vector2.UP, &"pistol", &"gun"))
		assert(d.hp == hp and d.locked and not d.broken, "Ordinary fire must not bypass the breach gate")
	if DisplayServer.get_name() != "headless":
		# Focus the real gameplay camera on the gate and suppress unrelated HUD
		# panels so the capture assesses the asset at its shipping scale.
		var gate := breach.doors[0] as Door
		level.player.global_position = gate.global_position + Vector2(-112, 0)
		level.player.velocity = Vector2.ZERO
		level.camera.set_process(false)
		level.camera.set_physics_process(false)
		level.camera.global_position = gate.global_position + gate.leaf_dir() * (gate.length * 0.5)
		level.camera.zoom = Vector2(6.5, 6.5)
		level.hud.visible = false
		for child in level.get_children():
			if child is IntroCall or child is LevelIntro:
				child.hide()
		for control in get_tree().root.find_children("*", "Control", true, false):
			(control as Control).hide()
		for _frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_harcourt_gate_locked.png")
	assert(not level._boss_triggered)
	breach._on_take(null, level.player)
	assert(breach.has_charge and breach._plant_it.enabled and breach.objective().contains("PLANT"))
	# Detonation itself is deterministic; keep Cass outside its lethal radius here
	# so the next assertion can verify the post-breach boss-room trigger.
	level.player.global_position = breach._plant_it.global_position + Vector2(-180, 180)
	breach.detonate()
	assert(breach.done and not breach.planted)
	for door in breach.doors:
		var d := door as Door
		assert(d.broken and not d.locked)
		assert(d.broken_visual_texture != null)
	if DisplayServer.get_name() != "headless":
		for _frame in 90:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_harcourt_gate_breached.png")
	assert(not level._boss_triggered, "Explosion must not start Harcourt before Cass enters his room")
	var trigger: Array = level.data.get("boss_trigger", [])
	assert(trigger.size() == 4)
	level.player.global_position = Vector2((int(trigger[0]) + 1) * 16 + 8, (int(trigger[1]) + 1) * 16 + 8)
	level._process(1.0 / 60.0)
	assert(level._boss_triggered and Dialogue.active and Dialogue._id == "m01_boss_intro", "Harcourt intro must begin only after entry post-breach")
	print("M01 BREACH/BOSS FLOW REVIEW PASSED")
	Game.request_quit(0)
