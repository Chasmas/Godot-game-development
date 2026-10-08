extends Node

func _ready() -> void:
	var version := OS.get_environment("M01_WALL_VERSION")
	if version.is_empty(): version="v3"
	assert(version in ["v1","v2","v3","v4","v5"])
	var wall_mask := int(OS.get_environment("M01_WALL_MASK"))
	if wall_mask == 0: wall_mask=2
	Engine.set_meta("skip_tasks",true)
	Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path="user://m01_wall_layer_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene=placeholder
	Game.campaign_mode=false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level.floor_root.has_node("NativeM01Ground"))
	Dialogue._end(false)
	Dialogue.set_process(false)
	level.player.input_enabled=false
	level.player.set_physics_process(false)
	level.player.visual.update_move(Vector2.ZERO,0)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
		enemy.visual.update_move(Vector2.ZERO,0)
	level.hud.hide()
	for child in level.get_children():
		if child is IntroCall or child is LevelIntro: child.hide()
	level.camera.set_process(false)
	level.camera.set_physics_process(false)
	level.camera.global_position=Vector2(390,116)
	level.camera.zoom=Vector2(2.5,2.5)
	for frame in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_wall_%s_baseline.png" % version)
	var image := Image.load_from_file("res://assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/wall_layer_candidate_%s.png" % version)
	assert(image != null and image.get_size()==Vector2i(2176,1952))
	var wall := Node2D.new()
	wall.name="TiledWallReview"
	var texture := ImageTexture.create_from_image(image)
	var tile_count := 0
	# Match the existing baked-floor granularity: local canvas items avoid
	# exhausting Godot's per-item light limit on one map-sized texture.
	for y in range(0,image.get_height(),128):
		for x in range(0,image.get_width(),128):
			var region := Rect2i(x,y,mini(128,image.get_width()-x),mini(128,image.get_height()-y))
			if image.get_region(region).is_invisible(): continue
			var tile := Sprite2D.new()
			tile.texture=texture
			tile.region_enabled=true
			tile.region_rect=Rect2(region)
			tile.centered=false
			tile.position=Vector2(x,y)*.5
			tile.scale=Vector2.ONE*.5
			tile.z_index=6
			tile.light_mask=wall_mask
			tile.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			wall.add_child(tile)
			tile_count+=1
	var chunks := 0
	for child in level.walls_root.get_children():
		if child is LevelBuilder.WallChunk:
			child.hide()
			chunks+=1
	assert(chunks>0)
	level.walls_root.add_child(wall)
	for frame in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_wall_%s_mask%d_candidate.png" % [version,wall_mask])
	SaveManager.data=saved
	SaveManager.save_path=saved_path
	Dialogue.set_process(true)
	print("M01 WALL %s REVIEW: %d locally lit tiles; %d wall drawing chunks hidden; physics retained; production ground retained" % [version,tile_count,chunks])
	Game.request_quit(0)
