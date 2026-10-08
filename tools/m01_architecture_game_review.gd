extends Node

func chair_wall_samples(image: Image, anchor: Vector2, scale_factor: float, position: Vector2, builder: LevelBuilder) -> int:
	var count := 0
	for y in range(0, 512, 8):
		for x in range(0, 512, 8):
			if image.get_pixel(x, y).a < .5:
				continue
			var point := position + (Vector2(x, y) - anchor) * scale_factor
			if builder.ch(floori(point.x / 16), floori(point.y / 16)) == "#":
				count += 1
	return count

func chair_door_arc_hits(position: Vector2, tree: SceneTree, footprint := Vector2(13.88,13.40)) -> int:
	var occupied := Rect2(position - footprint*.5, footprint)
	var corners := [occupied.position, Vector2(occupied.end.x, occupied.position.y), occupied.end, Vector2(occupied.position.x, occupied.end.y)]
	var hits := 0
	for door in tree.get_nodes_in_group("door"):
		if not door is Door or door.broken or door.global_position.distance_to(position) > door.length + 10:
			continue
		var original: float = door.swing
		var hit := false
		for direction in [-1, 1]:
			for angle in range(0, 106):
				door.swing = deg_to_rad(float(angle * direction))
				if door._leaf_blocked():
					break
				var a: Vector2 = door.global_position + door.leaf_dir()
				var b: Vector2 = door.global_position + door.leaf_dir() * (door.length - 1)
				if occupied.has_point(a) or occupied.has_point(b):
					hit = true
				for edge in 4:
					if Geometry2D.segment_intersects_segment(a, b, corners[edge], corners[(edge + 1) % 4]) != null:
						hit = true
			door.swing = original
		if hit:
			hits += 1
		door.swing = original
	return hits

func clear_chair_approaches(level: Level, position: Vector2, stop_distance := 14.0) -> int:
	var clear := 0
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var transform := Transform2D(0, position + direction * (stop_distance + 16))
		if not level.player.test_move(transform, Vector2.ZERO) and not level.player.test_move(transform, -direction * 16):
			clear += 1
	return clear

func preview_armchairs(level: Level) -> int:
	var directory := "res://assets/art/prerendered/m01_sunset_palms/staging/armchair_runtime_v3/"
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + "runtime_contract.json"))
	var count := 0
	var placement_report: Array = []
	for layer in level.get_children():
		if not (layer is Dressing.ClutterLayer or layer is Furnish.FurnitureLayer):
			continue
		var remaining: Array = []
		var changed := false
		for item in layer.items:
			if str(item[0]) != "armchair":
				remaining.append(item)
				continue
			changed = true
			var position: Vector2 = item[1].get_center() if item[1] is Rect2 else item[1]
			var facing := posmod(roundi(-float(item[2]) / (PI * .5)), 4)
			var frame: Dictionary = contract.frames[facing]
			var image := Image.load_from_file(directory + str(frame.file))
			assert(not image.is_empty())
			var original_position := position
			var anchor := Vector2(frame.floor_anchor_px[0], frame.floor_anchor_px[1])
			var sprite_scale := float(contract.sprite_scale)
			if layer is Dressing.ClutterLayer and (chair_wall_samples(image, anchor, sprite_scale, position, level.builder) > 0 or chair_door_arc_hits(position, get_tree()) > 0 or clear_chair_approaches(level,position) == 0):
				# Decorative chairs have no collision body to relocate. Find the
				# nearest clear placement; solid FurnitureLayer pieces stay put.
				var best_distance := INF
				for dy in range(-40, 41, 2):
					for dx in range(-40, 41, 2):
						var shift := Vector2(dx, dy)
						if shift.length() > 40 or shift.length_squared() >= best_distance:
							continue
						var candidate := original_position + shift
						var query := PhysicsPointQueryParameters2D.new()
						query.position = candidate
						query.collision_mask = Layers.WORLD | Layers.PROP
						if not level.get_world_2d().direct_space_state.intersect_point(query).is_empty():
							continue
						if shift.length_squared() > 0:
							var path_query := PhysicsRayQueryParameters2D.create(original_position, candidate, Layers.WORLD | Layers.PROP)
							if not level.get_world_2d().direct_space_state.intersect_ray(path_query).is_empty():
								continue
						if chair_wall_samples(image, anchor, sprite_scale, candidate, level.builder) > 0:
							continue
						if clear_chair_approaches(level,candidate) == 0:
							continue
						if chair_door_arc_hits(candidate, get_tree()) > 0:
							continue
						if chair_wall_samples(image, anchor, sprite_scale, candidate, level.builder) == 0:
							best_distance = shift.length_squared()
							position = candidate
			var sprite := Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(image)
			sprite.centered = false
			sprite.offset = -Vector2(frame.floor_anchor_px[0], frame.floor_anchor_px[1])
			sprite.scale = Vector2.ONE * float(contract.sprite_scale)
			sprite.position = position
			sprite.z_index = layer.z_index
			sprite.light_mask = layer.light_mask
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			level.add_child(sprite)
			var opaque := 0
			var over_walls := 0
			var footprint_query := PhysicsShapeQueryParameters2D.new()
			var footprint := RectangleShape2D.new()
			footprint.size = Vector2(.68, .65) * 16.0
			footprint_query.shape = footprint
			footprint_query.transform = Transform2D(0, position)
			footprint_query.collision_mask = Layers.WORLD | Layers.PROP
			var overlaps := level.get_world_2d().direct_space_state.intersect_shape(footprint_query)
			var nearest_door := INF
			var clear_passages := 0
			var clear_approaches := 0
			var approach_blockers: Array = []
			var paths := [[Vector2(-14, 14), Vector2(14, 14)],
				[Vector2(-14, -14), Vector2(14, -14)],
				[Vector2(-14, -14), Vector2(-14, 14)],
				[Vector2(14, -14), Vector2(14, 14)]]
			for path in paths:
				var start: Vector2 = position + path[0]
				var motion: Vector2 = path[1] - path[0]
				var transform := Transform2D(0, start)
				if not level.player.test_move(transform, Vector2.ZERO) and not level.player.test_move(transform, motion):
					clear_passages += 1
			# Solid legacy pieces reserve a larger collision rectangle. Stop at
			# its outside edge plus player radius/margin, not inside the chair.
			var approach_stop := 14.0
			if item[1] is Rect2 and bool(item[3]):
				approach_stop = maxf(14, maxf(item[1].size.x,item[1].size.y)*.5+9)
			for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var transform := Transform2D(0, position + direction * (approach_stop+16))
				if not level.player.test_move(transform, Vector2.ZERO) and not level.player.test_move(transform, -direction * 16):
					clear_approaches += 1
				else:
					var collision := KinematicCollision2D.new()
					level.player.test_move(transform, -direction * 16, collision)
					if collision.get_collider() != null:
						var collider := collision.get_collider() as Node2D
						approach_blockers.append({"name": str(collider.name), "class": collider.get_class(),
							"position": [collider.global_position.x, collider.global_position.y]})
			for door in get_tree().get_nodes_in_group("door"):
				if door is Door:
					nearest_door = minf(nearest_door, door.hit_point(position).distance_to(position))
			for y in range(0, 512, 4):
				for x in range(0, 512, 4):
					if image.get_pixel(x, y).a < .5:
						continue
					opaque += 1
					var point := sprite.to_global(sprite.offset + Vector2(x, y))
					if level.builder.ch(floori(point.x / 16), floori(point.y / 16)) == "#":
						over_walls += 1
			placement_report.append({"position": [position.x, position.y],
				"original_position": [original_position.x, original_position.y],
				"facing_index": facing, "opaque_samples": opaque,
				"physical_footprint_overlaps": overlaps.size(),
				"clear_player_side_passages": clear_passages,
				"clear_player_approaches": clear_approaches,
				"approach_stop_distance_px": approach_stop,
				"approach_blockers": approach_blockers,
				"reachable_door_arc_overlaps": chair_door_arc_hits(position, get_tree()),
				"nearest_door_leaf_px": nearest_door,
				"projected_wall_samples": over_walls,
				"scope": "projected silhouette, not physical footprint"})
			count += 1
		if changed:
			# This isolated review redraws the source layer, leaving its existing
			# collision bodies in place. Hide the corresponding old baked tiles.
			for tile in level.get_children():
				if tile is Sprite2D and str(tile.name).begins_with(str(layer.name) + "Baked"):
					tile.hide()
			layer.items = remaining
			layer.show()
			layer.queue_redraw()
	var report := FileAccess.open("res://build/m01_armchair_placement_review.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(placement_report, "  "))
	report.close()
	return count

func seated_bones(cast: CastModel) -> Dictionary:
	var skeleton := cast._skeleton
	var report := {}
	for side in ["Left", "Right"]:
		var indices := [skeleton.find_bone(side + "UpLeg"),
			skeleton.find_bone(side + "Leg"), skeleton.find_bone(side + "Foot")]
		if -1 in indices:
			report[side] = {"missing_bones": true}
			continue
		var hip := skeleton.to_global(skeleton.get_bone_global_pose(indices[0]).origin)
		var knee := skeleton.to_global(skeleton.get_bone_global_pose(indices[1]).origin)
		var ankle := skeleton.to_global(skeleton.get_bone_global_pose(indices[2]).origin)
		report[side] = {"knee_bend_degrees": rad_to_deg((knee - hip).angle_to(ankle - knee)),
			"hip_height_m": hip.y, "knee_height_m": knee.y, "ankle_height_m": ankle.y}
	return report

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_architecture_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 900:
		await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	var seat_review: Array = []
	for node in level.find_children("*", "Node2D", true, false):
		if node is IdleActivity and node.kind == IdleActivity.Kind.SNOOZE:
			var cast := node.visual.cast_sprite as CastModel
			seat_review.append({"position": [node.global_position.x, node.global_position.y],
				"palette": str(node.visual.palette),
				"doze_available": node.visual.has_clip("doze"),
				"selected_pose": node.visual.idle_activity_pose,
				"pose_override": node.visual.pose_override,
				"native_model": cast != null,
				"active_clip": cast.clip if cast else "",
				"move_speed": cast.move_speed if cast else 0,
				"clip_clock": cast.clock if cast else 0,
				"leg_geometry": seated_bones(cast) if cast else {},
				"pelvis_local_px": [cast.pelvis_point().x, cast.pelvis_point().y] if cast else []})
	var report := FileAccess.open("res://build/m01_seated_pose_diagnostics.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(seat_review, "  "))
	report.close()
	level.player.input_enabled = false
	level.player.set_physics_process(false)
	level.player.visual.update_move(Vector2.ZERO, 0)
	level.player.global_position = Vector2(400,352)
	for enemy in level.enemies:
		if enemy.visual._cast_velocity.length() > 0:
			print("M01_REVIEW_FREEZE: ", enemy.enemy_id, " state=", enemy.state_name(), " previous animation velocity=", enemy.visual._cast_velocity)
		enemy.set_physics_process(false)
		# Architecture review freezes locomotion but keeps breathing/activity
		# clips alive. Clear the last velocity so gait does not run in place.
		enemy.visual.update_move(Vector2.ZERO, 0)
	level.camera.set_process(false)
	level.camera.set_physics_process(false)
	level.camera.zoom = Vector2.ONE * 1.5
	level.camera.global_position = Vector2(470,260)
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_architecture_baseline.png")
	var image := Image.load_from_file("res://assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/ground_layer_candidate_v2.png")
	if image == null or image.get_size() != Vector2i(4352,3904):
		push_error("Invalid M01 ground layer image")
		SaveManager.data = saved
		SaveManager.save_path = saved_path
		Game.request_quit(1)
		return
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE * .25
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -9
	level.floor_root.add_child(sprite)
	var wall_image := Image.load_from_file("res://assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/wall_layer_candidate_v1.png")
	assert(wall_image.get_size() == Vector2i(2176, 1952))
	var wall_sprite := Sprite2D.new()
	wall_sprite.texture = ImageTexture.create_from_image(wall_image)
	wall_sprite.centered = false
	wall_sprite.scale = Vector2(.5, .5)
	wall_sprite.z_index = 6
	wall_sprite.light_mask = 1
	wall_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var hidden_chunks := 0
	for child in level.walls_root.get_children():
		if child is LevelBuilder.WallChunk:
			child.visible = false
			hidden_chunks += 1
	assert(hidden_chunks > 0)
	level.walls_root.add_child(wall_sprite)
	var door_review = load("res://tools/m01_door_projection_review.gd")
	var leaf_image := Image.load_from_file("res://assets/art/prerendered/m01_sunset_palms/staging/guest_door_v1/guest_door_leaf_topdown.png")
	var debris_image := Image.load_from_file("res://assets/art/prerendered/m01_sunset_palms/staging/guest_door_v1/guest_door_debris_topdown.png")
	assert(not leaf_image.is_empty() and not debris_image.is_empty())
	var leaf_texture := ImageTexture.create_from_image(leaf_image)
	var debris_texture := ImageTexture.create_from_image(debris_image)
	var replacements := 0
	for old in get_tree().get_nodes_in_group("door"):
		if not old is Door or old.metal:
			continue
		var replacement = door_review.ReviewDoor.new()
		replacement.texture = leaf_texture
		replacement.debris = debris_texture
		replacement.setup(old.position, old.length, old.closed_angle, old.locked)
		replacement.hp = old.hp
		replacement.swing = old.swing
		old.get_parent().add_child(replacement)
		replacement.set_physics_process(false)
		replacement._apply()
		old.queue_free()
		replacements += 1
	assert(replacements > 0)
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_wall_architecture_candidate.png")
	level.hud.hide()
	for child in level.get_children():
		if child is IntroCall:
			child.hide()
	level.camera.global_position = Vector2(390, 116)
	level.camera.zoom = Vector2(2.5, 2.5)
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_room_architecture_detail.png")
	var native := level.get_node_or_null("NativeM01Armchairs")
	var chairs: int = native.get_child_count() if native != null else preview_armchairs(level)
	assert(chairs > 0)
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_room_armchair_candidate.png")
	if native != null:
		print("M01_NATIVE_ARMCHAIR_MAP_REVIEW: ",chairs," integrated chairs retained during architecture preview")
	else:
		print("M01_ARMCHAIR_MAP_REVIEW: ", chairs, " visual replacements; existing collision unchanged; preview only")
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	print("M01_ARCHITECTURE_REVIEW: floor and ", replacements, " wooden doors captured; preview only")
	Game.request_quit(0)
