class_name Decor
extends RefCounted
## Atmospheric set dressing: swaying palms, flickering neon signs, animated
## pool caustics. Built from the level JSON "decor" list.

static func build(level: Node, root: Node2D, builder: LevelBuilder, items: Array) -> void:
	for it in items:
		var p := Vector2(float(it.pos[0]) * 16.0 + 8.0, float(it.pos[1]) * 16.0 + 8.0)
		match str(it.type):
			"palm":
				var pt := PalmTree.new()
				pt.position = p
				pt.size = float(it.get("size", 1.0))
				root.add_child(pt)
			"sprite":
				# a painted prop laid on the floor (studio cameras, lights...)
				var tex := ArtLib.sprite(str(it.get("id", "")))
				if tex:
					var sp := Sprite2D.new()
					sp.texture = tex
					sp.scale = Vector2(0.5, 0.5)
					sp.position = p
					sp.rotation = deg_to_rad(float(it.get("rot", 0.0)))
					sp.z_index = -1
					root.add_child(sp)
			"vacancy":
				var vs := WallArt.VacancySign.new()
				vs.position = p
				root.add_child(vs)
			"neon":
				var ns := NeonSign.new()
				ns.position = p
				ns.text = str(it.get("text", "OPEN"))
				ns.color = Color.html("#" + str(it.get("color", "ff3d7f")))
				ns.font_size = int(it.get("size", 14))
				ns.zone = builder.zone_at_cell(int(it.pos[0]), int(it.pos[1]))
				root.add_child(ns)
	var pool := PoolFX.new()
	pool.builder = builder
	root.add_child(pool)


## Top-down palm: canopy of fronds above everything, with a soft ground
## shadow. The crown is not a rigid picture turning on a pin: it is cut into
## a polar mesh (sectors x rings) and every vertex bends by how far out it is
## - the trunk end stays put, the tips whip. Each frond has its own phase, so
## a wave runs round the crown; the wind comes in gusts (layered slow sines),
## pushes the whole canopy downwind and makes the tips flutter. Now and then a
## leaf lets go, tumbles away with the wind and settles on the ground.
class PalmTree extends Node2D:
	var size := 1.0
	var _t := 0.0
	var _seed := 0.0
	var _shadow: Node2D
	var _ground: Node2D
	var _leaves: Array = []      # falling: {p, v, rot, spin, h, vh, s, c}
	var _next_leaf := 0.0
	const SECTORS := 14
	const RINGS := 4

	func _ready() -> void:
		z_index = 45
		_seed = randf() * 10.0
		_next_leaf = randf_range(2.0, 9.0)
		_shadow = PalmShadow.new()
		_shadow.size = size
		_shadow.palm = self
		_shadow.z_index = -6
		_shadow.z_as_relative = false
		add_child(_shadow)
		_ground = FallenLeaves.new()
		_ground.z_index = -5
		_ground.z_as_relative = false
		add_child(_ground)

	func _process(d: float) -> void:
		_t += d
		_tick_leaves(d)
		queue_redraw()
		if Engine.get_process_frames() % 2 == 0:
			_shadow.queue_redraw()

	func _wind() -> float:
		var w = get_tree().get_first_node_in_group("weather")
		return float(w.wind) if w else 0.2

	func _wind_dir() -> Vector2:
		var w = get_tree().get_first_node_in_group("weather")
		if w and "wind_dir" in w:
			var v = w.wind_dir
			if v is Vector2 and v != Vector2.ZERO:
				return v.normalized()
		return Vector2(1, 0.25).normalized()

	## 0..~1.3: the wind as it arrives, in gusts and lulls
	func gust() -> float:
		var w := _wind()
		var g := 0.55 + 0.3 * sin(_t * 0.37 + _seed) + 0.2 * sin(_t * 0.91 + _seed * 2.3) + 0.1 * sin(_t * 2.3 + _seed * 0.7)
		return w * clampf(g, 0.1, 1.3)

	## Kept for anything that asks for the crown's overall turn.
	func sway() -> float:
		var g := gust()
		return sin(_t * (0.9 + g * 0.8) + _seed) * (0.03 + g * 0.06)

	func lean() -> Vector2:
		return _wind_dir() * gust() * 4.0 * size

	func breathe() -> float:
		return 1.0 + sin(_t * 1.7 + _seed) * 0.012 * (1.0 + _wind())

	## Where a crown point (polar: angle a, radius fraction r 0..1) is now.
	## `amp` lets the shadow exaggerate a touch.
	func bend(a: float, r: float, R: float, amp := 1.0) -> Vector2:
		var g := gust()
		var k := r * r                                   # stiff near the trunk, loose at the tips
		var frond := sin(_t * (1.3 + g * 1.4) + a * 3.0 + _seed) * (0.05 + g * 0.1)
		var flutter := sin(_t * (7.0 + g * 6.0) + a * 11.0 + _seed * 3.0) * 0.02 * g
		var ang := a + sway() + (frond + flutter) * k * amp
		var droop := 1.0 + sin(_t * 1.1 + a * 2.0 + _seed) * 0.04 * k - g * 0.05 * k
		var pos := Vector2.from_angle(ang) * r * R * droop * breathe()
		# the canopy is pushed downwind, the tips most of all
		return pos + lean() * (0.35 + k) * amp

	## The deformed crown as triangles with UVs into the painted texture.
	func crown_polys(R: float, amp := 1.0) -> Array:
		var out: Array = []
		var grid: Array = []
		for ri in RINGS + 1:
			var row: Array = []
			var r := float(ri) / RINGS
			for si in SECTORS:
				var a := float(si) / SECTORS * TAU
				row.append([bend(a, r, R, amp), Vector2(0.5, 0.5) + Vector2.from_angle(a) * r * 0.5])
			grid.append(row)
		for ri in RINGS:
			for si in SECTORS:
				var sn := (si + 1) % SECTORS
				var a0: Array = grid[ri][si]
				var a1: Array = grid[ri][sn]
				var b0: Array = grid[ri + 1][si]
				var b1: Array = grid[ri + 1][sn]
				out.append([PackedVector2Array([a0[0], b0[0], b1[0], a1[0]]), PackedVector2Array([a0[1], b0[1], b1[1], a1[1]])])
		return out

	func _draw() -> void:
		var tex := ArtLib.sprite("palm")
		if tex:
			# the painted crown's corners fall outside the circle - the art is
			# a round canopy on a transparent square, so the fan loses nothing
			var R: float = tex.get_width() * 0.5 * 0.5 * size * 1.414
			var tint := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
			draw_set_transform(Vector2.ZERO, _seed, Vector2.ONE)
			for q in crown_polys(R):
				var uv: PackedVector2Array = q[1]
				# the square's corners: stretch the outer ring's UVs to reach them
				var uv2 := PackedVector2Array()
				for u in uv:
					var c := u - Vector2(0.5, 0.5)
					uv2.append(Vector2(0.5, 0.5) + c * 1.414)
				draw_polygon(q[0], tint, uv2, tex)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_draw_procedural()
		_draw_leaves()

	func _draw_procedural() -> void:
		for i in 9:
			var a := i * TAU / 9.0 + _seed
			var L := (26.0 + (i % 3) * 5.0) * size
			var base := bend(a, 0.0, L)
			var tip := bend(a, 1.0, L)
			var midp := bend(a + 0.05, 0.5, L)
			var dir := (tip - base).normalized()
			var w := 5.0 * size
			var pts := PackedVector2Array([base, midp + dir.orthogonal() * w, tip, midp - dir.orthogonal() * w * 0.4])
			draw_colored_polygon(pts, Color(0.1, 0.32, 0.18, 0.96))
			draw_polyline(PackedVector2Array([base, midp, tip]), Color(0.22, 0.55, 0.28, 0.9), 1.0)
			for k in 3:
				var q := bend(a, 0.35 + k * 0.2, L)
				draw_line(q, q + dir.rotated(0.9) * 4.0 * size, Color(0.06, 0.22, 0.12, 0.9), 1.0)
		var c := bend(0.0, 0.0, 1.0)
		draw_circle(c, 4.0 * size, Color(0.35, 0.22, 0.1))
		draw_circle(c + Vector2(-1, -1), 2.0 * size, Color(0.55, 0.38, 0.18))

	# ---- leaves letting go
	func _tick_leaves(d: float) -> void:
		var g := gust()
		_next_leaf -= d * (0.4 + g * 1.6)
		if _next_leaf <= 0.0 and _leaves.size() < 6:
			_next_leaf = randf_range(3.0, 11.0)
			var a := randf() * TAU
			var start := bend(a, randf_range(0.6, 0.95), 24.0 * size)
			var greens := [Color(0.16, 0.42, 0.2), Color(0.3, 0.5, 0.18), Color(0.55, 0.5, 0.2), Color(0.45, 0.3, 0.12)]
			_leaves.append({"p": start, "v": _wind_dir() * (10.0 + g * 30.0) + Vector2.from_angle(a) * 8.0,
				"rot": a, "spin": randf_range(-3.0, 3.0), "h": 1.0, "vh": randf_range(0.18, 0.3),
				"s": randf_range(0.8, 1.3) * size, "c": greens[randi() % greens.size()], "ph": randf() * TAU})
		for lf in _leaves:
			var t: float = _t + float(lf.ph)
			# flutter: the leaf rocks side to side as it sinks, sliding downwind
			var side: Vector2 = Vector2.from_angle(float(lf.rot)).orthogonal() * sin(t * 4.0) * 14.0
			lf.v = (lf.v as Vector2).lerp(_wind_dir() * (8.0 + g * 40.0), d * 0.8)
			lf.p = (lf.p as Vector2) + ((lf.v as Vector2) + side) * d
			lf.rot = float(lf.rot) + float(lf.spin) * d * (0.5 + absf(sin(t * 2.0)))
			lf.h = float(lf.h) - float(lf.vh) * d * (0.7 + 0.3 * sin(t * 3.0))
		for k in range(_leaves.size() - 1, -1, -1):
			var lf: Dictionary = _leaves[k]
			if float(lf.h) <= 0.0:
				_ground.land(lf.p, lf.rot, lf.s, lf.c)
				_leaves.remove_at(k)

	func _draw_leaves() -> void:
		for lf in _leaves:
			var h: float = float(lf.h)
			# high up it's bigger (nearer the camera) and throws a shadow below
			var sc: float = float(lf.s) * (0.8 + 0.5 * h)
			var p: Vector2 = lf.p
			_leaf_shape(p + Vector2(6, 8) * h, float(lf.rot), sc, Color(0, 0, 0.02, 0.25 * (1.0 - h * 0.5)))
			_leaf_shape(p, float(lf.rot), sc, lf.c)

	func _leaf_shape(p: Vector2, rot: float, sc: float, col: Color) -> void:
		var d := Vector2.from_angle(rot)
		var n := d.orthogonal()
		var L := 5.0 * sc
		var W := 1.6 * sc
		draw_colored_polygon(PackedVector2Array([p - d * L, p + n * W, p + d * L, p - n * W * 0.6]), col)
		if col.a > 0.5:
			draw_line(p - d * L, p + d * L, col.darkened(0.35), 1.0)


## Leaves that fell: lie on the floor a while, curl and fade.
class FallenLeaves extends Node2D:
	var _items: Array = []
	var _t := 0.0

	func land(p: Vector2, rot: float, s: float, c: Color) -> void:
		_items.append({"p": p, "rot": rot, "s": s, "c": c, "age": 0.0, "life": randf_range(14.0, 26.0)})
		if _items.size() > 14:
			_items.pop_front()

	func _process(d: float) -> void:
		if _items.is_empty():
			return
		_t += d
		for it in _items:
			it.age = float(it.age) + d
		_items = _items.filter(func(it): return float(it.age) < float(it.life))
		if Engine.get_process_frames() % 4 == 0:
			queue_redraw()

	func _draw() -> void:
		for it in _items:
			var fade := clampf((float(it.life) - float(it.age)) / 4.0, 0.0, 1.0)
			var c: Color = (it.c as Color).darkened(clampf(float(it.age) / float(it.life), 0.0, 0.5))
			c.a = fade * 0.95
			var d := Vector2.from_angle(float(it.rot))
			var n := d.orthogonal()
			var L := 5.0 * float(it.s)
			var W := 1.4 * float(it.s)
			var p: Vector2 = it.p
			draw_colored_polygon(PackedVector2Array([p - d * L, p + n * W, p + d * L, p - n * W * 0.6]), c)
			draw_line(p - d * L, p + d * L, c.darkened(0.35), 1.0)


## The palm's shadow on the ground: the crown's own silhouette, thrown down
## and to the side by the light and squashed onto the floor, bending vertex
## for vertex with the tree (same mesh, same gusts) but a touch further, as a
## shadow does.
class PalmShadow extends Node2D:
	var size := 1.0
	var palm: PalmTree
	const OFFSET := Vector2(12, 16)
	const SHADE := Color(0.0, 0.0, 0.02, 0.4)
	func _draw() -> void:
		if palm == null:
			return
		var base := OFFSET * size
		var tex := ArtLib.sprite("palm")
		draw_set_transform_matrix(Transform2D(0.0, Vector2(1.05, 0.72), 0.25, base) * Transform2D(palm._seed, Vector2.ZERO))
		if tex:
			var R: float = tex.get_width() * 0.5 * 0.5 * size * 1.414
			var tint := PackedColorArray([SHADE, SHADE, SHADE, SHADE])
			for q in palm.crown_polys(R, 1.25):
				var uv2 := PackedVector2Array()
				for u in (q[1] as PackedVector2Array):
					uv2.append(Vector2(0.5, 0.5) + (u - Vector2(0.5, 0.5)) * 1.414)
				draw_polygon(q[0], tint, uv2, tex)
		else:
			for i in 9:
				var a := i * TAU / 9.0
				var L := (26.0 + (i % 3) * 5.0) * size
				var b0 := palm.bend(a, 0.0, L, 1.25)
				var tip := palm.bend(a, 1.0, L, 1.25)
				var mid := palm.bend(a + 0.05, 0.5, L, 1.25)
				var dir := (tip - b0).normalized()
				var w := 5.0 * size
				draw_colored_polygon(PackedVector2Array([b0, mid + dir.orthogonal() * w, tip, mid - dir.orthogonal() * w * 0.4]), SHADE)
			draw_circle(Vector2.ZERO, 4.0 * size, SHADE)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## Neon lettering with glow, buzz-flicker and its own light.
class NeonSign extends Node2D:
	var text := "OPEN"
	var color := Color("ff3d7f")
	var font_size := 14
	var zone := ""
	var _t := 0.0
	var _on := 1.0
	var _light: PointLight2D

	func _ready() -> void:
		z_index = 44
		_light = PointLight2D.new()
		_light.texture = SpriteLib.light_texture(256)
		_light.texture_scale = 1.1
		_light.color = color
		_light.energy = 0.9
		_light.shadow_enabled = false
		add_child(_light)

	func _process(d: float) -> void:
		_t += d
		var on := 1.0
		if fmod(_t, 5.7) < 0.12 or (fmod(_t, 3.1) < 0.05):
			on = 0.25 + randf() * 0.3
		_on = on
		_light.energy = 0.9 * on
		if Engine.get_process_frames() % 3 == 0:
			queue_redraw()

	func _draw() -> void:
		var f := UIStyle.font_display()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var o := Vector2(-w * 0.5, font_size * 0.35)
		draw_rect(Rect2(o + Vector2(-6, -font_size - 2), Vector2(w + 12, font_size + 8)), Color(0.04, 0.02, 0.07, 0.85))
		draw_rect(Rect2(o + Vector2(-6, -font_size - 2), Vector2(w + 12, font_size + 8)), Color(color, 0.5 * _on), false, 1.0)
		for g in [3.0, 2.0, 1.0]:
			draw_string_outline(f, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, int(g * 2.0), Color(color, 0.12 * _on))
		draw_string(f, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.lightened(0.5), _on))


## Animated caustics and highlights over every pool tile.
class PoolFX extends Node2D:
	var builder: LevelBuilder
	var _cells: Array = []
	var _t := 0.0

	func _ready() -> void:
		z_index = -9
		for y in builder.h:
			for x in builder.w:
				if builder.floor_grid[y][x] == "~":
					_cells.append(Vector2(x * 16, y * 16))

	func _process(d: float) -> void:
		_t += d
		if Engine.get_process_frames() % 3 == 0 and not _cells.is_empty():
			queue_redraw()

	func _draw() -> void:
		for c: Vector2 in _cells:
			for i in 2:
				var ph := _t * 1.3 + c.x * 0.05 + c.y * 0.07 + i * 2.1
				var y := c.y + 4.0 + i * 7.0 + sin(ph) * 1.5
				var pts := PackedVector2Array()
				for k in 5:
					pts.append(Vector2(c.x + k * 4.0, y + sin(ph + k * 1.4) * 1.2))
				draw_polyline(pts, Color(0.55, 0.9, 1.0, 0.28 + 0.12 * sin(ph * 1.7)), 1.0)
