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
	Game.replay_mission("m01_checkout")
	Game.attempts = 2
	for frame in 90: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	level.player.god_mode = true
	level.player.input_enabled = false
	level.player.set_physics_process(false)
	for enemy in level.enemies: enemy.set_physics_process(false)
	var tree: Decor.PalmTree
	for child in level.get_node("Decor").get_children():
		if child is Decor.PalmTree:
			tree = child
			break
	if tree == null:
		push_error("No authored M01 palm found")
		SaveManager.data = saved
		Game.request_quit(1)
		return
	tree.set_process(false)
	if OS.get_environment("PALM_TRUNK_REVIEW") == "1":
		tree.trunk_texture = ImageTexture.create_from_image(Image.load_from_file("res://build/palm_trunk_review/trunk_top_v1.png"))
	if tree.flame_texture == null and OS.get_environment("PALM_TEXTURE_REVIEW") != "1":
		push_error("Runtime palm has no authored flame texture")
		SaveManager.data = saved
		Game.request_quit(1)
		return
	if OS.get_environment("PALM_TEXTURE_REVIEW") == "1":
		tree.flame_texture = ImageTexture.create_from_image(Image.load_from_file("res://build/flame_texture_review/flame_v1.png"))
	tree.visible = true
	level.player.global_position = tree.global_position + Vector2(-45,0)
	level.camera.set_process(false)
	level.camera.limit_left = -100000
	level.camera.limit_top = -100000
	level.camera.limit_right = 100000
	level.camera.limit_bottom = 100000
	level.camera.global_position = tree.global_position
	level.camera.offset = Vector2.ZERO
	level.camera.zoom = Vector2(3,3)
	level.hud.visible = false
	DirAccess.make_dir_recursive_absolute("res://build/palm_fire_review")
	if OS.get_environment("PALM_LIGHTNING_REVIEW") == "1":
		var bolt := AmbientEventDirector.LightningStrike.new()
		bolt.position = Vector2(-7,0)
		tree.add_child(bolt)
		bolt.strike()
		bolt.set_process(false)
		for sample in [0.0,0.06,0.085,0.2,0.39]:
			bolt._age = sample
			bolt._update_flash()
			for frame in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/palm_fire_review/lightning_%03d.png" % int(sample*1000))
		SaveManager.data = saved
		print("PALM LIGHTNING REVIEW: five discharge phases captured")
		Game.request_quit(0)
		return
	if OS.get_environment("PALM_SEQUENCE_REVIEW") == "1":
		DirAccess.make_dir_recursive_absolute("res://build/palm_fire_review/sequence_30fps")
		var bolt := AmbientEventDirector.LightningStrike.new()
		bolt.position = Vector2(-7,0)
		tree.add_child(bolt)
		bolt.strike()
		bolt.set_process(false)
		tree.start_lightning_fire()
		for frame in 391:
			if frame > 0: tree._process(1.0/30.0)
			if is_instance_valid(bolt):
				bolt._age = float(frame)/30.0
				bolt._update_flash()
				if frame >= 12: bolt.queue_free()
			tree.visible = true
			tree.queue_redraw()
			tree._shadow.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().get_region(Rect2i(650,80,630,720)).save_png("res://build/palm_fire_review/sequence_30fps/%03d.png" % frame)
			if frame % 90 == 0: print("PALM FIRE SEQUENCE FRAME ",frame," / 390")
		SaveManager.data = saved
		print("PALM FIRE SEQUENCE: 391 frames at 30 authored samples/sec")
		Game.request_quit(0)
		return
	for stage in ["healthy", "burning", "midburn", "lateburn", "finished"]:
		if stage == "burning": tree.start_lightning_fire()
		var advance := 6.0 if stage == "midburn" else (3.0 if stage == "lateburn" else (4.0 if stage == "finished" else 0.0))
		for step in int(advance * 30): tree._process(1.0/30.0)
		tree.visible = true
		tree.queue_redraw()
		tree._shadow.queue_redraw()
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/palm_fire_review/%s.png" % stage)
		print("PALM FIRE CAPTURE ",stage," at=",tree.global_position)
	SaveManager.data = saved
	Game.request_quit(0)
