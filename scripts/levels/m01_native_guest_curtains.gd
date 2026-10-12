class_name M01NativeGuestCurtains
extends RefCounted

## Curtains are attached to the existing breakable window bodies.  They add no
## floor collision and disappear with the intact pane when it shatters.

const RUNTIME_DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/guest_curtain_v1/"
const STAGING_DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/staging/guest_curtain_v1/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var review := Engine.has_meta("review_m01_guest_curtains")
	var directory := STAGING_DIRECTORY if review else RUNTIME_DIRECTORY
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory + "contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not review and not bool(contract.get("runtime_approved", false)): return
	if not review and str(contract.get("source_level_sha256", "")) != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"): return
	var texture := load(directory + str(contract.get("file", ""))) as Texture2D
	if texture == null: return
	var guest_rooms: Array = Dressing._find_rooms(level.builder).filter(func(room): return room.kind == "guest_room")
	var count := 0
	var rows: Array = []
	for node in level.props_root.get_children():
		if not node is GlassWindow: continue
		var window := node as GlassWindow
		if window.size.x < window.size.y or window.has_node("NativeM01GuestCurtains"): continue
		var room_side := _guest_side(window, guest_rooms)
		if room_side == 0: continue
		var dressing := Node2D.new()
		dressing.name = "NativeM01GuestCurtains"
		dressing.z_index = 1
		dressing.set_meta("guest_curtain_staging", review)
		dressing.set_meta("guest_curtain_room_side", room_side)
		for panel_side in [-1.0, 1.0]:
			var sprite := Sprite2D.new()
			sprite.name = "CurtainPanel"
			sprite.texture = texture
			sprite.scale = Vector2.ONE * float(contract.get("scale", 1.0))
			# The GlassWindow body sits in the exterior wall cell.  Mount the
			# fabric on the room-facing wall band, beyond that cell, so neither
			# panel leaks over the glass frame or out of the playable room.
			sprite.position = Vector2(panel_side * (window.size.x * .5 - 3.0), room_side * (window.size.y * .5 + 14.0))
			sprite.flip_h = panel_side < 0.0
			sprite.flip_v = room_side < 0.0
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.light_mask = window.light_mask
			dressing.add_child(sprite)
		window.add_child(dressing)
		rows.append({"position": [window.global_position.x, window.global_position.y], "size_px": [window.size.x, window.size.y], "guest_room_side": room_side})
		count += 1
	Engine.set_meta("m01_guest_curtain_review", {"count": count, "windows": rows, "staging": review})


static func _guest_side(window: GlassWindow, guest_rooms: Array) -> float:
	for distance in [8.0, 16.0, 24.0]:
		for side in [-1.0, 1.0]:
			var p := window.global_position + Vector2(0, side * (window.size.y * .5 + distance))
			var cell := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
			for room in guest_rooms:
				if room.cells.has(cell): return side
	return 0.0
