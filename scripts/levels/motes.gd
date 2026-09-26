class_name AmbientMotes
extends Node2D
## Dust drifting in the air of interior rooms: a few dozen motes around the
## camera, slow drift, brighter where lights are. One node, capped count;
## hidden outdoors and in blacked-out rooms. Light/zone lookups are cached
## per mote and refreshed a few per frame, so the cost is flat.

const COUNT := 36
const REFRESH_PER_FRAME := 4

var level: Level
var _pts: Array = []    ## [pos, vel, phase, light (0..1, -1 = hidden)]
var _t := 0.0
var _next := 0

func _ready() -> void:
	z_index = 40
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in COUNT:
		_pts.append([Vector2.INF, Vector2.from_angle(randf() * TAU) * randf_range(2.0, 6.0), randf() * TAU, -1.0])

func _process(delta: float) -> void:
	_t += delta
	if level == null or level.player == null or not is_instance_valid(level.player):
		return
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	for m in _pts:
		var p: Vector2 = m[0]
		if p == Vector2.INF or not view.grow(20).has_point(p):
			m[0] = view.position + Vector2(randf() * view.size.x, randf() * view.size.y)
			m[3] = -1.0
			continue
		m[1] = (m[1] as Vector2).rotated(randf_range(-0.6, 0.6) * delta)
		m[0] = p + m[1] * delta + Vector2(0, sin(_t * 0.7 + m[2]) * 1.5 * delta)
	for i in REFRESH_PER_FRAME:
		_next = (_next + 1) % COUNT
		var m2: Array = _pts[_next]
		var z := level.zone_at(m2[0])
		m2[3] = -1.0 if (z == "exterior" or z == "" or level.is_zone_dark(z)) else clampf(level.light_level_at(m2[0]), 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	for m in _pts:
		var lit: float = m[3]
		if lit < 0.0:
			continue
		var a := (0.05 + 0.25 * lit) * (0.6 + 0.4 * sin(_t * 1.3 + m[2]))
		draw_rect(Rect2(m[0], Vector2(0.8, 0.8)), Color(1.0, 0.92, 0.8, a))
