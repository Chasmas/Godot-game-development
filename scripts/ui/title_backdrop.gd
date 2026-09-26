class_name TitleBackdrop
extends Control
## Animated title background: night over the 10 freeway - city lights,
## palms, passing headlights, rain, a flickering motel sign. Also reused
## (with a different `mode`) as cutscene backdrops.

var mode := "title"      # title, desert_night, apartment, tv_news, black
var fire := 0.0
var _t := 0.0
var _rain: Array = []
var _cars: Array = []
var _stars: Array = []
var _city: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1988
	for i in 140:
		_rain.append([rng.randf(), rng.randf(), rng.randf_range(0.6, 1.0)])
	for i in 60:
		_stars.append([rng.randf(), rng.randf() * 0.45, rng.randf()])
	for i in 220:
		_city.append([rng.randf(), rng.randf_range(0.0, 1.0), rng.randi() % 4, rng.randf()])
	for i in 6:
		_cars.append([rng.randf(), rng.randi() % 2, rng.randf_range(0.8, 1.3)])

func _process(delta: float) -> void:
	_t += delta
	fire = move_toward(fire, 0.0, delta * 0.25)
	queue_redraw()

func _draw() -> void:
	match mode:
		"title": _draw_title()
		"desert_night": _draw_desert()
		"apartment": _draw_apartment()
		"tv_news": _draw_tv()
		_: draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.0, 0.02))

func _sky(top: Color, bottom: Color, horizon: float) -> void:
	var steps := 24
	for i in steps:
		var a := float(i) / steps
		var c := top.lerp(bottom, a)
		draw_rect(Rect2(0, size.y * horizon * a, size.x, size.y * horizon / steps + 1), c)

func _palm(base: Vector2, h: float, c: Color, sway: float) -> void:
	var top := base + Vector2(sway * 10.0, -h)
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(base.lerp(top, t) + Vector2(sin(t * 3.0) * 8.0 * t, 0))
	draw_polyline(pts, c, 5.0)
	for k in 7:
		var ang := -PI * 0.5 + (k - 3) * 0.55 + sin(_t * 0.8 + k) * 0.05
		var frond := PackedVector2Array()
		for j in 6:
			var tt := j / 5.0
			frond.append(top + Vector2.from_angle(ang) * 46.0 * tt + Vector2(0, 22.0 * tt * tt))
		draw_polyline(frond, c, 4.0 - k % 2)

func _draw_title() -> void:
	var horizon := 0.62
	_sky(Color(0.03, 0.01, 0.09), Color(0.42, 0.06, 0.32), horizon)
	for s in _stars:
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + s[2] * 30.0)
		draw_rect(Rect2(s[0] * size.x, s[1] * size.y, 2, 2), Color(1, 1, 1, 0.3 + 0.4 * tw))
	# sun sinking behind haze (a thin band - it's midnight in the memory, sunset on the logo)
	var sun_c := Vector2(size.x * 0.5, size.y * horizon)
	for i in 10:
		var y := sun_c.y - 150.0 + i * 15.0
		var half := sqrt(maxf(0.0, 150.0 * 150.0 - pow(y - sun_c.y, 2.0)))
		draw_rect(Rect2(sun_c.x - half, y, half * 2.0, 10.0 - i * 0.6), Color(1.0, 0.35 + i * 0.03, 0.4, 0.28))
	# city grid lights
	for c in _city:
		var x: float = c[0] * size.x
		var y: float = size.y * horizon + c[1] * size.y * 0.1
		var cols := [Color(1, 0.8, 0.4), Color(1, 0.4, 0.6), Color(0.5, 0.9, 1.0), Color(1, 1, 0.9)]
		var tw := 0.6 + 0.4 * sin(_t * 3.0 + c[3] * 40.0)
		draw_rect(Rect2(x, y, 2, 1), Color(cols[c[2]], 0.55 * tw))
	# ground / freeway
	draw_rect(Rect2(0, size.y * (horizon + 0.1), size.x, size.y), Color(0.04, 0.02, 0.07))
	var road_y := size.y * 0.84
	draw_rect(Rect2(0, road_y, size.x, 34), Color(0.09, 0.07, 0.12))
	for i in 20:
		var x := fmod(i * 90.0 - _t * 240.0, size.x + 90.0) - 45.0
		draw_rect(Rect2(x, road_y + 16, 40, 2), Color(0.9, 0.8, 0.4, 0.7))
	for car in _cars:
		var dir := 1.0 if car[1] == 0 else -1.0
		var speed: float = 380.0 * car[2]
		var x2: float = fmod(car[0] * 2000.0 + _t * speed, size.x + 400.0) - 200.0
		if dir < 0.0:
			x2 = size.x - x2
		var y2 := road_y + (8.0 if dir > 0 else 24.0)
		var col := Color(1, 0.95, 0.8) if dir > 0 else Color(1, 0.1, 0.2)
		for k in 6:
			draw_rect(Rect2(x2 - dir * k * 14.0, y2 - 1, 14, 2), Color(col, 0.5 - k * 0.08))
		draw_circle(Vector2(x2 + dir * 4.0, y2), 3.0, col)
	# palms
	_palm(Vector2(size.x * 0.08, size.y * 0.86), 230.0, Color(0.02, 0.0, 0.04), sin(_t * 0.6))
	_palm(Vector2(size.x * 0.16, size.y * 0.88), 170.0, Color(0.03, 0.01, 0.05), sin(_t * 0.7 + 1.0))
	_palm(Vector2(size.x * 0.9, size.y * 0.87), 250.0, Color(0.02, 0.0, 0.04), sin(_t * 0.5 + 2.0))
	# motel sign
	var on := fmod(_t, 4.3) > 0.18 and fmod(_t, 1.7) > 0.05
	var sign_p := Vector2(size.x * 0.78, size.y * 0.5)
	draw_rect(Rect2(sign_p + Vector2(40, 30), Vector2(6, 120)), Color(0.02, 0.0, 0.04))
	draw_rect(Rect2(sign_p, Vector2(92, 34)), Color(0.05, 0.02, 0.08))
	draw_string(UIStyle.font_bold(), sign_p + Vector2(8, 15), "VACANCY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.3, 0.5, 1.0 if on else 0.15))
	draw_string(UIStyle.font_bold(), sign_p + Vector2(8, 30), "NO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.9, 1.0, 0.9 if fmod(_t, 2.0) < 1.0 else 0.1))
	_rain_draw(Color(0.7, 0.8, 1.0, 0.18))

func _rain_draw(c: Color) -> void:
	for r in _rain:
		var x: float = fmod(r[0] * size.x + _t * 60.0, size.x)
		var y: float = fmod(r[1] * size.y + _t * 700.0 * r[2], size.y)
		draw_line(Vector2(x, y), Vector2(x - 3, y + 14), c, 1.0)

func _draw_desert() -> void:
	_sky(Color(0.02, 0.01, 0.05), Color(0.2, 0.06, 0.16), 0.6)
	for s in _stars:
		draw_rect(Rect2(s[0] * size.x, s[1] * size.y, 2, 2), Color(1, 1, 1, 0.5))
	draw_rect(Rect2(0, size.y * 0.6, size.x, size.y * 0.4), Color(0.12, 0.06, 0.07))
	# road vanishing to the horizon
	var c := Vector2(size.x * 0.5, size.y * 0.6)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(8, 0), Vector2(size.x * 0.8, size.y), Vector2(size.x * 0.2, size.y)]), Color(0.08, 0.06, 0.09))
	for i in 8:
		var t := fmod(i / 8.0 + _t * 0.15, 1.0)
		var y := lerpf(c.y, size.y, t * t)
		draw_rect(Rect2(c.x - 2 - t * 4, y, 4 + t * 8, 6 * t + 1), Color(0.9, 0.8, 0.3, 0.7))
	# the car
	var car := Rect2(size.x * 0.44, size.y * 0.74, size.x * 0.12, 40)
	draw_rect(car, Color(0.55, 0.05, 0.1))
	draw_rect(Rect2(car.position + Vector2(car.size.x * 0.25, -14), Vector2(car.size.x * 0.5, 16)), Color(0.3, 0.02, 0.06))
	if fire > 0.0:
		for i in 30:
			var p := car.get_center() + Vector2(randf_range(-80, 80), randf_range(-120, 20)) * fire
			draw_circle(p, randf_range(6, 26) * fire, Color(1, randf_range(0.3, 0.8), 0.1, 0.5 * fire))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.6, 0.3, fire * 0.35))
	# a film crew silhouette
	for i in 3:
		var bx := size.x * (0.12 + i * 0.05)
		draw_rect(Rect2(bx, size.y * 0.68, 10, 40), Color(0.02, 0.0, 0.03))
		draw_circle(Vector2(bx + 5, size.y * 0.67), 7, Color(0.02, 0.0, 0.03))
	draw_rect(Rect2(size.x * 0.27, size.y * 0.62, 28, 20), Color(0.02, 0.0, 0.03))

func _draw_apartment() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.04, 0.1))
	# window with blinds, neon outside
	var win := Rect2(size.x * 0.58, size.y * 0.12, size.x * 0.3, size.y * 0.45)
	draw_rect(win, Color(0.5, 0.1, 0.35))
	for i in 16:
		var y := win.position.y + i * win.size.y / 16.0
		draw_rect(Rect2(win.position.x, y, win.size.x, win.size.y / 32.0), Color(0.12, 0.05, 0.12))
	var flick := 0.6 + 0.4 * sin(_t * 9.0) * sin(_t * 3.1)
	draw_rect(win.grow(18), Color(1, 0.3, 0.6, 0.06 * flick), false, 18.0)
	# blind light slats on the floor
	for i in 7:
		draw_colored_polygon(PackedVector2Array([Vector2(win.position.x, win.end.y + i * 6), Vector2(win.end.x, win.end.y + i * 6), Vector2(win.end.x - 160, size.y), Vector2(win.position.x - 220, size.y)]), Color(1, 0.35, 0.6, 0.015))
	# table + answering machine
	var tbl := Rect2(size.x * 0.12, size.y * 0.66, size.x * 0.34, 16)
	draw_rect(tbl, Color(0.25, 0.14, 0.08))
	var am := Rect2(tbl.position + Vector2(40, -34), Vector2(90, 34))
	draw_rect(am, Color(0.1, 0.1, 0.12))
	draw_circle(am.position + Vector2(24, 17), 10, Color(0.2, 0.2, 0.22))
	draw_circle(am.position + Vector2(66, 17), 10, Color(0.2, 0.2, 0.22))
	draw_circle(am.position + Vector2(45, 8), 3, Color(1, 0.1, 0.1) if fmod(_t, 1.0) < 0.5 else Color(0.3, 0.02, 0.02))
	# the package
	var pk := Rect2(tbl.position + Vector2(170, -40), Vector2(70, 40))
	draw_rect(pk, Color(0.55, 0.42, 0.26))
	draw_rect(Rect2(pk.position + Vector2(30, 0), Vector2(8, 40)), Color(0.8, 0.7, 0.3))
	draw_string(UIStyle.font_bold(), pk.position + Vector2(8, 26), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.GOLD)

func _draw_tv() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03))
	var scr := Rect2(size.x * 0.15, size.y * 0.08, size.x * 0.7, size.y * 0.55)
	draw_rect(scr.grow(16), Color(0.15, 0.1, 0.08))
	draw_rect(scr, Color(0.1, 0.16, 0.35))
	draw_rect(Rect2(scr.position + Vector2(0, scr.size.y - 44), Vector2(scr.size.x, 44)), Color(0.8, 0.08, 0.15))
	draw_string(UIStyle.font_bold(), scr.position + Vector2(14, scr.size.y - 16), tr("LIVE  ·  BARSTOW MOTEL MASSACRE  ·  'THE STAR KILLER'"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(UIStyle.font_display(), scr.position + Vector2(scr.size.x - 90, 40), "9", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, 0.8))
	# anchor silhouette
	var ac := scr.position + Vector2(scr.size.x * 0.35, scr.size.y * 0.55)
	draw_circle(ac, 34, Color(0.85, 0.65, 0.5))
	draw_circle(ac + Vector2(0, -16), 36, Color(0.75, 0.6, 0.35))
	draw_rect(Rect2(ac + Vector2(-70, 36), Vector2(140, 80)), Color(0.15, 0.2, 0.4))
	# over-shoulder graphic: gold star
	draw_string(UIStyle.font_display(), scr.position + Vector2(scr.size.x * 0.66, scr.size.y * 0.5), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, UIStyle.GOLD)
	for i in 30:
		var y := scr.position.y + fmod(i * 11.0 + _t * 40.0, scr.size.y)
		draw_line(Vector2(scr.position.x, y), Vector2(scr.end.x, y), Color(1, 1, 1, 0.03))
