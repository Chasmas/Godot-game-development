class_name CheckpointMarker
extends Node2D
## A checkpoint on the floor at an area's entrance: a small tape reel in a
## ring. Dim cyan and breathing while waiting; when the checkpoint saves it
## flares gold, spins up, throws a ring and settles into a steady gold glow.
## Deliberately low-key: it sits on the floor under everything.

var active := false
var _t := 0.0
var _flash := 0.0
var _spin := 0.0

func _ready() -> void:
	z_index = -2
	_t = randf() * 3.0

func activate(silent := false) -> void:
	if active:
		return
	active = true
	if not silent:
		_flash = 1.0
		_spin = 12.0

func _process(delta: float) -> void:
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 1.5)
	_spin = move_toward(_spin, 0.8 if active else 0.3, delta * 8.0)
	queue_redraw()

func _draw() -> void:
	var col := UIStyle.GOLD if active else UIStyle.CYAN
	var breathe := 0.5 + 0.5 * sin(_t * 2.2)
	var a := (0.55 if active else 0.3 + 0.2 * breathe)
	# floor glow and ring
	draw_circle(Vector2.ZERO, 11.0, Color(col, 0.07 + 0.05 * breathe + _flash * 0.3))
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 28, Color(col, a), 1.0)
	# tick marks turning slowly, like a reel's edge
	var rot := _t * _spin
	for i in 6:
		var ang := rot + i * TAU / 6.0
		draw_line(Vector2.from_angle(ang) * 6.5, Vector2.from_angle(ang) * 8.5, Color(col, a), 1.0)
	# the reel hub
	draw_circle(Vector2.ZERO, 2.2, Color(col, a + 0.2))
	for i in 3:
		var ang2 := rot * 1.5 + i * TAU / 3.0
		draw_line(Vector2.ZERO, Vector2.from_angle(ang2) * 4.5, Color(col, a), 1.0)
	if _flash > 0.0:
		var k := 1.0 - _flash
		draw_arc(Vector2.ZERO, 10.0 + k * 40.0, 0, TAU, 40, Color(UIStyle.GOLD, _flash), 2.0)
		draw_circle(Vector2.ZERO, 12.0, Color(1, 0.95, 0.7, _flash * 0.4))
