class_name M01NativeReceptionCounterVisual
extends Node2D

## Decorative face for the existing M01 lobby counter.  Its parent remains the
## original Furniture body, so this node deliberately owns no collision.

var rect_size := Vector2(16.0, 16.0)
var segment_index := 0

func _draw() -> void:
	var r := Rect2(-rect_size * .5 + Vector2.ONE, rect_size - Vector2(2.0, 2.0))
	var ink := Color("211923")
	# A broad, soft shadow makes the service desk feel anchored without changing
	# the low-cover silhouette that the player navigates around.
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0.03, 0.015, 0.04, .38))
	draw_rect(r, Color("563522"))
	draw_rect(Rect2(r.position + Vector2(1, 2), Vector2(r.size.x - 2, r.size.y - 4)), Color("75462b"))
	# Cream stone service top and its brass/copper lip.
	draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(r.size.x, minf(4.0, r.size.y))), Color("e9d7bc"))
	draw_line(r.position + Vector2(1, 4), Vector2(r.end.x - 1, r.position.y + 4), Color("b98644"), 1.0)
	draw_line(r.position + Vector2(1, r.end.y - 2), Vector2(r.end.x - 1, r.end.y - 2), Color("b98644"), 1.0)
	# Cabinet-panel seams and varnished grain keep long runs from becoming a flat
	# block at game zoom.
	if rect_size.x >= rect_size.y:
		for x in range(5, int(r.size.x), 8):
			draw_line(Vector2(r.position.x + x, r.position.y + 5), Vector2(r.position.x + x, r.end.y - 3), Color("3f251a"), 1.0)
			draw_line(Vector2(r.position.x + x + 1, r.position.y + 6), Vector2(r.position.x + x + 1, r.end.y - 4), Color("9a6038"), 1.0)
		for x in range(3, int(r.size.x), 7):
			draw_line(Vector2(r.position.x + x, r.position.y + 7), Vector2(r.position.x + minf(x + 3, r.size.x - 2), r.position.y + 7), Color("ad7042"), .6)
	else:
		for y in range(6, int(r.size.y), 8):
			draw_line(Vector2(r.position.x + 2, r.position.y + y), Vector2(r.end.x - 2, r.position.y + y), Color("3f251a"), 1.0)
			draw_line(Vector2(r.position.x + 3, r.position.y + y + 1), Vector2(r.end.x - 3, r.position.y + y + 1), Color("9a6038"), 1.0)
	# Reception tools live on the counter rather than on a new floor prop.
	var c := r.get_center()
	if segment_index == 0 or segment_index == 2:
		draw_rect(Rect2(c + Vector2(-5, -2), Vector2(7, 3)), Color("282937")) # register
		draw_rect(Rect2(c + Vector2(-4, -1.5), Vector2(5, .8)), Color("72d9bc"))
		draw_circle(c + Vector2(5, 0), 1.8, Color("d8ad4d")) # bell
		draw_circle(c + Vector2(5, 0), .8, Color("fff3be"))
	elif segment_index == 1:
		draw_rect(Rect2(c + Vector2(-5, -2), Vector2(9, 3)), Color("d9c6a6")) # guest ledger
		draw_line(c + Vector2(-3, -1), c + Vector2(-3, .5), Color("a25c43"), 1.0)
		draw_line(c + Vector2(0, -1), c + Vector2(0, .5), Color("a25c43"), 1.0)
		draw_circle(c + Vector2(5, 0), 1.3, Color("384b63")) # key bowl
	else:
		draw_rect(Rect2(c + Vector2(-4, -2), Vector2(5, 3)), Color("d9c6a6"))
		draw_circle(c + Vector2(4, 0), 1.5, Color("a55b35")) # coffee cup
	draw_rect(r, ink, false, 1.0)
