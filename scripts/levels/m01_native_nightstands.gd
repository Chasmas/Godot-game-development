class_name M01NativeNightstands
extends RefCounted

## Production M01 bedside cabinets.  The original dressing entries drive the
## positions; this module replaces their drawings with reviewed Blender frames
## and adds the same solid/nav footprint validated in the isolated review.

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/nightstand_v1/"

# This cabinet is framed as room dressing in a shallow wall recess.  Keeping
# the legacy sprite preserves the composition; adding a collision body there
# seals every approach lane, so it must stay visual-only.
const VISUAL_ONLY_POSITIONS := [Vector2(840,438)]

static func build(level: Level, layer: Dressing.ClutterLayer) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "runtime_contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved", false)): return
	var frame: Dictionary = contract.frames[0]
	var texture := load(DIRECTORY + str(frame.file)) as Texture2D
	if texture == null: return
	var remaining: Array = []
	var count := 0
	for item in layer.items:
		if str(item[0]) != "nightstand":
			remaining.append(item)
			continue
		var position: Vector2 = item[1]
		var original_position := position
		if original_position in VISUAL_ONLY_POSITIONS:
			remaining.append(item)
			continue
		# The 101 pair otherwise seals both sides of the bed in the nav grid.
		# Actual guard traversal and radius-clearance reviews validate this layout.
		if position in [Vector2(262, 440), Vector2(262, 488)]:
			var relocation := Vector2(-48 if position.y == 488 else -32, 0)
			position += relocation
			var room_pools := level.get_node_or_null("LightPools") as Dressing.ClutterLayer
			if room_pools != null:
				for pool in room_pools.items:
					if str(pool[0]) == "glow" and (pool[1] as Vector2).distance_to(original_position) < .01:
						pool[1] = position
			for light in level.get_tree().get_nodes_in_group("lights"):
				if light is Node2D and light.global_position.distance_to(original_position) < .01:
					light.global_position += relocation
		# These offsets are the validated, room-side placements from the
		# collision and door-clearance review.
		if position == Vector2(262, 600) or position == Vector2(790, 600):
			position += Vector2(-32, 0)
			var pools := level.get_node_or_null("LightPools") as Dressing.ClutterLayer
			if pools != null:
				for pool in pools.items:
					if str(pool[0]) == "glow" and (pool[1] as Vector2).distance_to(original_position) < .01:
						pool[1] = position
		if position == Vector2(808, 480):
			position += Vector2(0, 8)
			for light in level.get_tree().get_nodes_in_group("lights"):
				if light is Node2D and light.global_position.distance_to(original_position) < .01:
					light.global_position += Vector2(0, 8)
		var footprint := Vector2(contract.footprint_metres[0], contract.footprint_metres[1]) * 16.0
		var rectangle := RectangleShape2D.new()
		rectangle.size = footprint
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = rectangle
		query.transform = Transform2D(0, position)
		query.collision_mask = Layers.WORLD | Layers.LOW | Layers.PROP
		if not level.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			remaining.append(item)
			push_warning("M01 bedside cabinet blocked at %s; retaining legacy dressing" % position)
			continue
		var body := StaticBody2D.new()
		body.name = "NativeNightstand_%d" % count
		body.position = position
		body.collision_layer = Layers.LOW
		body.collision_mask = 0
		body.set_meta("native_nightstand", true)
		var shape := CollisionShape2D.new()
		shape.shape = rectangle
		body.add_child(shape)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.offset = -Vector2(frame.floor_anchor_px[0], frame.floor_anchor_px[1])
		sprite.scale = Vector2.ONE * 16.0 / float(contract.pixels_per_metre)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		body.add_child(sprite)
		body.z_index = -1
		level.props_root.add_child(body)
		var bounds := Rect2(position - footprint * .5, footprint)
		for y in range(floori(bounds.position.y / 16.0), ceili(bounds.end.y / 16.0)):
			for x in range(floori(bounds.position.x / 16.0), ceili(bounds.end.x / 16.0)):
				var cell := Vector2i(x, y)
				if level.nav.is_in_boundsv(cell): level.nav.set_point_solid(cell, true)
		count += 1
	layer.items = remaining
	if count != int(contract.expected_placements):
		push_warning("M01 native nightstands placed %d/%d reviewed cabinets" % [count, int(contract.expected_placements)])
