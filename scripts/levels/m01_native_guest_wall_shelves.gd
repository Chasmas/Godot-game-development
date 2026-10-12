class_name M01NativeGuestWallShelves
extends RefCounted

## Compact Blender shelf, books and flower pot on the upper free wall of a
## selection of guest rooms. It deliberately adds only a visual child: room
## layout, collisions, navigation and Door nodes remain authoritative.
const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/guest_wall_shelf_v1/"

static func build(level: Level, builder: LevelBuilder) -> void:
	if str(builder.data.get("id", "")) != "m01_sunset_palms": return
	var contract_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not contract_data is Dictionary or not bool(contract_data.get("runtime_approved", false)): return
	var filenames: Array = contract_data.get("files", [str(contract_data.get("file", ""))])
	var textures: Array[Texture2D] = []
	for filename in filenames:
		var texture := load(DIRECTORY + str(filename)) as Texture2D
		if texture == null: return
		textures.append(texture)
	if textures.is_empty(): return
	var rooms: Array = Dressing._find_rooms(builder).filter(func(room): return room.kind == "guest_room")
	var count := 0
	var placements: Array = []
	for room in rooms:
		if count >= int(contract_data.get("max_placements", 8)): break
		var at := _top_wall_anchor(builder, room)
		if at == Vector2.INF: continue
		var shelf := Sprite2D.new()
		shelf.name = "NativeM01GuestWallShelf_%d" % count
		var variant := count % textures.size()
		var selected_texture := textures[variant]
		shelf.texture = selected_texture
		shelf.position = at
		shelf.scale = Vector2.ONE * (float(contract_data.get("world_width_px", 20.0)) / float(selected_texture.get_width()))
		shelf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shelf.z_index = 7
		shelf.light_mask = 0
		shelf.set_meta("native_m01_guest_wall_shelf", true)
		shelf.set_meta("native_m01_guest_wall_shelf_variant", variant)
		level.add_child(shelf)
		placements.append([at.x, at.y])
		count += 1
	Engine.set_meta("m01_guest_wall_shelf_review", {"count": count, "placements": placements, "collision_added": false})

static func _top_wall_anchor(builder: LevelBuilder, room: Dressing.Room) -> Vector2:
	var choices: Array[Vector2i] = []
	for cell in room.cells:
		var above := builder.ch(cell.x, cell.y - 1)
		if above not in ["#", "W"]: continue
		# Keep clear of an upper doorway/window and choose from the authored wall.
		if builder.ch(cell.x - 1, cell.y - 1) in ["D", "W"] or builder.ch(cell.x + 1, cell.y - 1) in ["D", "W"]: continue
		choices.append(cell)
	if choices.is_empty(): return Vector2.INF
	choices.sort_custom(func(a, b): return absf(float(a.x) - room.rect.get_center().x) < absf(float(b.x) - room.rect.get_center().x))
	var c := choices[0]
	return Vector2(c.x * 16.0 + 8.0, c.y * 16.0 + 6.5)
