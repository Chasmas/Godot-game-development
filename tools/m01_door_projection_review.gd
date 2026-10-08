extends Node2D
## Isolated projection review using the production Door physics implementation.

class ReviewDoor extends Door:
	var texture: Texture2D
	var debris: Texture2D
	func _draw() -> void:
		if broken and debris != null:
			var factor := length / 275.2
			draw_set_transform(Vector2.ZERO, closed_angle, Vector2.ONE)
			draw_texture_rect(debris, Rect2(Vector2(-54.4, -32) * factor,
				Vector2(384, 384) * factor), false)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			return
		if texture == null:
			return
		var factor := length / 275.2
		draw_set_transform(Vector2.ZERO, closed_angle + swing, Vector2.ONE)
		draw_texture_rect(texture, Rect2(Vector2(-54.4, -96) * factor,
			Vector2(384, 192) * factor), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 0.7, Color.CYAN)

func _ready() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/art/prerendered/m01_sunset_palms/staging/guest_door_v1/guest_door_leaf_topdown.png"))
	assert(not image.is_empty())
	var texture := ImageTexture.create_from_image(image)
	var debris_image := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/art/prerendered/m01_sunset_palms/staging/guest_door_v1/guest_door_debris_topdown.png"))
	assert(not debris_image.is_empty())
	var debris_texture := ImageTexture.create_from_image(debris_image)
	var reviewed_doors: Array[ReviewDoor] = []
	var camera := Camera2D.new()
	camera.position = Vector2(90, 50)
	camera.zoom = Vector2(5, 5)
	add_child(camera)
	for index in 3:
		var door := ReviewDoor.new()
		door.texture = texture
		door.debris = debris_texture
		door.setup(Vector2(35 + index * 55, 50), 32, 0)
		add_child(door)
		reviewed_doors.append(door)
		door.set_physics_process(false)
		door.swing = deg_to_rad([0, 45, 85][index])
		door._apply()
		assert(is_equal_approx(door.leaf.rotation, door.swing))
		assert(door.hit_point(door.global_position + door.leaf_dir() * 100).distance_to(
			door.global_position + door.leaf_dir() * 32) < 0.001)
		var label := Label.new()
		label.text = str([0, 45, 85][index]) + " degrees"
		label.position = door.position + Vector2(-5, -20)
		label.scale = Vector2(.2, .2)
		add_child(label)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image()
	result.save_png(ProjectSettings.globalize_path("res://build/m01_door_projection_review.png"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	for door in reviewed_doors:
		var centre := door.global_position + door.leaf_dir() * 16
		var normal := door.leaf_dir().orthogonal()
		var query := PhysicsRayQueryParameters2D.create(centre - normal * 10,
			centre + normal * 10, Layers.DOOR)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty() and hit.collider == door.leaf)
	var target := reviewed_doors[0]
	target.locked = true
	await get_tree().physics_frame
	var centre := target.global_position + Vector2(16, 0)
	var world_ray := PhysicsRayQueryParameters2D.create(centre - Vector2(0, 10),
		centre + Vector2(0, 10), Layers.WORLD)
	assert(not get_world_2d().direct_space_state.intersect_ray(world_ray).is_empty())
	target.unlock()
	await get_tree().physics_frame
	assert(get_world_2d().direct_space_state.intersect_ray(world_ray).is_empty())
	var damage := DamageInfo.new()
	damage.type = DamageInfo.Type.BALLISTIC
	damage.weapon_id = &"pistol"
	damage.pos = centre
	damage.dir = Vector2.DOWN
	for count in 4:
		assert(target.take_damage(damage) == "blocked")
	assert(target.take_damage(damage) == "pass")
	assert(target.broken and target.leaf.collision_layer == 0)
	assert(not target.is_in_group("damageable"))
	assert(target.take_damage(damage) == "pass")
	await get_tree().physics_frame
	var broken_ray := PhysicsRayQueryParameters2D.create(centre - Vector2(0, 10),
		centre + Vector2(0, 10), Layers.DOOR)
	assert(get_world_2d().direct_space_state.intersect_ray(broken_ray).is_empty())
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(
		"res://build/m01_door_destroyed_godot_review.png"))
	print("M01_DOOR_PROJECTION: 3 angles; collider rotation and leaf endpoints verified; preview only")
	print("M01_DOOR_INTERACTION: rays at 3 angles; locked world blocker, unlock and 5-hit destruction verified")
	get_tree().quit()
