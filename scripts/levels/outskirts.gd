class_name Outskirts
extends Node2D
## What lies past the lot's walls, so the car never comes out of a black
## void: a band of ground all round the map with its own place's clutter.
##   motel   - Barstow desert: sand, creosote scrub, telephone poles and
##             sagging wires, a billboard, tumbleweeds rolling in the wind
##   yard    - Mojave scrub: dust, tyre stacks, rusting wrecks, chain-link
##   studio  - the Burbank backlot: asphalt, production trucks, light towers,
##             palms, a painted studio wall
##   dream   - the villa's grounds: black lawn, cypresses, headstones, a
##             red fog lying low
## Drawn under the level (the floor covers anything inside the map) and
## kept off the car's roads.

const BAND := 26.0 * 16.0      ## how far out the scenery goes

var level: Node
var theme := "motel"
var _rect := Rect2()
var _props: Array = []         ## [kind, pos, rot, scale, seed]
var _t := 0.0
var _weeds: Array = []

static func theme_for(mission_id: String) -> String:
	if mission_id.begins_with("m02"):
		return "yard"
	if mission_id.begins_with("m03"):
		return "studio"
	if mission_id.begins_with("m04"):
		return "dream"
	return "motel"

func setup(p_level: Node, map_size: Vector2i, mission_id: String) -> void:
	level = p_level
	theme = theme_for(mission_id)
	_rect = Rect2(Vector2.ZERO, Vector2(map_size) * 16.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(mission_id + "outskirts")
	var kinds: Dictionary = {
		"motel": [["scrub", 70], ["rock", 30], ["cactus", 18], ["palm", 6]],
		# The yard is built from authored in-level salvage clusters.  Keep the
		# distant perimeter sparse so it frames the map instead of repeating the
		# same wreck silhouette around every edge.
		"yard": [["tyres", 12], ["wreck", 5], ["scrub", 18], ["drum", 8], ["rock", 10]],
		"studio": [["truck", 14], ["tower", 8], ["palm", 18], ["cone", 26], ["crate", 18]],
		"dream": [["cypress", 40], ["grave", 34], ["candle", 16], ["hedge", 16]],
	}
	for kv in kinds[theme]:
		for i in int(kv[1]):
			var p := _outside_point(rng)
			if p != Vector2.INF:
				_props.append([kv[0], p, rng.randf() * TAU, rng.randf_range(0.8, 1.25), rng.randi()])
	# telephone poles in a line along one side, billboard near the road in
	if theme == "motel":
		var y := _rect.end.y + 70.0
		var x := _rect.position.x - BAND
		while x < _rect.end.x + BAND:
			_props.append(["pole", Vector2(x, y), 0.0, 1.0, 0])
			x += 150.0
		_props.append(["billboard", Vector2(_rect.position.x - 150.0, _rect.end.y - 60.0), 0.0, 1.0, 0])
		for i in 3:
			_weeds.append({"p": _outside_point(rng), "v": Vector2(rng.randf_range(20, 45), rng.randf_range(-6, 6)), "r": 0.0})
	if theme == "studio":
		_props.append(["studio_wall", Vector2(_rect.position.x - 60.0, _rect.position.y + _rect.size.y * 0.3), 0.0, 1.0, 0])
	_props.sort_custom(func(a, b): return a[1].y < b[1].y)
	# real lights out there: lamps along the roads and a few in the dark
	var lc: Color = {"motel": Color(1.0, 0.6, 0.3), "yard": Color(1.0, 0.7, 0.35), "studio": Color(0.9, 0.95, 1.0), "dream": Color(1.0, 0.2, 0.2)}[theme]
	var spots: Array = []
	var car = level.get("hero_car")
	if car:
		for route in [car.route_in, car.route_out]:
			if route.size() >= 2:
				spots.append(route[0].lerp(route[1], 0.35) + (route[1] - route[0]).normalized().orthogonal() * 40.0)
				spots.append(route[0].lerp(route[1], 0.75) - (route[1] - route[0]).normalized().orthogonal() * 40.0)
	for i in 4:
		var sp := _outside_point(rng)
		if sp != Vector2.INF:
			spots.append(sp)
	for sp in spots:
		var l := PointLight2D.new()
		l.texture = SpriteLib.light_texture(256)
		l.texture_scale = 1.2
		l.color = lc
		l.energy = 0.9
		l.position = sp
		add_child(l)
		_props.append(["lamp", sp, 0.0, 1.0, 0])

func _on_road(p: Vector2) -> bool:
	var car = level.get("hero_car")
	if car == null:
		return false
	for route in [car.route_in, car.route_out]:
		for i in route.size() - 1:
			var cp := Geometry2D.get_closest_point_to_segment(p, route[i], route[i + 1])
			if cp.distance_to(p) < 60.0:
				return true
	return false

func _outside_point(rng: RandomNumberGenerator) -> Vector2:
	for tries in 30:
		var p := Vector2(rng.randf_range(_rect.position.x - BAND, _rect.end.x + BAND), rng.randf_range(_rect.position.y - BAND, _rect.end.y + BAND))
		if _rect.grow(24.0).has_point(p) or _on_road(p):
			continue
		return p
	return Vector2.INF

## The ground and the clutter are drawn once; only what moves (tumbleweeds,
## the fog, flickering candles and glows) is redrawn, on a child layer.
var _anim: Node2D

class _AnimLayer extends Node2D:
	var o: Outskirts
	func _draw() -> void:
		o._draw_anim(self)

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_anim = _AnimLayer.new()
	_anim.o = self
	add_child(_anim)

func _process(delta: float) -> void:
	_t += delta
	for w in _weeds:
		w.p += w.v * delta
		w.r += delta * 4.0
		if w.p.x > _rect.end.x + BAND:
			w.p.x = _rect.position.x - BAND
	if Engine.get_process_frames() % 2 == 0:
		_anim.queue_redraw()

func _draw_anim(c: CanvasItem) -> void:
	for w in _weeds:
		if w.p == Vector2.INF:
			continue
		c.draw_set_transform(w.p, w.r, Vector2.ONE)
		for k in 6:
			c.draw_arc(Vector2.ZERO, 5.0 + k * 0.6, k, k + 2.2, 6, Color(0.45, 0.35, 0.25, 0.8), 1.0)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for pr in _props:
		var p: Vector2 = pr[1]
		match str(pr[0]):
			"billboard":
				c.draw_circle(p + Vector2(48, 44), 20.0, Color(1, 0.75, 0.4, 0.06 + 0.02 * sin(_t * 3.0)))
			"candle":
				var fl := 0.8 + 0.2 * sin(_t * 9.0 + p.x)
				c.draw_circle(p, 12.0 * fl, Color(1.0, 0.5, 0.2, 0.08))
				c.draw_circle(p + Vector2(0, -3), 1.2 * fl, Color(1.0, 0.8, 0.4))
	if theme == "dream":
		# red fog lying in bands, drifting
		var outer := _rect.grow(BAND)
		for i in 7:
			var y := outer.position.y + fmod(i * 173.0 + _t * 6.0, outer.size.y)
			c.draw_rect(Rect2(outer.position.x, y, outer.size.x, 40.0), Color(0.5, 0.05, 0.08, 0.05))

const GROUND_TEX := {"motel": ";", "yard": ";", "studio": ":", "dream": "\""}

func _ground() -> Color:
	return {"motel": Color(0.34, 0.25, 0.24), "yard": Color(0.38, 0.29, 0.22), "studio": Color(0.2, 0.2, 0.24), "dream": Color(0.1, 0.15, 0.11)}[theme]

func _draw() -> void:
	var g := _ground()
	var outer := _rect.grow(BAND)
	# four strips round the map (the map itself draws its own floor)
	var strips := [Rect2(outer.position, Vector2(outer.size.x, BAND)), Rect2(Vector2(outer.position.x, _rect.end.y), Vector2(outer.size.x, BAND)),
		Rect2(Vector2(outer.position.x, _rect.position.y), Vector2(BAND, _rect.size.y)), Rect2(Vector2(_rect.end.x, _rect.position.y), Vector2(BAND, _rect.size.y))]
	var gt := ArtLib.floor_tex(str(GROUND_TEX[theme]))
	if gt:
		# the painted ground, tiled at the floors' density (4 texels a pixel),
		# darkened toward the place's own ground colour
		var tint := Color(0.62, 0.58, 0.6) if theme != "dream" else Color(0.3, 0.35, 0.32)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.25, 0.25))
		for r in strips:
			draw_texture_rect(gt, Rect2(r.position * 4.0, r.size * 4.0), true, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		for r in strips:
			draw_rect(r, g)
	# ground texture: a scatter of lighter and darker specks, seeded
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in (0 if gt else 900):
		var p := Vector2(rng.randf_range(outer.position.x, outer.end.x), rng.randf_range(outer.position.y, outer.end.y))
		if _rect.has_point(p):
			continue
		draw_circle(p, rng.randf_range(0.8, 2.6), g.lightened(0.12) if rng.randf() < 0.5 else g.darkened(0.3))
	for pr in _props:
		_prop(pr)

func _sprite(id: String, p: Vector2, rot: float, sc: float) -> bool:
	var tex := ArtLib.sprite(id)
	if tex == null:
		return false
	var sz := Vector2(tex.get_width(), tex.get_height()) * 0.5 * sc
	draw_set_transform(p, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

func _prop(pr: Array) -> void:
	var kind: String = pr[0]
	var p: Vector2 = pr[1]
	var rot: float = pr[2]
	var sc: float = pr[3]
	var shade := Color(0, 0, 0.02, 0.35)
	match kind:
		"scrub":
			for k in 5:
				draw_circle(p + Vector2.from_angle(k * 1.3 + rot) * 4.0 * sc, 4.0 * sc, Color(0.2, 0.24, 0.14))
			draw_circle(p + Vector2(2, 2), 3.0 * sc, Color(0.14, 0.17, 0.1))
		"cactus":
			draw_rect(Rect2(p + Vector2(-2, -9) * sc, Vector2(4, 18) * sc), Color(0.18, 0.3, 0.18))
			draw_rect(Rect2(p + Vector2(2, -4) * sc, Vector2(5, 3) * sc), Color(0.18, 0.3, 0.18))
		"rock":
			draw_circle(p + Vector2(2, 2), 6.0 * sc, shade)
			draw_circle(p, 6.0 * sc, Color(0.3, 0.26, 0.26))
			draw_circle(p + Vector2(-1.5, -1.5), 3.0 * sc, Color(0.38, 0.33, 0.32))
		"pole":
			draw_line(p + Vector2(-150, -2), p + Vector2(0, -2), Color(0.05, 0.05, 0.06, 0.8), 1.0)
			draw_line(p + Vector2(-150, 3), p + Vector2(0, 3), Color(0.05, 0.05, 0.06, 0.8), 1.0)
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.32, 0.22, 0.14))
			draw_line(p + Vector2(-10, 0), p + Vector2(10, 0), Color(0.3, 0.2, 0.13), 3.0)
		"billboard":
			draw_rect(Rect2(p + Vector2(4, 4), Vector2(96, 36)), shade)
			draw_rect(Rect2(p, Vector2(96, 36)), Color(0.12, 0.08, 0.1))
			draw_rect(Rect2(p + Vector2(3, 3), Vector2(90, 30)), Color(0.55, 0.12, 0.25))
			draw_string(UIStyle.font_display(), p + Vector2(8, 24), "SUNSET PALMS  2 MI", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.5))
		"tyres":
			for k in 3:
				var q := p + Vector2(k * 5.0 - 5.0, sin(k + rot) * 3.0)
				draw_circle(q, 6.0 * sc, Color(0.07, 0.07, 0.08))
				draw_circle(q, 2.6 * sc, Color(0.16, 0.14, 0.14))
		"wreck":
			if not _sprite("wreck", p, rot, sc * 0.9):
				draw_rect(Rect2(p - Vector2(24, 12), Vector2(48, 24)), Color(0.3, 0.2, 0.15))
		"drum":
			draw_circle(p + Vector2(2, 2), 5.5, shade)
			draw_circle(p, 5.5, Color(0.35, 0.22, 0.12))
			draw_arc(p, 4.0, 0, TAU, 12, Color(0.2, 0.12, 0.08), 1.0)
		"truck":
			draw_set_transform(p, rot, Vector2.ONE)
			draw_rect(Rect2(-40, -14, 80, 28), Color(0.85, 0.85, 0.82))
			draw_rect(Rect2(28, -12, 14, 24), Color(0.2, 0.3, 0.55))
			draw_string(UIStyle.font_bold(), Vector2(-34, 4), "KHSC GRIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.2, 0.2, 0.25))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"tower":
			if not _sprite("studio_light", p, rot, sc):
				draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.3, 0.3, 0.32))
			draw_circle(p, 40.0, Color(1, 0.95, 0.8, 0.05))
		"palm":
			_sprite("palm", p, rot, sc * 0.9)
		"cone":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(4, 4), p + Vector2(-4, 4)]), Color(1.0, 0.45, 0.1))
			draw_line(p + Vector2(-2.5, 1), p + Vector2(2.5, 1), Color(1, 1, 1), 1.0)
		"crate":
			if not _sprite("crate", p, rot, sc):
				draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color(0.4, 0.3, 0.18))
		"studio_wall":
			draw_rect(Rect2(p - Vector2(20, 90), Vector2(22, 180)), Color(0.25, 0.22, 0.28))
			draw_set_transform(p + Vector2(-5, 60), -PI * 0.5, Vector2.ONE)
			draw_string(UIStyle.font_display(), Vector2.ZERO, "KHSC STUDIOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.35, 0.6, 0.8))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"cypress":
			draw_circle(p + Vector2(4, 5), 9.0 * sc, shade)
			draw_circle(p, 9.0 * sc, Color(0.04, 0.1, 0.07))
			draw_circle(p + Vector2(-2, -2), 5.0 * sc, Color(0.07, 0.15, 0.1))
		"grave":
			if not _sprite("grave", p, 0.0, sc * 0.8):
				draw_rect(Rect2(p - Vector2(5, 7), Vector2(10, 14)), Color(0.35, 0.33, 0.36))
		"candle":
			draw_rect(Rect2(p - Vector2(1, 2), Vector2(2, 4)), Color(0.9, 0.85, 0.75))
		"lamp":
			draw_circle(p + Vector2(3, 3), 4.0, shade)
			draw_circle(p, 3.5, Color(0.2, 0.2, 0.22))
			draw_circle(p, 1.8, Color(1.0, 0.9, 0.7))
		"hedge":
			draw_rect(Rect2(p - Vector2(20, 5), Vector2(40, 10)), Color(0.05, 0.12, 0.07))
