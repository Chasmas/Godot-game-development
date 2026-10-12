class_name M01NativeGuestAirConditioners
extends RefCounted

## Replaces the small baked guest-room AC glyph with an in-place wall fixture.
## It is visual-only and retains Dressing's authored wall-facing anchors.

class GuestACVisual extends Node2D:
	func _draw() -> void:
		var r := Rect2(-6, -4, 12, 8)
		var ink := Color("1d2730")
		draw_rect(Rect2(r.position + Vector2(1, 1.5), r.size), Color(0.02, 0.03, 0.05, .35))
		draw_rect(r, Color("d6d0bf"))
		draw_rect(Rect2(-5, -3, 10, 2), Color("f0e7d2"))
		draw_rect(Rect2(-5, -.5, 10, 3.5), Color("98a9aa"))
		for y in 3:
			draw_line(Vector2(-4.3, .1 + y * .9), Vector2(2.2, .1 + y * .9), Color("40565f"), .65)
		draw_rect(Rect2(3.1, -.2, 1.3, 1.5), Color("63c8bf"))
		draw_circle(Vector2(3.75, 2.3), .7, Color("d39b52"))
		draw_line(Vector2(5, 3), Vector2(5.5, 5.5), Color("a3b8b4"), .7) # condensate drain
		draw_rect(r, ink, false, .8)

static func build(level: Level, builder: LevelBuilder, wall_layer: Dressing.ClutterLayer) -> void:
	if str(builder.data.get("id", "")) != "m01_sunset_palms": return
	var remaining: Array = []
	var count := 0
	for item in wall_layer.items:
		if str(item[0]) != "ac_unit":
			remaining.append(item)
			continue
		var unit := GuestACVisual.new()
		unit.name = "NativeM01GuestAC_%d" % count
		unit.position = item[1]
		unit.rotation = float(item[2])
		unit.z_index = wall_layer.z_index
		unit.light_mask = wall_layer.light_mask
		unit.set_meta("native_guest_ac", true)
		level.add_child(unit)
		count += 1
	wall_layer.items = remaining
	Engine.set_meta("m01_guest_ac_review", {"count": count, "collision_added": false})
	print("M01 native guest AC fixtures: ", count)
