class_name UpgradeIcon
extends RefCounted
## Drawn icons for the mission upgrades: one small illustration per upgrade
## instead of a two-letter code. Vector-drawn so the same art works as a
## 10 px hologram over a briefcase, a HUD badge and a big pickup card.
##
## draw(ci, id, centre, size, colour, t): `size` is the icon's full width;
## `t` animates the moving bits (beam, pulse, sparkle).

const INK := Color("0b0710")

static func draw(ci: CanvasItem, id: StringName, c: Vector2, size: float, col: Color, t := 0.0) -> void:
	var u := size / 24.0          # the art is authored on a 24x24 grid
	var hi := col.lightened(0.45)
	var lo := col.darkened(0.45)
	var w := maxf(1.0, 1.6 * u)
	match id:
		&"laser":
			# pistol in profile, beam out of the muzzle, a dot where it lands
			_poly(ci, c, u, [Vector2(-10, -3), Vector2(3, -3), Vector2(3, 0), Vector2(-3, 0), Vector2(-4, 6), Vector2(-8, 6), Vector2(-7, 0), Vector2(-10, 0)], lo, INK, w)
			_poly(ci, c, u, [Vector2(-10, -3), Vector2(3, -3), Vector2(3, -1.5), Vector2(-10, -1.5)], hi, Color(0, 0, 0, 0), 0)
			var flick := 0.75 + 0.25 * sin(t * 30.0)
			ci.draw_line(c + Vector2(3, -1.5) * u, c + Vector2(11, -1.5) * u, Color(col, 0.35 * flick), 3.0 * u)
			ci.draw_line(c + Vector2(3, -1.5) * u, c + Vector2(11, -1.5) * u, Color(1, 0.8, 0.8, flick), maxf(1.0, u))
			ci.draw_circle(c + Vector2(11, -1.5) * u, 2.2 * u, Color(col, 0.5))
			ci.draw_circle(c + Vector2(11, -1.5) * u, 1.0 * u, Color.WHITE)
		&"silencer":
			# suppressor tube with baffle rings and a thread collar
			var r := Rect2(c + Vector2(-10, -3.5) * u, Vector2(17, 7) * u)
			ci.draw_rect(r.grow(w * 0.6), INK)
			ci.draw_rect(r, lo)
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2.2 * u)), hi)
			for i in 4:
				ci.draw_line(c + Vector2(-7 + i * 4, -3.5) * u, c + Vector2(-7 + i * 4, 3.5) * u, INK, maxf(1.0, 0.8 * u))
			ci.draw_rect(Rect2(c + Vector2(7, -2) * u, Vector2(3.5, 4) * u), Color(0.6, 0.62, 0.68))
			# the hush: soft rings leaving the end
			for i in 2:
				var k := fmod(t * 0.8 + i * 0.5, 1.0)
				ci.draw_arc(c + Vector2(-11, 0) * u, (2.0 + k * 6.0) * u, PI * 0.6, PI * 1.4, 10, Color(col, (1.0 - k) * 0.6), maxf(1.0, u * 0.8))
		&"armor":
			# kevlar vest: shield silhouette with plate seams
			var pts := [Vector2(-8, -9), Vector2(-3, -9), Vector2(0, -6), Vector2(3, -9), Vector2(8, -9), Vector2(9, 2), Vector2(0, 10), Vector2(-9, 2)]
			_poly(ci, c, u, pts, lo, INK, w)
			_poly(ci, c, u, [Vector2(-7, -7), Vector2(-3, -7), Vector2(0, -4), Vector2(0, 8), Vector2(-7, 1.5)], col, Color(0, 0, 0, 0), 0)
			ci.draw_line(c + Vector2(0, -4) * u, c + Vector2(0, 9) * u, INK, maxf(1.0, u))
			ci.draw_line(c + Vector2(-8, 0) * u, c + Vector2(8, 0) * u, Color(INK, 0.6), maxf(1.0, u * 0.8))
			ci.draw_line(c + Vector2(-6, -6) * u, c + Vector2(-3, -6) * u, hi, maxf(1.0, u))
		&"soft_soles":
			# sneaker with thick soft sole, motion ticks
			_poly(ci, c, u, [Vector2(-10, 3), Vector2(-9, -4), Vector2(-4, -5), Vector2(-1, -1), Vector2(6, 0), Vector2(10, 2), Vector2(10, 5), Vector2(-10, 5)], col, INK, w)
			ci.draw_rect(Rect2(c + Vector2(-10, 3) * u, Vector2(20, 3) * u), Color(0.95, 0.93, 0.9))
			ci.draw_line(c + Vector2(-10, 6) * u, c + Vector2(10, 6) * u, INK, maxf(1.0, u))
			for i in 3:
				ci.draw_line(c + Vector2(-6 + i * 2.5, -3.5 + i * 0.6) * u, c + Vector2(-4 + i * 2.5, -1.8 + i * 0.6) * u, hi, maxf(1.0, u * 0.8))
			var zz := 0.5 + 0.5 * sin(t * 3.0)
			ci.draw_line(c + Vector2(-14, -2) * u, c + Vector2(-12, -2) * u, Color(col, zz), maxf(1.0, u))
			ci.draw_line(c + Vector2(-15, 1) * u, c + Vector2(-12, 1) * u, Color(col, zz * 0.7), maxf(1.0, u))
		&"ext_mag":
			# a long curved magazine with a brass round on top
			_poly(ci, c, u, [Vector2(-3, -9), Vector2(3, -9), Vector2(5, 9), Vector2(-1, 10)], lo, INK, w)
			_poly(ci, c, u, [Vector2(-3, -9), Vector2(-1, -9), Vector2(1, 10), Vector2(-1, 10)], hi, Color(0, 0, 0, 0), 0)
			ci.draw_rect(Rect2(c + Vector2(-2, -12) * u, Vector2(4, 3) * u), Color(0.95, 0.75, 0.3))
			ci.draw_rect(Rect2(c + Vector2(-2, -12) * u, Vector2(4, 1) * u), Color(1, 0.95, 0.7))
			var f := UIStyle.font_display()
			ci.draw_string(f, c + Vector2(4, -3) * u, "+", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(6.0, 12.0 * u)), hi)
		&"night_vision":
			# goggles: twin tubes with green lenses that scan
			for sx in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(sx * 5, 0) * u, 5.2 * u, INK)
				ci.draw_circle(c + Vector2(sx * 5, 0) * u, 4.2 * u, lo)
				ci.draw_circle(c + Vector2(sx * 5, 0) * u, 2.8 * u, col)
				ci.draw_circle(c + Vector2(sx * 5 - 1, -1) * u, 1.0 * u, Color(1, 1, 1, 0.8))
			ci.draw_rect(Rect2(c + Vector2(-1.5, -1.5) * u, Vector2(3, 3) * u), INK)
			ci.draw_line(c + Vector2(-11, -2) * u, c + Vector2(-9, -3) * u, INK, maxf(1.0, u * 1.2))
			ci.draw_line(c + Vector2(11, -2) * u, c + Vector2(9, -3) * u, INK, maxf(1.0, u * 1.2))
			var sy := sin(t * 2.5) * 2.5
			ci.draw_line(c + Vector2(-8, sy) * u, c + Vector2(8, sy) * u, Color(hi, 0.45), maxf(1.0, u * 0.6))
		&"brass_knuckles":
			# four rings on a grip bar
			for i in 4:
				var rc := c + Vector2(-7.5 + i * 5, -3) * u
				ci.draw_circle(rc, 3.2 * u, INK)
				ci.draw_circle(rc, 2.5 * u, col)
				ci.draw_circle(rc, 1.3 * u, INK)
				ci.draw_arc(rc, 2.3 * u, PI * 1.1, PI * 1.6, 6, hi, maxf(1.0, u * 0.7))
			_poly(ci, c, u, [Vector2(-10, 0), Vector2(10, 0), Vector2(8, 6), Vector2(-8, 6)], lo, INK, w)
			ci.draw_line(c + Vector2(-8, 1.5) * u, c + Vector2(8, 1.5) * u, hi, maxf(1.0, u * 0.8))
		&"adrenaline":
			# syringe with a pulse line behind it
			var pts2 := PackedVector2Array()
			for i in 25:
				var x := -12.0 + i
				var ph := fmod(t * 1.4, 1.0) * 24.0 - 12.0
				var spike := 0.0
				if absf(x - ph) < 1.0:
					spike = -6.0
				elif absf(x - ph - 1.0) < 1.0:
					spike = 4.0
				pts2.append(c + Vector2(x, 6 + spike) * u)
			ci.draw_polyline(pts2, Color(col, 0.8), maxf(1.0, u))
			var rot := Transform2D(-0.7, c)
			ci.draw_set_transform_matrix(rot)
			ci.draw_rect(Rect2(Vector2(-7, -2.5) * u, Vector2(12, 5) * u).grow(w * 0.6), INK)
			ci.draw_rect(Rect2(Vector2(-7, -2.5) * u, Vector2(12, 5) * u), Color(0.85, 0.9, 0.95))
			ci.draw_rect(Rect2(Vector2(-6, -1.5) * u, Vector2(7, 3) * u), col)
			ci.draw_rect(Rect2(Vector2(-10, -1) * u, Vector2(3, 2) * u), INK)
			ci.draw_rect(Rect2(Vector2(-11, -3) * u, Vector2(1.5, 6) * u), INK)
			ci.draw_line(Vector2(5, 0) * u, Vector2(11, 0) * u, Color(0.8, 0.85, 0.9), maxf(1.0, u * 0.7))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		&"quick_hands":
			# open hand with speed lines
			_poly(ci, c, u, [Vector2(-4, 9), Vector2(-6, 1), Vector2(-7, -6), Vector2(-5, -6), Vector2(-4, -1), Vector2(-3, -9), Vector2(-1, -9), Vector2(0, -2), Vector2(1, -10), Vector2(3, -10), Vector2(3, -2), Vector2(5, -8), Vector2(7, -8), Vector2(6, 1), Vector2(9, -2), Vector2(10, 0), Vector2(5, 9)], col, INK, w)
			ci.draw_line(c + Vector2(-2, 3) * u, c + Vector2(3, 3) * u, lo, maxf(1.0, u * 0.8))
			for i in 3:
				var k := fmod(t * 2.0 + i * 0.33, 1.0)
				var y := -5.0 + i * 5.0
				ci.draw_line(c + Vector2(-16 + k * 3, y) * u, c + Vector2(-10 + k * 3, y) * u, Color(hi, 1.0 - k), maxf(1.0, u))
		_:
			ci.draw_circle(c, 8.0 * u, col)

static func _poly(ci: CanvasItem, c: Vector2, u: float, pts: Array, fill: Color, outline: Color, w: float) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(c + (v as Vector2) * u)
	ci.draw_colored_polygon(p, fill)
	if w > 0.0 and outline.a > 0.0:
		p.append(p[0])
		ci.draw_polyline(p, outline, w, true)

## Hexagonal badge behind an icon: dark plate, coloured rim, inner glow.
static func badge(ci: CanvasItem, c: Vector2, r: float, col: Color, t := 0.0, glow := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(PI / 6.0 + i * TAU / 6.0) * r)
	if glow > 0.0:
		for k in 3:
			var gp := PackedVector2Array()
			for v in pts:
				gp.append(c + (v - c) * (1.12 + k * 0.1))
			ci.draw_colored_polygon(gp, Color(col, (0.12 - k * 0.035) * glow * (0.8 + 0.2 * sin(t * 4.0))))
	ci.draw_colored_polygon(pts, Color(INK, 0.92))
	var inner := PackedVector2Array()
	for v in pts:
		inner.append(c + (v - c) * 0.84)
	ci.draw_colored_polygon(inner, Color(col.darkened(0.7), 0.9))
	pts.append(pts[0])
	ci.draw_polyline(pts, col, maxf(1.0, r * 0.08), true)
