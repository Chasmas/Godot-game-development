class_name CheckpointMarker
extends Node2D
## A checkpoint on the floor just inside an area's door, centred on it:
## one thin ring of cyan light, breathing, with a faint column of light
## rising from it and a few motes drifting up. Step on it and it saves: the
## ring flashes gold, bursts outward as a wave across the floor, throws a
## handful of sparks, and is gone.

var active := false
var _t := 0.0
var _burst := -1.0           ## 0..1 while it's going, then it frees itself
var _light: PointLight2D
var _motes: Array = []

const R := 9.0

func _ready() -> void:
	z_index = -2
	_t = randf() * 3.0
	_light = PointLight2D.new()
	_light.texture = SpriteLib.light_texture(128)
	_light.texture_scale = 0.35
	_light.energy = 0.25
	_light.color = UIStyle.CYAN
	_light.range_item_cull_mask = 1
	add_child(_light)
	for i in 5:
		_motes.append(Vector3(randf_range(-R, R) * 0.6, randf(), randf_range(0.6, 1.2)))

## silent: restored from a checkpoint - it's already been taken, so it's gone.
func activate(silent := false) -> void:
	if active:
		return
	active = true
	if silent:
		queue_free()
		return
	_burst = 0.0
	_light.color = UIStyle.GOLD

func _process(delta: float) -> void:
	_t += delta
	if _burst >= 0.0:
		_burst += delta / 0.9
		_light.energy = 1.6 * (1.0 - _burst)
		_light.texture_scale = 0.35 + _burst * 0.8
		if _burst >= 1.0:
			queue_free()
			return
	else:
		_light.energy = 0.2 + 0.12 * sin(_t * 2.4)
	queue_redraw()

func _draw() -> void:
	if _burst >= 0.0:
		var k := _burst
		var e := 1.0 - pow(1.0 - k, 3.0)
		# the wave across the floor, gold into pink
		draw_arc(Vector2.ZERO, R + e * 46.0, 0, TAU, 48, Color(UIStyle.GOLD, (1.0 - k) * 0.9), 2.0 * (1.0 - k) + 0.5)
		draw_arc(Vector2.ZERO, R + e * 28.0, 0, TAU, 40, Color(UIStyle.PINK, (1.0 - k) * 0.5), 1.0)
		draw_circle(Vector2.ZERO, R * (1.0 - k), Color(1, 0.95, 0.75, (1.0 - k) * 0.5))
		# sparks flung out and up
		for i in 10:
			var a := i * TAU / 10.0 + 0.3
			var p := Vector2.from_angle(a) * (R + e * 24.0) + Vector2(0, -e * 10.0 * (0.5 + 0.5 * sin(i * 3.0)))
			draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 0.9, 0.6, 1.0 - k))
		return
	var breathe := 0.5 + 0.5 * sin(_t * 2.4)
	var col := UIStyle.CYAN
	# the ring: thin, with a soft halo
	draw_arc(Vector2.ZERO, R, 0, TAU, 40, Color(col, 0.18), 3.5)
	draw_arc(Vector2.ZERO, R, 0, TAU, 40, Color(col, 0.55 + 0.35 * breathe), 1.0)
	# a faint column of light rising off it
	for i in 6:
		var h := 4.0 + i * 3.0
		draw_line(Vector2(-R * 0.7, -h), Vector2(R * 0.7, -h), Color(col, 0.06 * (1.0 - i / 6.0) * (0.6 + 0.4 * breathe)), 2.0)
	# motes drifting up
	for m in _motes:
		var y := -fmod(m.y * 20.0 + _t * 8.0 * m.z, 20.0)
		var fade := 1.0 - (-y / 20.0)
		draw_rect(Rect2(Vector2(m.x, y), Vector2(1, 1)), Color(col.lightened(0.4), 0.6 * fade))
