extends Node2D

func _ready() -> void:
	for vertical in [false, true]:
		var glass := GlassWindow.new()
		var origin := Vector2(100 if vertical else 0, 0)
		glass.setup(Rect2(origin, Vector2(4, 32) if vertical else Vector2(32, 4)))
		add_child(glass)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var normal := Vector2.RIGHT if vertical else Vector2.DOWN
		var centre := glass.global_position
		var query := PhysicsRayQueryParameters2D.create(centre - normal * 10,
			centre + normal * 10, Layers.GLASS)
		assert(not get_world_2d().direct_space_state.intersect_ray(query).is_empty())
		glass.shatter(normal.orthogonal())
		await get_tree().process_frame
		await get_tree().physics_frame
		assert(glass.broken and glass.collision_layer == Layers.LOW)
		assert(not glass.is_in_group("glass"))
		assert(get_world_2d().direct_space_state.intersect_ray(query).is_empty())
		var found := false
		for child in get_children():
			if child is WeaponPickup and child.global_position.distance_to(centre) < 20:
				assert(absf((child.global_position - centre).dot(normal)) >= 11)
				found = true
		assert(found)
	print("M01_WINDOW_INTERACTION: both orientations block then shatter; tangential shard drops clear of frame")
	get_tree().quit()
