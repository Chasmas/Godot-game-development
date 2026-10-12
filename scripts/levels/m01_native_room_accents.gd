class_name M01NativeRoomAccents
extends RefCounted

## Flat, readable guest-room story props.  These replace only like-for-like
## entries from Dressing, preserving the existing authored free cells, paths
## and all physical gameplay volumes.

const RUNTIME_DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/guest_room_props_v1/"
const STAGING_DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/staging/guest_room_props_v1/"
const PROP_MAP := {"suitcase":"suitcase", "shoes":"shoes", "tray":"tray", "clothes":"clothes", "towel":"towel"}

static func build(level: Level, builder: LevelBuilder, layer: Dressing.ClutterLayer) -> void:
	if str(builder.data.get("id", "")) != "m01_sunset_palms": return
	var review := Engine.has_meta("review_m01_room_accents")
	var directory := STAGING_DIRECTORY if review else RUNTIME_DIRECTORY
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory + "contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not review and not bool(contract.get("runtime_approved", false)): return
	if not review and str(contract.get("source_level_sha256", "")) != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"): return
	var items: Dictionary = contract.get("items", {})
	var textures := {}
	for kind in PROP_MAP.values():
		var descriptor: Dictionary = items.get(kind, {})
		var texture := load(directory + str(descriptor.get("file", ""))) as Texture2D
		if texture == null: return
		textures[kind] = texture
	var guest_rooms: Array = Dressing._find_rooms(builder).filter(func(room): return room.kind == "guest_room")
	var remaining: Array = []
	var placements: Array = []
	var count := 0
	for item in layer.items:
		var source_kind := str(item[0])
		if not PROP_MAP.has(source_kind):
			remaining.append(item)
			continue
		var visual_kind: String = PROP_MAP[source_kind]
		var descriptor: Dictionary = items[visual_kind]
		var scale := Vector2.ONE * float(descriptor.get("scale", 1.0))
		var rotation := float(item[2])
		var position := _fit_inside_guest_room(textures[visual_kind] as Texture2D, item[1], rotation, scale, guest_rooms)
		if position == Vector2.INF:
			remaining.append(item)
			continue
		var sprite := Sprite2D.new()
		sprite.name = ("CandidateGuestRoomAccent_" if review else "NativeGuestRoomAccent_") + "%s_%d" % [visual_kind, count]
		sprite.position = position
		sprite.rotation = rotation
		sprite.texture = textures[visual_kind]
		sprite.scale = scale
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = layer.z_index
		sprite.light_mask = layer.light_mask
		sprite.set_meta("accent_kind", visual_kind)
		sprite.set_meta("source_dressing_kind", source_kind)
		sprite.set_meta("staging_accent", review)
		level.add_child(sprite)
		placements.append({"kind": visual_kind, "source_kind": source_kind, "position": [sprite.position.x, sprite.position.y], "offset_from_dressing": [sprite.position.x-(item[1] as Vector2).x, sprite.position.y-(item[1] as Vector2).y], "rotation": sprite.rotation})
		count += 1
	layer.items = remaining
	Engine.set_meta("m01_guest_room_accent_review", {"count": count, "placements": placements, "staging": review})


static func _fit_inside_guest_room(texture: Texture2D, original: Vector2, rotation: float, scale: Vector2, guest_rooms: Array) -> Vector2:
	var room_cells: Array = []
	var anchor := Vector2i(floori(original.x / 16.0), floori(original.y / 16.0))
	for room in guest_rooms:
		if room.cells.has(anchor):
			room_cells = room.cells
			break
	if room_cells.is_empty(): return Vector2.INF
	var image: Image = texture.get_image()
	# Preserve the authored point whenever possible.  Nearby positions are
	# searched in one-pixel rings so a detailed edge never slips through a wall.
	for radius in range(0, 9):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius: continue
				var candidate := original + Vector2(dx, dy)
				if _alpha_is_inside_room(image, candidate, rotation, scale, room_cells): return candidate
	return Vector2.INF


static func _alpha_is_inside_room(image: Image, position: Vector2, rotation: float, scale: Vector2, room_cells: Array) -> bool:
	var centre := Vector2(image.get_size()) * .5
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < .05: continue
			var local := (Vector2(x + .5, y + .5) - centre) * scale
			var projected := position + local.rotated(rotation)
			var cell := Vector2i(floori(projected.x / 16.0), floori(projected.y / 16.0))
			if not room_cells.has(cell): return false
	return true
