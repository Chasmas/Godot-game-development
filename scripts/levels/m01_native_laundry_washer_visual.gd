class_name M01NativeLaundryWasherVisual
extends Node2D

## Visual-only face for the existing M01 laundry washer furniture.
var rect_size := Vector2(32.0, 16.0)
var machine_index := 0

func _draw() -> void:
	var r := Rect2(-rect_size * .5 + Vector2.ONE, rect_size - Vector2(2.0, 2.0))
	var ink := Color("25303a")
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0.02, 0.04, 0.06, .34))
	draw_rect(r, Color("d4d1c1"))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 3)), Color("f5eedb"))
	draw_rect(Rect2(r.position + Vector2(1, r.size.y - 3), Vector2(r.size.x - 2, 2)), Color("88939a"))
	# Two distinct front-loaders inhabit the authored two-cell furniture piece.
	var machine_w := (r.size.x - 4.0) * .5
	for i in 2:
		var m := Rect2(r.position + Vector2(2.0 + i * machine_w, 4.5), Vector2(machine_w - 1.5, r.size.y - 8.0))
		draw_rect(m, Color("e9e3d3"))
		draw_rect(m, Color("66747b"), false, 1.0)
		var drum := Vector2(m.get_center().x, m.position.y + m.size.y * .58)
		draw_circle(drum + Vector2(1, 1), minf(m.size.x, m.size.y) * .30, Color(0.16, 0.21, 0.25, .55))
		draw_circle(drum, minf(m.size.x, m.size.y) * .30, Color("536b74"))
		draw_circle(drum, minf(m.size.x, m.size.y) * .22, Color("253846"))
		draw_arc(drum, minf(m.size.x, m.size.y) * .17, -2.4, -.4, 8, Color("8ee5e7"), 1.0)
		draw_circle(Vector2(m.position.x + 3, m.position.y + 1.7), .9, Color("cf7b4e"))
		draw_rect(Rect2(m.position + Vector2(m.size.x - 4, 1), Vector2(2.5, 1.5)), Color("60c9c4"))
	# Folded linen lives on one top edge and makes the service room readable.
	if machine_index == 0:
		draw_rect(Rect2(r.position + Vector2(3, -1), Vector2(7, 2)), Color("e7aa7c"))
		draw_rect(Rect2(r.position + Vector2(4, -2.5), Vector2(5, 1.7)), Color("79b5b4"))
	else:
		draw_rect(Rect2(r.end - Vector2(10, 1), Vector2(7, 2)), Color("c8c1a7"))
		draw_rect(Rect2(r.end - Vector2(9, 3), Vector2(5, 1.7)), Color("d78667"))
	draw_rect(r, ink, false, 1.0)
