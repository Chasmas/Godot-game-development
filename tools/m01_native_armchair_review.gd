extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks",true)
	Engine.set_meta("autoplay",true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_native_armchair_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120: await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	var ground := level.floor_root.get_node("NativeM01Ground") as Node2D
	assert(ground != null and ground.get_child_count()==253)
	var ground_texture := (ground.get_child(0) as Sprite2D).texture
	assert(ground_texture is ImageTexture)
	var covered: Dictionary = {}
	for tile in ground.get_children():
		assert(tile is Sprite2D and tile.get_child_count()==0)
		assert(tile.texture==ground_texture,"All ground tiles must share one texture")
		assert(tile.light_mask==1 and tile.z_index==-9)
		assert(tile.position==tile.region_rect.position*.25)
		assert(tile.scale==Vector2.ONE*.25)
		var key := Vector2i(tile.region_rect.position/256)
		assert(not covered.has(key),"Tiles must never overlap")
		covered[key]=true
	var ground_image := ground_texture.get_image()
	assert(ground_image.is_compressed() and ground_image.get_data_size()==16990208)
	assert(ground_image.decompress()==OK)
	var pool_cells := 0
	for y in level.builder.h:
		for x in level.builder.w:
			if ground_image.get_pixel(x*64+32,y*64+32).a>0:
				assert(covered.has(Vector2i(x/4,y/4)),"Every opaque floor centre needs a tile")
			if level.builder.floor_grid[y][x] == "~":
				assert(ground_image.get_pixel(x*64+32,y*64+32).a==0.0)
				pool_cells+=1
	assert(pool_cells>0)
	var covered_chunks := 0
	for child in level.floor_root.get_children():
		if not child.has_meta("native_floor_fully_covered"): continue
		assert(child is LevelBuilder.FloorChunk and not child.visible)
		for y in range(child.rect.position.y,child.rect.end.y):
			for x in range(child.rect.position.x,child.rect.end.x):
				var kind: String = level.builder.floor_grid[y][x]
				if kind=="": continue
				assert(kind!="~","Water fallback must remain")
				var region := ground_image.get_region(Rect2i(x*64,y*64,64,64))
				var pixels := region.get_data()
				for alpha in range(3,pixels.size(),4):
					assert(pixels[alpha]==255,"Hidden fallback must be fully opaque")
		covered_chunks+=1
	assert(covered_chunks==223)
	var native := level.get_node("NativeM01Armchairs")
	assert(native.get_child_count()==11)
	for layer in level.get_children():
		if layer is Dressing.ClutterLayer or layer is Furnish.FurnitureLayer:
			for item in layer.items: assert(item[0]!="armchair","legacy painting must not remain underneath")
	var helper: Node = load("res://tools/m01_architecture_game_review.gd").new()
	var placements: Array = []
	for sprite in native.get_children():
		var approaches: int = helper.clear_chair_approaches(level,sprite.global_position)
		var door_hits: int = helper.chair_door_arc_hits(sprite.global_position,get_tree())
		assert(approaches>0,"native chair must have an accessible side")
		assert(door_hits==0,"native chair must clear the reachable door swing")
		var image: Image = sprite.texture.get_image()
		var wall_pixels := 0
		for y in range(0,512,8):
			for x in range(0,512,8):
				if image.get_pixel(x,y).a<.5: continue
				var point: Vector2 = sprite.to_global(sprite.offset+Vector2(x,y))
				if level.builder.ch(floori(point.x/16),floori(point.y/16))=="#": wall_pixels+=1
		assert(wall_pixels==0)
		placements.append({"position":[sprite.position.x,sprite.position.y],"approaches":approaches,"door_hits":door_hits,"sampled_wall_pixels":wall_pixels})
	var solids := 0
	var sweep_failures := 0
	var swept_chairs := 0
	for body in level.props_root.get_children():
		if not body.has_meta("native_armchair"): continue
		solids+=1
		var shape := body.get_child(0) as CollisionShape2D
		assert(shape.shape.size.distance_to(Vector2(.73,.67996845)*16)<.001)
		var point_query := PhysicsPointQueryParameters2D.new()
		point_query.position = shape.global_position
		point_query.collision_mask = level.player.collision_mask
		var detected := false
		for hit in level.get_world_2d().direct_space_state.intersect_point(point_query, 32):
			if hit.collider == body:
				detected = true
		assert(detected, "Player movement mask must detect every chair footprint")
		var player_contacts := 0
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var local_start: Vector2 = direction * (shape.shape.size * .5 + Vector2.ONE * (Player.RADIUS + 2.0))
			var start := shape.to_global(local_start)
			var from := level.player.global_transform
			from.origin = start
			if level.player.test_move(from, Vector2.ZERO):
				continue
			var contact := KinematicCollision2D.new()
			if level.player.test_move(from, shape.global_position - start, contact) and contact.get_collider() == body:
				player_contacts += 1
		if player_contacts > 0:
			swept_chairs += 1
		else:
			sweep_failures += 1
			push_error("No clear player sweep reaches chair at " + str(shape.global_position))
		print("CHAIR PLAYER SWEEP position=", shape.global_position, " contact_sides=", player_contacts)
		# The smaller grounded geometry still overlaps the four original nav cells.
		var cells := {}
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var point := shape.to_global(corner*shape.shape.size*.5)
			var cell := Vector2i(floori(point.x/16),floori(point.y/16))
			cells[cell]=true
			assert(level.nav.is_point_solid(cell))
		assert(cells.size()>=1 and cells.size()<=4)
	assert(solids==11)
	helper.free()
	var output := FileAccess.open("res://build/m01_native_armchair_review.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"placements":placements,"native_chairs":11,"native_solid_colliders":solids,"player_sweep_chairs":swept_chairs,"player_sweep_failures":sweep_failures,"legacy_armchair_paintings":0},"  "))
	if DisplayServer.get_name()!="headless":
		level.player.set_physics_process(false)
		level.player.visual.update_move(Vector2.ZERO,0)
		for enemy in level.enemies:
			enemy.set_physics_process(false)
			enemy.visual.update_move(Vector2.ZERO,0)
		level.hud.hide()
		for child in level.get_children():
			if child is IntroCall or child is LevelIntro: child.hide()
		level.camera.set_process(false)
		level.camera.global_position=Vector2(390,116)
		level.camera.zoom=Vector2(2.5,2.5)
		for frame in 12: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/m01_native_armchair_runtime.png")
	SaveManager.data=saved
	SaveManager.save_path=saved_path
	print("M01 NATIVE ARMCHAIR REVIEW: 11 accessible chairs, zero door/wall overlaps, 11 measured colliders detected by player mask, matching nav cells reserved")
	print("M01 NATIVE GROUND REVIEW: compressed resource loaded; exact map extent; %d pool centres transparent; no added physics" % pool_cells)
	print("CHAIR PLAYER SWEEP REVIEW: ", swept_chairs, " chairs, ", sweep_failures, " failures")
	Game.request_quit(1 if sweep_failures else 0)




