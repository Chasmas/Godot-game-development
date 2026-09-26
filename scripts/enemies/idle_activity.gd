class_name IdleActivity
extends Node2D
## What a bored guard or a civilian does with their hands: smoke, drink,
## eat, or doze off. Lives on the character's rig (so it turns with them),
## runs a small loop (hand up to the mouth, ember brightens, smoke out...),
## and when the character gets alerted the prop is dropped where they stood.
##
## Snoozing is also gameplay: the owner checks `snoozing` to see much less
## and hear only loud things (see Enemy._perceive / _on_noise).

enum Kind { SMOKE, DRINK, EAT, SNOOZE }

var kind := Kind.SMOKE
var visual: CharacterVisual
var _t := 0.0
var _cycle := 5.0
var _puffs: Array = []        ## world-space smoke / crumbs / Zs
var _snore_t := 1.0
var _variant := 0
var snoozing: bool:
	get: return kind == Kind.SNOOZE

const HAND_LOW := Vector2(2.5, -5.0)     ## rig space: off hand at the hip
const MOUTH := Vector2(3.5, -1.5)        ## rig space: at the face

## Pick an activity for a calm character; stable per seed. Guards doze off
## sometimes; civilians never do (they're awake and twitchy).
static func pick(seed_str: String, can_snooze: bool) -> int:
	var h := absi(hash(seed_str + "idle"))
	var roll := h % 100
	if can_snooze and roll < 25:
		return Kind.SNOOZE
	if roll < 60:
		return Kind.SMOKE
	if roll < 82:
		return Kind.DRINK
	return Kind.EAT

func setup(p_visual: CharacterVisual, p_kind: int, seed_str: String) -> void:
	visual = p_visual
	kind = p_kind
	_variant = absi(hash(seed_str)) % 3
	_cycle = [4.5, 6.0, 5.0, 3.2][kind] + float(absi(hash(seed_str + "c")) % 100) / 60.0
	_t = float(absi(hash(seed_str + "t")) % 100) / 100.0 * _cycle
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	var phase := fmod(_t, _cycle) / _cycle
	match kind:
		Kind.SMOKE:
			# thin wisp from the ember; a big exhale after each drag
			if randf() < delta * 5.0:
				_add_puff(_prop_pos(phase), Vector2(randf_range(-3, 3), -10), 1.0, 1.0, 0)
			if phase > 0.34 and phase - delta / _cycle <= 0.34:
				for i in 5:
					_add_puff(to_global(MOUTH + Vector2(3, 0)), Vector2.from_angle(global_rotation).rotated(randf_range(-0.5, 0.5)) * randf_range(8, 16) + Vector2(0, -4), 2.2, 2.2, 0)
		Kind.EAT:
			if phase > 0.3 and phase - delta / _cycle <= 0.3:
				for i in 3:
					_add_puff(to_global(MOUTH), Vector2(randf_range(-10, 10), randf_range(4, 12)), 0.5, 0.6, 1)
		Kind.SNOOZE:
			if phase > 0.9 and phase - delta / _cycle <= 0.9:
				_add_puff(global_position + Vector2(4, -10), Vector2(6, -10), 1.0, 2.6, 2)
			_snore_t -= delta
			if _snore_t <= 0.0:
				_snore_t = _cycle
				Audio.play_at("snore", global_position, -16.0, 0.08)
			if visual:
				# slumped: head nods forward on each breath
				var b := sin(_t * TAU / _cycle)
				visual.torso.position = Vector2(1.2 + b * 0.5, 0)
				visual.torso.scale = Vector2(0.5 + b * 0.008, 0.5 + b * 0.008)
	for p in _puffs.duplicate():
		p.t += delta
		p.pos += p.vel * delta
		p.vel *= 1.0 - delta * (0.6 if p.kind == 2 else 1.2)
		if p.kind == 1:
			p.vel.y += 60.0 * delta
		if p.t > p.life:
			_puffs.erase(p)
	queue_redraw()

func _add_puff(pos: Vector2, vel: Vector2, r: float, life: float, k: int) -> void:
	if _puffs.size() < 24:
		_puffs.append({"pos": pos, "vel": vel, "r": r, "life": life, "t": 0.0, "kind": k})

## Where the prop is in rig space for this point of the loop: at the hip,
## up at the mouth for a moment, back down.
func _prop_local(phase: float) -> Vector2:
	var up := 0.0
	match kind:
		Kind.SMOKE:
			up = _hump(phase, 0.12, 0.3)
		Kind.DRINK:
			up = _hump(phase, 0.1, 0.38)
		Kind.EAT:
			up = _hump(phase, 0.1, 0.3)
	return HAND_LOW.lerp(MOUTH, up)

func _prop_pos(phase: float) -> Vector2:
	return to_global(_prop_local(phase))

## 0 -> 1 -> 0 between a and b with eased ramps.
static func _hump(x: float, a: float, b: float) -> float:
	if x < a or x > b:
		return 0.0
	var k := (x - a) / (b - a)
	return clampf(minf(k, 1.0 - k) * 4.0, 0.0, 1.0)

func _draw() -> void:
	var phase := fmod(_t, _cycle) / _cycle
	var p := _prop_local(phase)
	var ink := Color("0b0710")
	match kind:
		Kind.SMOKE:
			var drag := _hump(phase, 0.16, 0.28)
			draw_line(p, p + Vector2(2.5, 0.5), Color(0.95, 0.93, 0.88), 1.0)
			draw_circle(p + Vector2(2.8, 0.5), 0.9 + drag * 0.5, Color(1.0, 0.35 + 0.3 * drag, 0.1))
			draw_circle(p + Vector2(2.8, 0.5), 2.5 + drag * 2.0, Color(1.0, 0.4, 0.1, 0.18 + 0.25 * drag))
		Kind.DRINK:
			var tilt := _hump(phase, 0.14, 0.34) * 0.9
			draw_set_transform(p, tilt, Vector2.ONE)
			var can_col: Color = [Color("c81830"), Color("d8d8e0"), Color("2a6ad0")][_variant]
			draw_rect(Rect2(-1.5, -2.2, 3.0, 4.4), ink)
			draw_rect(Rect2(-1.0, -1.8, 2.0, 3.6), can_col)
			draw_rect(Rect2(-1.0, -1.8, 2.0, 0.8), Color(0.85, 0.85, 0.9))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Kind.EAT:
			if _variant == 0:
				draw_circle(p, 2.2, ink)
				draw_circle(p, 1.8, Color("d8a060"))
				draw_circle(p, 1.4, Color("ff6ab0"))
				draw_circle(p, 0.6, ink)
			else:
				draw_rect(Rect2(p - Vector2(2.2, 1.6), Vector2(4.4, 3.2)), ink)
				draw_rect(Rect2(p - Vector2(1.8, 1.2), Vector2(3.6, 1.0)), Color("d8a050"))
				draw_rect(Rect2(p - Vector2(1.8, 0.2), Vector2(3.6, 0.8)), Color("5a2a18"))
				draw_rect(Rect2(p + Vector2(-1.8, 0.6), Vector2(3.6, 0.6)), Color("d8a050"))
	# world-space bits: smoke, crumbs, Zs
	var inv := get_global_transform().affine_inverse()
	for q in _puffs:
		var k: float = q.t / q.life
		var lp: Vector2 = inv * q.pos
		match int(q.kind):
			0:
				draw_circle(lp, q.r + k * 3.0, Color(0.8, 0.8, 0.85, 0.28 * (1.0 - k)))
			1:
				draw_rect(Rect2(lp, Vector2(0.8, 0.8)), Color(0.85, 0.65, 0.4, 1.0 - k))
			2:
				draw_set_transform_matrix(inv * Transform2D(0.0, q.pos))
				draw_string(UIStyle.font_bold(), Vector2.ZERO, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(5 + k * 4), Color(0.8, 0.85, 1.0, 1.0 - k))
				draw_set_transform_matrix(Transform2D.IDENTITY)

## Startled: drop whatever it was where they stand, and stop.
func drop() -> void:
	if kind != Kind.SNOOZE and is_inside_tree():
		var d := DroppedProp.new()
		d.kind = kind
		d.variant = _variant
		var host := get_tree().current_scene if get_tree().current_scene else get_parent()
		host.add_child(d)
		d.global_position = _prop_pos(fmod(_t, _cycle) / _cycle)
		d.vel = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 30.0)
	if visual:
		visual.torso.position = Vector2.ZERO
		visual.torso.scale = Vector2(0.5, 0.5)
	queue_free()


## A dropped cigarette (still smouldering), a rolling can, a half-eaten donut.
class DroppedProp extends Node2D:
	var kind := 0
	var variant := 0
	var vel := Vector2.ZERO
	var t := 0.0
	func _ready() -> void:
		z_index = -1
		if kind == IdleActivity.Kind.DRINK:
			Audio.play_at("metal_clang", global_position, -20.0, 0.3)
	func _process(d: float) -> void:
		t += d
		position += vel * d
		vel = vel.move_toward(Vector2.ZERO, (20.0 if kind == IdleActivity.Kind.DRINK else 90.0) * d)
		rotation += vel.length() * d * 0.3
		if t > 25.0:
			modulate.a -= d * 0.5
			if modulate.a <= 0.0:
				queue_free()
		if kind == IdleActivity.Kind.SMOKE:
			queue_redraw()
	func _draw() -> void:
		match kind:
			IdleActivity.Kind.SMOKE:
				draw_line(Vector2(-1.2, 0), Vector2(1.2, 0), Color(0.9, 0.88, 0.82), 1.0)
				if t < 8.0:
					draw_circle(Vector2(1.4, 0), 0.8, Color(1, 0.4, 0.1, 0.6 + 0.4 * sin(t * 6.0)))
			IdleActivity.Kind.DRINK:
				draw_rect(Rect2(-2.2, -1.5, 4.4, 3.0), Color("0b0710"))
				draw_rect(Rect2(-1.8, -1.0, 3.6, 2.0), [Color("c81830"), Color("d8d8e0"), Color("2a6ad0")][variant])
			IdleActivity.Kind.EAT:
				draw_circle(Vector2.ZERO, 1.8, Color("d8a060"))
				draw_circle(Vector2.ZERO, 1.3, Color("ff6ab0"))
				draw_circle(Vector2(0.9, -0.4), 0.9, Color(0, 0, 0, 0))
