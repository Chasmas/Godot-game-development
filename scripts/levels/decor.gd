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


## Top-down palm: canopy of fronds above everything, swaying with the wind,
## with a soft ground shadow.
class PalmTree extends Node2D:
	var size := 1.0
	var _t := 0.0
	var _seed := 0.0
	var _shadow: Node2D

	func _ready() -> void:
		z_index = 45
		_seed = randf() * 10.0
		_shadow = PalmShadow.new()
		_shadow.size = size
		_shadow.z_index = -6
		_shadow.z_as_relative = false
		add_child(_shadow)

	func _process(d: float) -> void:
		_t += d
		if Engine.get_process_frames() % 2 == 0:
			queue_redraw()

	func _wind() -> float:
		var w = get_tree().get_first_node_in_group("weather")
		return float(w.wind) if w else 0.2

	func _draw() -> void:
		var wind := _wind()
		var sway := sin(_t * (1.2 + wind) + _seed) * (0.05 + wind * 0.12)
		var lean := Vector2(wind * 4.0, 0)
		for i in 9:
			var a := i * TAU / 9.0 + sway + _seed
			var L := (26.0 + (i % 3) * 5.0) * size
			var dir := Vector2.from_angle(a)
			var tip := lean + dir * L
			var mid := lean * 0.5 + dir * L * 0.5 + dir.orthogonal() * 3.0 * size
			var w := 5.0 * size
			var pts := PackedVector2Array([lean, mid + dir.orthogonal() * w, tip, mid - dir.orthogonal() * w * 0.4])
			draw_colored_polygon(pts, Color(0.1, 0.32, 0.18, 0.96))
			draw_line(lean, tip, Color(0.22, 0.55, 0.28, 0.9), 1.0)
			# leaflet serrations (cel detail)
			for k in 3:
				var q := lean.lerp(tip, 0.35 + k * 0.2)
				draw_line(q, q + dir.rotated(0.9) * 4.0 * size, Color(0.06, 0.22, 0.12, 0.9), 1.0)
		draw_circle(lean, 4.0 * size, Color(0.35, 0.22, 0.1))
		draw_circle(lean + Vector2(-1, -1), 2.0 * size, Color(0.55, 0.38, 0.18))


class PalmShadow extends Node2D:
	var size := 1.0
	func _draw() -> void:
		draw_set_transform(Vector2(10, 14) * size, 0.3, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 26.0 * size, Color(0, 0, 0, 0.22))


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
