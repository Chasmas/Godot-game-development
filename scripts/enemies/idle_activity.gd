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

var _chair: Node2D = null

func setup(p_visual: CharacterVisual, p_kind: int, seed_str: String) -> void:
	visual = p_visual
	kind = p_kind
	if kind == Kind.SNOOZE and visual:
		# a folding chair under him, gun put away, legs stretched out: it
		# has to read as "asleep on the job" at a glance
		# on the body, not the rig: the rig breathes and turns with the aim,
		# the chair stays put on the floor
		_chair = SnoozeChair.new()
		_chair.z_index = -1
		_chair.rotation = visual.rig.rotation
		var body := visual.get_parent() as Node2D
		if body:
			body.add_child.call_deferred(_chair)
		else:
			visual.rig.add_child(_chair)
		visual.weapon_sprite.visible = false
		visual.legs.visible = false
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
			# a Z floats up on every exhale, the odd one mid-breath
			if (phase > 0.55 and phase - delta / _cycle <= 0.55) or (phase > 0.8 and phase - delta / _cycle <= 0.8):
				_add_puff(global_position + Vector2(3, -9), Vector2(8, -13), 1.0, 2.8, 2)
			_snore_t -= delta
			if _snore_t <= 0.0:
				_snore_t = _cycle
				Audio.play_at("snore", global_position, -14.0, 0.08)
			if visual:
				# slumped back in the chair, chest rising and falling, head
				# lolling to one side
				var b := sin(_t * TAU / _cycle)
				visual.torso.position = Vector2(-2.0 + b * 0.4, 0)
				visual.torso.rotation = sin(_t * 0.35) * 0.18 + 0.12
				visual.torso.scale = Vector2(0.5 + b * 0.015, 0.5 + b * 0.02)
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
	if kind == Kind.SNOOZE:
		# snore bubble at the nose: swells on the in-breath, pops
		var inh := clampf(sin(phase * TAU) * 0.5 + 0.5, 0.0, 1.0)
		if phase < 0.5:
			var r := 0.4 + inh * 1.3
			var bp := Vector2(4.0 + r * 0.6, -0.8)
			draw_circle(bp, r, Color(0.75, 0.9, 1.0, 0.35))
			draw_arc(bp, r, 0, TAU, 12, Color(0.85, 0.95, 1.0, 0.8), 0.5)
			draw_circle(bp + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.9))
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
				# big comic Z with an ink outline, wobbling as it rises
				var zp: Vector2 = q.pos + Vector2(sin(q.t * 3.0) * 2.5, 0)
				draw_set_transform_matrix(inv * Transform2D(sin(q.t * 2.0) * 0.25, zp))
				var fs := int(7 + k * 7)
				var a := clampf(minf(q.t * 4.0, 1.0 - k), 0.0, 1.0)
				var f := UIStyle.font_bold()
				for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
					draw_string(f, o, "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.04, 0.03, 0.08, a))
				draw_string(f, Vector2.ZERO, "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.75, 0.88, 1.0, a))
				draw_set_transform_matrix(Transform2D.IDENTITY)

## Startled: drop whatever it was where they stand, and stop.
func drop() -> void:
	if kind != Kind.SNOOZE and is_inside_tree():
		# spawned deferred under the effects layer: this often runs while the
		# owner is mid-death / mid-teardown, when adding nodes isn't safe
		var fx := Effects.get_fx()
		if fx:
			var d := DroppedProp.new()
			d.kind = kind
			d.variant = _variant
			d.start_pos = _prop_pos(fmod(_t, _cycle) / _cycle)
			d.vel = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 30.0)
			fx.add_child.call_deferred(d)
	if visual:
		visual.torso.position = Vector2.ZERO
		visual.torso.rotation = 0.0
		visual.torso.scale = Vector2(0.5, 0.5)
		if kind == Kind.SNOOZE:
			visual.weapon_sprite.visible = true
			visual.legs.visible = true
	if _chair and is_instance_valid(_chair):
		# startled up: the chair tips over and stays where it was
		var fx := Effects.get_fx() if is_inside_tree() else null
		if fx:
			var gp := _chair.global_position
			var gr := _chair.global_rotation
			_chair.get_parent().remove_child(_chair)
			_chair.global_position = gp
			_chair.global_rotation = gr
			(_chair as SnoozeChair).tipped = true
			_chair.z_index = -1
			fx.add_child.call_deferred(_chair)
		else:
			_chair.queue_free()
	queue_free()


## A dropped cigarette (still smouldering), a rolling can, a half-eaten donut.
class DroppedProp extends Node2D:
	var kind := 0
	var variant := 0
	var vel := Vector2.ZERO
	var start_pos := Vector2.ZERO
	var t := 0.0
	func _ready() -> void:
		global_position = start_pos
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


## Folding metal chair he's sleeping in (rig space: +x is where he faces).
class SnoozeChair extends Node2D:
	var tipped := false
	func _ready() -> void:
		if tipped:
			rotation += 1.2
			queue_redraw()
	func _draw() -> void:
		var ink := Color("0b0710")
		var frame := Color(0.42, 0.44, 0.5)
		var seat := Color(0.6, 0.28, 0.2)
		if tipped:
			draw_rect(Rect2(-6, -5, 11, 10), ink)
			draw_rect(Rect2(-5, -4, 9, 8), seat.darkened(0.2))
			draw_line(Vector2(-7, -6), Vector2(-7, 6), frame, 1.5)
			return
		draw_set_transform(Vector2(0.5, 1.5), 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 7.5, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# seat, backrest behind him, the leg ends poking out
		draw_rect(Rect2(-6, -5.5, 11, 11), ink)
		draw_rect(Rect2(-5, -4.5, 9, 9), seat)
		draw_rect(Rect2(-5, -4.5, 9, 2), seat.lightened(0.2))
		draw_rect(Rect2(-9, -6.5, 3, 13), ink)
		draw_rect(Rect2(-8.5, -6, 2, 12), frame)
		for c in [Vector2(-6, -6), Vector2(-6, 6), Vector2(5, -6), Vector2(5, 6)]:
			draw_circle(c, 1.0, ink)
		# his feet stuck out in front, crossed at the ankles
		draw_rect(Rect2(6, -3.5, 7, 3), ink)
		draw_rect(Rect2(6, 0.5, 7, 3), ink)
		draw_rect(Rect2(6.5, -3, 6, 2), Color(0.2, 0.2, 0.26))
		draw_rect(Rect2(6.5, 1, 6, 2), Color(0.2, 0.2, 0.26))
		draw_rect(Rect2(12, -3.8, 2.5, 3.4), Color(0.12, 0.08, 0.06))
		draw_rect(Rect2(12, 0.4, 2.5, 3.4), Color(0.12, 0.08, 0.06))
