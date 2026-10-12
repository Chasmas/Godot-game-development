extends Node2D

## Fixed wall dressing for the M01 front desk.  It intentionally has no
## physics body: the wall and door geometry remain authoritative.

func _draw() -> void:
	var ink := Color("211923")
	# Walnut key/mail cubbies on the wall immediately behind the counter.
	var board := Rect2(-25, -8, 50, 15)
	draw_rect(Rect2(board.position + Vector2(1, 2), board.size), Color(0.02, 0.01, 0.03, .35))
	draw_rect(board, Color("563522"))
	draw_rect(board.grow(-1), Color("8c5633"))
	for y in 2:
		for x in 6:
			var slot := Rect2(board.position + Vector2(3 + x * 7.4, 2 + y * 5.5), Vector2(5.4, 3.2))
			draw_rect(slot, Color("2a1c20"))
			if (x + y * 3) % 3 != 0:
				draw_circle(slot.get_center() + Vector2(1.1, .2), .75, Color("d9ad4d"))
	# Desk sign and a compact arrivals card make the space legible at close zoom.
	var sign := Rect2(-48, -5, 17, 10)
	draw_rect(sign, Color("d9c9a7"))
	draw_rect(sign.grow(-1), Color("284556"))
	draw_string(UIStyle.font_bold(), sign.position + Vector2(2, 6.5), "KEYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color("f5e8c9"))
	var card := Rect2(32, -5, 14, 10)
	draw_rect(card, Color("ead8b6"))
	for y in 3: draw_line(card.position + Vector2(2, 2 + y * 2), card.end - Vector2(2, 8 - y * 2), Color("b76c52"), .7)
	draw_rect(board, ink, false, 1.0)
	draw_rect(sign, ink, false, .8)
	draw_rect(card, ink, false, .8)

