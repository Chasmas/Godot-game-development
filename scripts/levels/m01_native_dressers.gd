class_name M01NativeDressers
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/tv_dresser_v1/"
const POSITIONS := {
	Vector2(235,72):Vector2(219,88),
	Vector2(1051,72):Vector2(1051,64),
	Vector2(824,491):Vector2(784,491),
}

# These two authored dressers sit in architectural recesses.  Their original
# drawings remain in Dressing, but a solid replacement leaves no valid player
# approach from any direction.  Do not promote them to navigation/collision.
const VISUAL_ONLY_POSITIONS := [Vector2(360,437), Vector2(843,632)]

static func _place(level: Level, position: Vector2, rotation: float, contract: Dictionary, index: int, television: BreakableProp = null) -> bool:
	var facing := posmod(roundi(rotation / (PI * .5)), 4)
	var frame: Dictionary = contract.frames[facing]
	var texture := load(DIRECTORY + str(frame.file)) as Texture2D
	if texture == null: return false
	var footprint := Vector2(contract.footprint_metres[0], contract.footprint_metres[1]) * 16.0
	if facing % 2 == 1: footprint = Vector2(footprint.y, footprint.x)
	var rectangle := RectangleShape2D.new()
	rectangle.size = footprint
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rectangle
	query.transform = Transform2D(0, position)
	query.collision_mask = Layers.WORLD | Layers.LOW | Layers.PROP
	if television != null: query.exclude = [television.get_rid()]
	if not level.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
		push_warning("M01 dresser blocked at %s; retaining legacy drawing" % position)
		return false
	var body: StaticBody2D = television if television != null else StaticBody2D.new()
	if television == null: body.name = "NativeDresser_%d" % index
	body.position = position
	body.collision_layer = Layers.PROP if television != null else Layers.LOW
	body.collision_mask = 0
	body.set_meta("native_dresser", true)
	var collision := CollisionShape2D.new()
	collision.shape = rectangle
	if television != null:
		for old_shape in body.find_children("*", "CollisionShape2D", false, false):
			old_shape.disabled = true
			old_shape.queue_free()
		television.size = footprint
		television.hit_radius = maxf(footprint.x, footprint.y) * .5
		television.set_meta("native_tv_dresser", true)
		television.queue_redraw()
	body.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.offset = -Vector2(frame.floor_anchor_px[0], frame.floor_anchor_px[1])
	sprite.scale = Vector2.ONE * 16.0 / float(contract.pixels_per_metre)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	# North-wall cabinet projects upward in front of that wall's decorative face.
	body.z_index = 8 if television != null else 0
	if not frame.screen_polygon_px.is_empty():
		var points := PackedVector2Array()
		for point in frame.screen_polygon_px: points.append(Vector2(point[0], point[1]))
		var panel := Polygon2D.new()
		panel.polygon = points
		panel.position = sprite.offset * sprite.scale
		panel.scale = sprite.scale
		var low := points[0]
		var high := points[0]
		for point in points:
			low = low.min(point)
			high = high.max(point)
		var uv := PackedVector2Array()
		for point in points: uv.append((point - low) / (high - low))
		panel.uv = uv
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/art/prerendered/m01_sunset_palms/runtime/crt_static.gdshader")
		material.set_shader_parameter("grain_source", load("res://assets/art/materials/m01/batch_v1/rubber_albedo.png"))
		material.set_shader_parameter("strength", 1.0)
		panel.material = material
		body.add_child(panel)
		if television != null:
			television.broken.connect(func(_prop: BreakableProp): material.set_shader_parameter("strength", 0.0))
	if television == null: level.props_root.add_child(body)
	var bounds := Rect2(position - footprint * .5, footprint)
	for y in range(floori(bounds.position.y / 16.0), ceili(bounds.end.y / 16.0)):
		for x in range(floori(bounds.position.x / 16.0), ceili(bounds.end.x / 16.0)):
			var cell := Vector2i(x, y)
			if level.nav.is_in_boundsv(cell): level.nav.set_point_solid(cell, true)
	return true

static func build(level: Level, layer: Dressing.ClutterLayer) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "runtime_contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved", false)): return
	# Room101's existing damageable TV becomes the north-facing TV/cabinet.
	# Preserve its identity, damage signals and debris instead of adding a duplicate.
	for prop in level.props_root.get_children():
		if prop is BreakableProp and prop.kind == "tv" and prop.position.distance_to(Vector2(200,488)) < .01:
			if _place(level, Vector2(200,440), 0.0, contract, 101, prop):
				var old_cell := Vector2i(12,30)
				level.nav.set_point_solid(old_cell, false)
				level.builder.solid_grid[old_cell.y][old_cell.x] = false
	var remaining: Array = []
	var index := 0
	for item in layer.items:
		if str(item[0]) != "dresser_tv":
			remaining.append(item)
			continue
		var original: Vector2 = item[1]
		if original in VISUAL_ONLY_POSITIONS:
			remaining.append(item)
			continue
		if not POSITIONS.has(original):
			remaining.append(item)
			continue
		var rotation := PI if original == Vector2(843,632) else float(item[2])
		if original == Vector2(360,437): rotation = 0.0
		if _place(level, POSITIONS[original], rotation, contract, index):
			index += 1
		else:
			remaining.append(item)
	for child in level.get_node("Decor").get_children():
		if not (child is Sprite2D and child.get_meta("decor_asset_id", "") == "hq_motel_dresser"): continue
		if child.position.distance_to(Vector2(552,48.64)) < .01 and _place(level, Vector2(552,56.64), 0.0, contract, index):
			child.hide()
			index += 1
	layer.items = remaining
	if index != int(contract.expected_placements):
		push_warning("M01 native dressers placed %d/%d reviewed cabinets" % [index, int(contract.expected_placements)])
