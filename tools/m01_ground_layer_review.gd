extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	Engine.set_meta("skip_native_m01_ground",true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_ground_layer_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 900:
		await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	var integrated_ground := level.floor_root.get_node_or_null("NativeM01Ground")
	if integrated_ground != null: integrated_ground.queue_free()
	Dialogue._end(false)
	Dialogue.set_process(false)
	level.player.input_enabled = false
	level.player.set_physics_process(false)
	level.player.global_position = Vector2(400,352)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
		enemy.visual.update_move(Vector2.ZERO,0)
	level.player.visual.update_move(Vector2.ZERO,0)
	level.hud.hide()
	for child in level.get_children():
		if child is IntroCall or child is LevelIntro: child.queue_free()
	level.camera.set_process(false)
	level.camera.set_physics_process(false)
	level.camera.zoom = Vector2.ONE * 1.5
	level.camera.global_position = Vector2(470,260)
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_ground_baseline.png")
	var baseline := await measure_frames()
	var image := Image.load_from_file("res://assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/ground_layer_candidate_v3.png")
	if image == null or image.get_size() != Vector2i(4352,3904):
		push_error("Invalid M01 ground layer image")
		SaveManager.data = saved
		SaveManager.save_path = saved_path
		Game.request_quit(1)
		return
	var sprite := Sprite2D.new()
	var texture_image := image.duplicate() as Image
	var compressed := OS.get_environment("M01_GROUND_COMPRESS") == "1"
	if compressed:
		var compression_error := texture_image.compress(Image.COMPRESS_S3TC)
		assert(compression_error == OK, "S3TC compression must succeed")
		var decoded := texture_image.duplicate() as Image
		assert(decoded.decompress() == OK, "Compressed ground must decode")
		decoded.save_png("res://build/m01_ground_s3tc_decoded.png")
	sprite.texture = ImageTexture.create_from_image(texture_image)
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE * .25
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -9
	level.floor_root.add_child(sprite)
	assert(sprite.get_rect().size * sprite.scale == Vector2(1088,976), "Ground must cover the exact 68x61 map")
	var map_rows: Array = level.data.get("map",[])
	var pool_cells := 0
	for y in map_rows.size():
		for x in str(map_rows[y]).length():
			if str(map_rows[y])[x] == "~":
				assert(image.get_pixel(x*64+32,y*64+32).a == 0.0, "Pool must remain transparent")
				pool_cells += 1
	assert(pool_cells > 0, "Review must include the pool")
	var candidate := await measure_frames()
	var tiled_review: Dictionary = {}
	if OS.get_environment("M01_GROUND_TILES") == "1":
		sprite.hide()
		var tiles := Node2D.new()
		tiles.name="GroundLightingTiles"
		level.floor_root.add_child(tiles)
		for y in range(0,image.get_height(),256):
			for x in range(0,image.get_width(),256):
				var region := Rect2i(x,y,mini(256,image.get_width()-x),mini(256,image.get_height()-y))
				if image.get_region(region).is_invisible(): continue
				var tile := Sprite2D.new()
				tile.texture=sprite.texture
				tile.region_enabled=true
				tile.region_rect=Rect2(region)
				tile.centered=false
				tile.position=Vector2(x,y)*.25
				tile.scale=Vector2.ONE*.25
				tile.z_index=-9
				tile.light_mask=1
				tile.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				tiles.add_child(tile)
		tiled_review=await measure_frames()
		tiled_review["tiles"]=tiles.get_child_count()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_ground_tiled_lighting.png")
	var report := {
		"candidate": "ground_layer_candidate_v3.png",
		"compressed": compressed,
		"texture_bytes": texture_image.get_data_size(),
		"baseline": baseline,
		"with_ground": candidate,
		"with_tiled_ground": tiled_review,
		"map_extent_px": [1088,976],
		"scope": "frozen actors, compatibility renderer, capped 60 fps; visual fixture, not gameplay benchmark"
	}
	var suffix := "compressed" if compressed else "uncompressed"
	var report_file := FileAccess.open("res://build/m01_ground_runtime_review_%s.json" % suffix,FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report,"\t"))
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_ground_candidate_%s.png" % suffix)
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	Dialogue.set_process(true)
	print("M01_GROUND_REVIEW: captured baseline and candidate; preview only")
	Game.request_quit(0)

func measure_frames() -> Dictionary:
	for frame in 30: await get_tree().process_frame
	var samples: Array[float] = []
	for frame in 180:
		if Dialogue.active: Dialogue._end(false)
		Dialogue.root.hide()
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)
	samples.sort()
	return {"median_ms": samples[90], "p95_ms": samples[171], "samples": samples.size()}
