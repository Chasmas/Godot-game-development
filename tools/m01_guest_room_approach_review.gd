extends Node

## Runtime-only preservation gate for approved M01 guest-room furniture.
## It does not load the Blender room study or change production visuals.

func _door_arc_hits(rect: Rect2) -> Array:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var hits: Array = []
	for node in get_tree().get_nodes_in_group("door"):
		if not node is Door or node.metal or node.broken:
			continue
		var door := node as Door
		var original := door.swing
		var hit := false
		for direction in [-1.0, 1.0]:
			for degrees in range(0, 101, 5):
				door.swing = deg_to_rad(float(degrees) * direction)
				# A blocked leaf cannot reach farther points on this arc.  Match the
				# production door solver instead of flagging impossible geometry.
				if door._leaf_blocked():
					break
				var leaf_start := door.global_position + door.leaf_dir()
				var leaf_end := door.global_position + door.leaf_dir() * (door.length - 1.0)
				if rect.has_point(leaf_start) or rect.has_point(leaf_end):
					hit = true
				for edge in 4:
					if Geometry2D.segment_intersects_segment(leaf_start, leaf_end, corners[edge], corners[(edge + 1) % 4]) != null:
						hit = true
		door.swing = original
		if hit:
			hits.append({"hinge":[door.global_position.x,door.global_position.y],"closed_angle":door.closed_angle})
	return hits

func _clear_approaches(level: Level, target: CollisionObject2D, position: Vector2, footprint: Vector2) -> int:
	var clear := 0
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		# This matches the production-furniture review's actual player sweep.
		# It proves that a player can stand in the adjacent lane and reach this
		# prop without an unrelated obstacle blocking the approach.
		var from := Transform2D(0, position + direction * 40.0)
		if level.player.test_move(from, Vector2.ZERO):
			continue
		var contact := KinematicCollision2D.new()
		if level.player.test_move(from, -direction * 40.0, contact) and contact.get_collider() == target:
			clear += 1
	return clear

func _record(level: Level, node: CollisionObject2D, shape: RectangleShape2D, label: String, rows: Array) -> void:
	var footprint := shape.size
	var rect := Rect2(node.global_position - footprint * .5, footprint)
	var approaches := _clear_approaches(level, node, node.global_position, footprint)
	var arc_doors := _door_arc_hits(rect)
	var arcs := arc_doors.size()
	if approaches == 0:
		print("M01 FURNITURE APPROACH BLOCKED kind=", label, " position=", node.global_position, " footprint=", footprint, " doors=", arc_doors)
	assert(approaches > 0, "%s must retain at least one usable player approach" % label)
	rows.append({"kind":label,"position":[node.global_position.x,node.global_position.y],
		"footprint_px":[footprint.x,footprint.y],"clear_player_approaches":approaches,"wooden_door_arc_overlaps":arcs,"blocking_door_hinges":arc_doors})

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://m01_guest_room_approach_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	for frame in 120:
		await get_tree().physics_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	assert(level != null)
	Dialogue._end(false)
	Dialogue.set_process(false)
	level.player.input_enabled = false
	level.player.set_physics_process(false)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	var rows: Array = []
	for item in get_tree().get_nodes_in_group("furniture"):
		if not item is Furniture or item.kind != "bed" or not level.is_ancestor_of(item):
			continue
		var bed := item as Furniture
		var bed_shape := bed.get_child(0) as CollisionShape2D
		assert(bed_shape != null and bed_shape.shape is RectangleShape2D)
		_record(level, bed, bed_shape.shape as RectangleShape2D, "bed", rows)
	for item in level.props_root.get_children():
		if not item is StaticBody2D or not (str(item.name).begins_with("NativeNightstand_") or str(item.name).begins_with("NativeDresser_")):
			continue
		var body := item as StaticBody2D
		var body_shape := body.get_child(0) as CollisionShape2D
		assert(body_shape != null and body_shape.shape is RectangleShape2D)
		_record(level, body, body_shape.shape as RectangleShape2D, "nightstand" if str(body.name).begins_with("NativeNightstand_") else "dresser", rows)
	var counts := {"bed":0,"nightstand":0,"dresser":0}
	for row in rows:
		counts[row.kind] = int(counts[row.kind]) + 1
	print("M01 GUEST ROOM PHYSICAL COUNTS: ", counts)
	# The damageable Room 101 TV is tested by its own composition contract.  This
	# furniture sweep counts the four independent native dresser bodies.
	assert(counts.bed == 10 and counts.nightstand == 12 and counts.dresser == 4)
	var arc_conflicts: Array = rows.filter(func(row): return int(row.wooden_door_arc_overlaps) > 0)
	var report := FileAccess.open("user://m01_guest_room_approach_review.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify({"passed":arc_conflicts.is_empty(),"counts":counts,"rows":rows,"door_arc_conflicts":arc_conflicts,
		"scope":"Production M01 bed, cabinet and dresser approach lanes and wooden-door swing clearance; staging guest-room art is not loaded."}, "  "))
	report.close()
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	Dialogue.set_process(true)
	print("M01 GUEST ROOM APPROACHES: 10 beds, 12 cabinets and 4 dresser bodies retain approach lanes; %d reachable door-arc conflicts" % arc_conflicts.size())
	Game.request_quit(0)
