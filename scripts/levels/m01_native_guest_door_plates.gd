class_name M01NativeGuestDoorPlates
extends RefCounted

## Replaces existing M01 room-number glyphs at their authored wall anchors.
## These plaques do not touch Door nodes, collision, or the swing solver.

class GuestDoorPlate extends Node2D:
	var room_number := 0
	func _draw() -> void:
		var plate := Rect2(-6.5, -4.5, 13, 8)
		var ink := Color("1b2027")
		draw_rect(Rect2(plate.position + Vector2(1, 1.5), plate.size), Color(0.01, 0.02, 0.04, .3))
		draw_rect(plate, Color("b78a46"))
		draw_rect(plate.grow(-1), Color("204858"))
		draw_circle(plate.position + Vector2(1.6, 1.6), .55, Color("dfbd6b"))
		draw_circle(plate.position + Vector2(plate.size.x - 1.6, 1.6), .55, Color("dfbd6b"))
		draw_circle(plate.position + Vector2(1.6, plate.size.y - 1.6), .55, Color("dfbd6b"))
		draw_circle(plate.position + Vector2(plate.size.x - 1.6, plate.size.y - 1.6), .55, Color("dfbd6b"))
		draw_string(UIStyle.font_bold(), Vector2(-4.6, 2.6), "%03d" % room_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("f5e5be"))
		draw_rect(plate, ink, false, .8)

static func build(level: Level, builder: LevelBuilder, wall_layer: Dressing.ClutterLayer) -> void:
	if str(builder.data.get("id", "")) != "m01_sunset_palms": return
	var remaining: Array = []
	var count := 0
	for item in wall_layer.items:
		if str(item[0]) != "room_no":
			remaining.append(item)
			continue
		var plaque := GuestDoorPlate.new()
		plaque.name = "NativeM01GuestDoorPlate_%d" % count
		plaque.position = item[1]
		plaque.rotation = float(item[2])
		plaque.room_number = int(item[3])
		plaque.z_index = wall_layer.z_index
		plaque.light_mask = wall_layer.light_mask
		plaque.set_meta("native_guest_door_plate", true)
		plaque.set_meta("room_number", plaque.room_number)
		level.add_child(plaque)
		count += 1
	wall_layer.items = remaining
	Engine.set_meta("m01_guest_door_plate_review", {"count": count, "collision_added": false})
	print("M01 native guest door plates: ", count)
