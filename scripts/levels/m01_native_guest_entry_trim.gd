class_name M01NativeGuestEntryTrim
extends RefCounted

## Fixed motel-room threshold and jamb dressing.  It mounts beside the live
## Door rather than replacing it, so the swing leaf and its collision remain
## the authoritative gameplay object.

class EntryTrim extends Node2D:
	var door_length := 16.0
	var closed_angle := 0.0
	var guest_side := 1.0
	func _draw() -> void:
		var ink := Color("17141b")
		var brass := Color("b88743")
		var paint := Color("42616a")
		draw_set_transform(Vector2.ZERO, closed_angle)
		# A slim sill stays under the swinging leaf.  It gives the guest-room
		# entrance a readable transition without changing the opening itself.
		var y := guest_side * 3.2
		draw_line(Vector2(1.5, y + 1.0), Vector2(door_length - 1.5, y + 1.0), Color(0.01, 0.01, 0.02, .45), 2.5)
		draw_line(Vector2(1.5, y), Vector2(door_length - 1.5, y), brass.darkened(.28), 1.8)
		draw_line(Vector2(2.0, y - guest_side * .6), Vector2(door_length - 2.0, y - guest_side * .6), brass, .55)
		# Painted steel jamb caps distinguish the motel-room edge from the
		# generic corridor wall and stay in place as the door swings or breaks.
		for x in [0.0, door_length]:
			draw_line(Vector2(x, -5.2), Vector2(x, 5.2), ink, 2.2)
			draw_line(Vector2(x + (1.0 if x == 0.0 else -1.0), -4.3), Vector2(x + (1.0 if x == 0.0 else -1.0), 4.3), paint, .8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func build(level: Level, builder: LevelBuilder) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var guest_cells := {}
	for room in Dressing._find_rooms(builder):
		if room.kind != "guest_room": continue
		for cell in room.cells: guest_cells[cell] = true
	var count := 0
	var rows: Array = []
	for node in level.doors_root.get_children():
		if not node is Door: continue
		var door := node as Door
		if door.metal or door.has_node("NativeM01GuestEntryTrim"): continue
		var side := _guest_side(door, guest_cells)
		if side == 0.0: continue
		var trim := EntryTrim.new()
		trim.name = "NativeM01GuestEntryTrim"
		trim.door_length = door.length
		trim.closed_angle = door.closed_angle
		trim.guest_side = side
		trim.z_index = door.z_index - 1
		trim.light_mask = door.light_mask
		trim.set_meta("native_guest_entry_trim", true)
		trim.set_meta("guest_room_side", side)
		door.add_child(trim)
		rows.append({"position": [door.position.x, door.position.y], "length_px": door.length, "guest_room_side": side})
		count += 1
	Engine.set_meta("m01_guest_entry_trim_review", {"count": count, "doors": rows, "collision_added": false})

static func _guest_side(door: Door, guest_cells: Dictionary) -> float:
	var normal := Vector2.from_angle(door.closed_angle).orthogonal()
	var cell_count := roundi(door.length / 16.0)
	for i in cell_count:
		var door_cell := Vector2i(roundi(door.position.x / 16.0) + i, roundi(door.position.y / 16.0 - .5)) if absf(sin(door.closed_angle)) < .5 else Vector2i(roundi(door.position.x / 16.0 - .5), roundi(door.position.y / 16.0) + i)
		for neighbour in [door_cell + Vector2i.UP, door_cell + Vector2i.DOWN, door_cell + Vector2i.LEFT, door_cell + Vector2i.RIGHT]:
			if not guest_cells.has(neighbour): continue
			var offset := Vector2(neighbour * 16 + Vector2i(8, 8)) - (door.position + Vector2.from_angle(door.closed_angle) * door.length * .5)
			return 1.0 if offset.dot(normal) >= 0.0 else -1.0
	return 0.0
