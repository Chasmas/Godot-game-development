class_name M01NativeArmchairs
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/armchair_v1/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"runtime_contract.json"))
	if not bool(contract.get("runtime_approved",false)): return
	var root := Node2D.new()
	root.name = "NativeM01Armchairs"
	level.add_child(root)
	for layer in level.get_children():
		if not (layer is Dressing.ClutterLayer or layer is Furnish.FurnitureLayer): continue
		var remaining: Array = []
		for item in layer.items:
			if str(item[0]) != "armchair":
				remaining.append(item)
				continue
			var original: Vector2 = item[1].get_center() if item[1] is Rect2 else item[1]
			var placement: Dictionary = {}
			for entry in contract.placements:
				if original.distance_to(Vector2(entry.original_position[0],entry.original_position[1])) < .01:
					placement = entry
					break
			if placement.is_empty():
				remaining.append(item)
				continue
			var frame: Dictionary = contract.frames[int(placement.facing_index)]
			var texture := load(DIRECTORY+str(frame.file)) as Texture2D
			if texture == null:
				remaining.append(item)
				continue
			var sprite := Sprite2D.new()
			sprite.name = "Armchair_%d" % root.get_child_count()
			sprite.texture = texture
			sprite.centered = false
			sprite.offset = -Vector2(frame.floor_anchor_px[0],frame.floor_anchor_px[1])
			sprite.scale = Vector2.ONE*float(contract.sprite_scale)
			sprite.position = Vector2(placement.position[0],placement.position[1])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.z_index = layer.z_index
			sprite.light_mask = layer.light_mask
			sprite.set_meta("native_armchair",true)
			root.add_child(sprite)
			var collider: StaticBody2D = null
			for existing in level.props_root.get_children():
				if existing is StaticBody2D and existing.get_meta("furnish_id", "") == "armchair" and existing.position.distance_to(original) < .01:
					collider = existing
					break
			if collider == null:
				collider = StaticBody2D.new()
				collider.collision_layer = Layers.PROP
				collider.collision_mask = 0
				collider.set_meta("furnish_id", "armchair")
				collider.add_child(CollisionShape2D.new())
				level.props_root.add_child(collider)
			collider.position = sprite.position
			var shape := collider.get_child(0) as CollisionShape2D
			shape.shape = RectangleShape2D.new()
			shape.shape.size = Vector2(contract.collision_footprint_metres[0], contract.collision_footprint_metres[1]) * 16
			shape.rotation = -deg_to_rad(float(frame.rotation_degrees))
			shape.position = Vector2(contract.collision_center_metres[0], -contract.collision_center_metres[1]).rotated(shape.rotation) * 16
			collider.set_meta("native_armchair", true)
			# Reserve the same floor area for navigation as for physical movement.
			var bounds := Rect2(shape.to_global(-shape.shape.size * .5), Vector2.ZERO)
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				bounds = bounds.expand(shape.to_global(corner * shape.shape.size * .5))
			for y in range(floori(bounds.position.y / 16), floori(bounds.end.y / 16) + 1):
				for x in range(floori(bounds.position.x / 16), floori(bounds.end.x / 16) + 1):
					var cell := Vector2i(x, y)
					if level.nav != null and level.nav.is_in_boundsv(cell):
						level.nav.set_point_solid(cell, true)
						level.builder.solid_grid[y][x] = true
		layer.items = remaining
		layer.queue_redraw()

