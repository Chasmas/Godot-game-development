class_name M01NativeOfficeDeskVisual
extends Node2D

## Detailed top-down manager desk face for the original M01 Furniture body.
var rect_size := Vector2(48.0, 16.0)

func _draw() -> void:
	var r := Rect2(-rect_size * .5 + Vector2.ONE, rect_size - Vector2(2.0, 2.0))
	var ink := Color("211923")
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0.02, 0.01, 0.03, .36))
	draw_rect(r, Color("4b2e20"))
	draw_rect(r.grow(-1.2), Color("795038"))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 3.5)), Color("ba875d"))
	draw_line(r.position + Vector2(2, 4.5), Vector2(r.end.x - 2, r.position.y + 4.5), Color("d4a66d"), 1.0)
	# Side drawers and their brass pulls communicate an actual manager's desk.
	for x in [3.0, r.size.x - 11.0]:
		for y in 3:
			var drawer := Rect2(r.position + Vector2(x, 6 + y * 2.2), Vector2(8, 1.6))
			draw_rect(drawer, Color("542f22"))
			draw_circle(drawer.get_center(), .55, Color("d8ad4d"))
	# CRT security monitor with a green image and a keypad, a rotary phone,
	# ledger, and warm task lamp on the top surface.
	var monitor := Rect2(r.get_center() + Vector2(-7, -1), Vector2(10, 5))
	draw_rect(monitor, Color("242936"))
	draw_rect(monitor.grow(-1), Color("5ec6b3"))
	draw_rect(Rect2(monitor.position + Vector2(3.5, 5), Vector2(3, 1.5)), Color("32333b"))
	var phone := r.position + Vector2(17, 7)
	draw_circle(phone, 2.6, Color("ded4bd"))
	draw_circle(phone, 1.5, Color("4c5561"))
	for angle in 6: draw_circle(phone + Vector2.from_angle(float(angle) * TAU / 6.0) * .85, .25, Color("e8dfc9"))
	var ledger := Rect2(r.position + Vector2(r.size.x - 14, 6), Vector2(7, 4))
	draw_rect(ledger, Color("d9c6a6"))
	for y in 2: draw_line(ledger.position + Vector2(1, 1 + y * 1.2), ledger.end - Vector2(1, 3 - y * 1.2), Color("a75e46"), .6)
	var lamp := r.position + Vector2(8, 7)
	draw_line(lamp + Vector2(0, 3), lamp + Vector2(1, -1), Color("d8ad4d"), 1.0)
	draw_circle(lamp + Vector2(1, -2), 2.0, Color("ffd686"))
	draw_circle(lamp + Vector2(1, -2), 1.2, Color("fff1bd"))
	draw_rect(r, ink, false, 1.0)
