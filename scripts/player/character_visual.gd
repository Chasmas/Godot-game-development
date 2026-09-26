class_name CharacterVisual
extends Node2D
## Layered top-down pixel character: legs (face movement), torso (faces aim),
## held weapon, optional persona overlay. Handles walk cycle, recoil kick,
## melee swings, punches and hit flashes. Shared by player, enemies, NPCs.

var palette := "guard"
var legs: Sprite2D
var torso: Sprite2D
var weapon_sprite: Sprite2D
var weapon_sprite2: Sprite2D       ## off-hand gun when dual wielding
var dual := false
var _hand2 := Vector2(5, -2)
var _gun_kick := 0.0               ## per-hand slide recoil (right, left)
var _gun_kick2 := 0.0
var overlay: Sprite2D
var rig: Node2D          ## rotates with aim; holds torso (0.5x hi-res art) + weapon (1x)
var shadow: Node2D
var outline_color := Color(0, 0, 0, 0)

var _walk_t := 0.0
var _kick := 0.0
var _swing_t := -1.0
var _swing_dur := 0.14
var _swing_dir := 1.0
var _swing_arc := 1.9
var _punch_t := -1.0
var _punch_left := true
var _flash := 0.0
var _hold: int = WeaponData.Hold.NONE
var _hand := Vector2(5, 0)
var aim_angle := 0.0
## 0 relaxed (weapon lowered), 1 wary (half raised), 2 ready. Enemies set it
## from their AI state; everyone else stays ready.
var _kick_leg_t := -1.0
var _posture := 2
var _relax := 0.0

func _init() -> void:
	legs = Sprite2D.new()
	torso = Sprite2D.new()
	weapon_sprite = Sprite2D.new()
	weapon_sprite2 = Sprite2D.new()
	overlay = Sprite2D.new()
	rig = Node2D.new()
	shadow = DropShadow.new()
	add_child(shadow)
	add_child(legs)
	add_child(rig)
	rig.add_child(torso)
	rig.add_child(weapon_sprite)
	rig.add_child(weapon_sprite2)
	rig.add_child(overlay)
	legs.scale = Vector2(0.5, 0.5)
	torso.scale = Vector2(0.5, 0.5)
	legs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = false
	weapon_sprite2.centered = false
	weapon_sprite2.flip_v = true
	weapon_sprite2.visible = false
	overlay.visible = false
	for s in [legs, torso, weapon_sprite, weapon_sprite2, overlay]:
		s.light_mask = 2

## Body language per archetype: walking sway (radians), forward lean while
## moving (px), and gait bounce. Small, but it lets you tell a swaggering
## gunner from a lumbering heavy before you can see their colours.
const MANNER := {
	"cass":   {"sway": 0.05, "lean": 0.8, "bounce": 0.35},
	"guard":  {"sway": 0.03, "lean": 0.4, "bounce": 0.25},
	"gunner": {"sway": 0.11, "lean": 0.2, "bounce": 0.45},
	"hunter": {"sway": 0.04, "lean": 1.6, "bounce": 0.3},
	"heavy":  {"sway": 0.08, "lean": 0.3, "bounce": 0.6},
	"scout":  {"sway": 0.06, "lean": 1.0, "bounce": 0.5},
	"riot":   {"sway": 0.02, "lean": 0.6, "bounce": 0.15},
	"boss":   {"sway": 0.03, "lean": 0.0, "bounce": 0.2},
}
var _manner: Dictionary = {}
var _manner_off := 0.0
var _speed_k := 0.0

func setup(p_palette: String) -> void:
	palette = p_palette
	_manner = MANNER.get(SpriteForge.base_name(p_palette), {"sway": 0.04, "lean": 0.5, "bounce": 0.3})
	legs.texture = SpriteLib.legs(0, palette)
	set_weapon(null)

func set_persona_overlay(enabled: bool) -> void:
	overlay.visible = false   # v2 art bakes the persona into the sprite
	return
	if enabled:
		overlay.texture = SpriteLib.persona_overlay(palette)

func set_weapon(w: WeaponData, p_dual := false) -> void:
	dual = p_dual and w != null and w.is_firearm()
	weapon_sprite2.visible = false
	if w == null:
		_hold = WeaponData.Hold.NONE
		torso.texture = SpriteLib.torso("unarmed", palette)
		weapon_sprite.visible = false
		return
	_hold = w.hold
	var pose := "aim_dual" if dual else SpriteLib.pose_for_hold(w.hold)
	torso.texture = SpriteLib.torso(pose, palette)
	weapon_sprite.texture = SpriteLib.weapon(w.sprite_key)
	weapon_sprite.visible = true
	_hand = SpriteForge.hand_world("aim_dual") if dual else SpriteLib.hand_offset(w.hold)
	var tex_h := weapon_sprite.texture.get_height()
	# grip sits on the hand: offset so the handle end is at the hand position
	weapon_sprite.offset = Vector2(-2 if w.is_firearm() else -3, -tex_h * 0.5)
	weapon_sprite.position = _hand
	weapon_sprite.rotation = 0.0
	if dual:
		_hand2 = SpriteForge.hand_world("aim_dual_l")
		weapon_sprite2.texture = weapon_sprite.texture
		weapon_sprite2.offset = Vector2(-2, -tex_h * 0.5)
		weapon_sprite2.position = _hand2
		weapon_sprite2.rotation = 0.0
		weapon_sprite2.visible = true

func set_aim(angle: float) -> void:
	aim_angle = angle
	rig.rotation = angle + _twist + _manner_off

func update_move(vel: Vector2, delta: float) -> void:
	# mannerisms: shoulders sway with the stride, torso leans into the walk
	_speed_k = move_toward(_speed_k, clampf(vel.length() / 150.0, 0.0, 1.2), delta * 6.0)
	if not _manner.is_empty():
		_manner_off = sin(_walk_t * PI * 0.5) * float(_manner.sway) * _speed_k
		# torso is inside the rig, which already faces the aim: +x is forward
		var bounce := absf(sin(_walk_t * PI * 0.5)) * float(_manner.bounce) * _speed_k
		torso.position = Vector2(float(_manner.lean) * _speed_k + bounce * 0.5, 0.0)
	if _kick_leg_t > 0.0:
		_kick_leg_t -= delta
		legs.rotation = rig.rotation
		legs.texture = SpriteLib.legs(1 if _kick_leg_t > 0.08 else 2, palette)
		legs.position = Vector2.RIGHT.rotated(rig.rotation) * (3.0 * sin(clampf(_kick_leg_t / 0.2, 0.0, 1.0) * PI))
		return
	legs.position = Vector2.ZERO
	var speed := vel.length()
	if speed > 8.0:
		_walk_t += delta * speed * 0.09
		legs.rotation = vel.angle()
		var f := int(_walk_t) % 4
		legs.texture = SpriteLib.legs([0, 1, 0, 2][f], palette)
	else:
		legs.texture = SpriteLib.legs(0, palette)
		legs.rotation = lerp_angle(legs.rotation, rig.rotation, minf(1.0, delta * 10.0))

func set_alert_posture(p: int) -> void:
	_posture = clampi(p, 0, 2)

## Front kick: the leading leg snaps out along the aim and the body leans in.
func kick_leg() -> void:
	_kick_leg_t = 0.2
	_kick = -3.5

func kick_recoil(amount := 2.0) -> void:
	_kick = amount

## One gun's slide/recoil when firing (the body kick is kick_recoil).
func gun_recoil(left: bool, amount: float) -> void:
	if left:
		_gun_kick2 = amount
	else:
		_gun_kick = amount

var _stab := false
var _twist := 0.0
var _heavy_swing := false
var _ghosts: Array[Sprite2D] = []
var _ghost_rot: Array[float] = []
## reload animation: 0..1 progress, kind "mag" / "shell" / "dual"
var _reload_k := -1.0
var _reload_dur := 1.0
var _reload_kind := "mag"
var _reload_step := 0
var _mag: Node2D = null

func swing(heavy := false, stab := false) -> void:
	_swing_t = 0.0
	_stab = stab and not heavy
	# a touch longer than before: the extra time is anticipation and
	# follow-through, the strike itself is as fast as ever
	_swing_dur = 0.19 if heavy else (0.09 if _stab else 0.12)
	_swing_arc = 3.2 if heavy else 2.5
	_swing_dir *= -1.0
	_heavy_swing = heavy
	_kick = -4.5 if _stab else -3.0   # body lunges forward with the blow
	if is_inside_tree() and palette.begins_with("cass"):
		Audio.play_at("whoosh", global_position, -8.0 if heavy else -12.0, 0.15)

func punch() -> void:
	_punch_t = 0.0
	_kick = -3.5
	torso.scale = Vector2(0.54, 0.48)
	create_tween().tween_property(torso, "scale", Vector2(0.5, 0.5), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_left = not _punch_left
	torso.texture = SpriteLib.torso("punch_l" if _punch_left else "punch_r", palette)

func flash(t := 0.08) -> void:
	_flash = t

func is_swinging() -> bool:
	return _swing_t >= 0.0

func hand_global() -> Vector2:
	return rig.to_global(_hand + Vector2(6, 0))

func muzzle_global(left := false) -> Vector2:
	if left and dual and weapon_sprite2.texture:
		return rig.to_global(_hand2 + Vector2(weapon_sprite2.texture.get_width() - 2, 0))
	if weapon_sprite.visible and weapon_sprite.texture:
		var w := weapon_sprite.texture.get_width()
		return rig.to_global(_hand + Vector2(w - 2, 0))
	return rig.to_global(Vector2(10, 0))

func _process(delta: float) -> void:
	# recoil: torso pushed back along aim
	_kick = move_toward(_kick, 0.0, delta * 30.0)
	rig.position = Vector2.RIGHT.rotated(rig.rotation) * -_kick
	if _swing_t >= 0.0:
		_swing_t += delta
		var k := clampf(_swing_t / _swing_dur, 0.0, 1.0)
		if _stab:
			# knife: small draw-back, fast thrust, snap back
			var d := -2.0 * sin(clampf(k / 0.25, 0.0, 1.0) * PI * 0.5) if k < 0.25 else 8.0 * sin(clampf((k - 0.25) / 0.75, 0.0, 1.0) * PI)
			weapon_sprite.rotation = 0.0
			weapon_sprite.position = _hand + Vector2(d, 0)
			torso.scale = Vector2(0.5 + 0.04 * clampf(d / 8.0, 0.0, 1.0), 0.5 - 0.02 * clampf(d / 8.0, 0.0, 1.0))
		else:
			# anticipation -> strike (expo ease-out) -> overshoot and settle
			var a := _swing_arc
			var rot: float
			if k < 0.22:
				var w := sin(k / 0.22 * PI * 0.5)
				rot = lerpf(-a * 0.5, -a * 0.72, w)
				torso.scale = Vector2(0.5 - 0.03 * w, 0.5 + 0.015 * w)      # coil
			elif k < 0.62:
				var w2 := 1.0 - pow(2.0, -10.0 * (k - 0.22) / 0.4)
				rot = lerpf(-a * 0.72, a * 0.62, w2)
				torso.scale = Vector2(0.5 + 0.045 * (1.0 - w2), 0.5 - 0.02 * (1.0 - w2))   # stretch into the blow
			else:
				var w3 := (k - 0.62) / 0.38
				rot = lerpf(a * 0.62, a * 0.5, w3 * w3)
				torso.scale = Vector2(0.5, 0.5)
			weapon_sprite.rotation = _swing_dir * rot
			_twist = _swing_dir * (sin(clampf((k - 0.1) / 0.7, 0.0, 1.0) * PI) * (0.32 if _heavy_swing else 0.24) - (0.12 if k < 0.22 else 0.0))
			_push_ghost()
		if _swing_t >= _swing_dur + 0.03:
			_swing_t = -1.0
			_twist = 0.0
			torso.scale = Vector2(0.5, 0.5)
			weapon_sprite.position = _hand
			var tw := create_tween()
			tw.tween_property(weapon_sprite, "rotation", 0.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_ghosts(delta)
	_update_reload(delta)
	# posture: guns drift down to a low-ready carry when calm and snap up
	# fast when alerted (raising is quicker than lowering)
	var want_relax: float = [1.0, 0.5, 0.0][_posture]
	_relax = move_toward(_relax, want_relax, delta * (1.2 if want_relax > _relax else 6.0))
	if _swing_t < 0.0 and _reload_k < 0.0 and weapon_sprite.visible and _hold in [WeaponData.Hold.ONE_HAND, WeaponData.Hold.TWO_HAND]:
		weapon_sprite.rotation = 0.6 * _relax
	# per-gun recoil: the gun snaps back along its barrel and returns
	_gun_kick = move_toward(_gun_kick, 0.0, delta * 26.0)
	_gun_kick2 = move_toward(_gun_kick2, 0.0, delta * 26.0)
	if _swing_t < 0.0 and _reload_k < 0.0 and weapon_sprite.visible:
		weapon_sprite.position = _hand - Vector2(_gun_kick, 0)
		# the gun flips up a little with the kick, then settles
		weapon_sprite.rotation = -0.09 * _gun_kick + 0.6 * _relax * float(_hold in [WeaponData.Hold.ONE_HAND, WeaponData.Hold.TWO_HAND])
		if dual:
			weapon_sprite2.position = _hand2 - Vector2(_gun_kick2, 0)
	if _punch_t >= 0.0:
		_punch_t += delta
		if _punch_t > 0.12:
			_punch_t = -1.0
			if _hold == WeaponData.Hold.NONE:
				torso.texture = SpriteLib.torso("unarmed", palette)
	if _flash > 0.0:
		_flash -= delta
		modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE


# ---------------------------------------------------------------- swing ghosts
## Afterimages of the weapon through the strike: a few fading copies that
## read as a smear at game speed.
func _push_ghost() -> void:
	if not weapon_sprite.visible or weapon_sprite.texture == null:
		return
	var g: Sprite2D
	if _ghosts.size() < 4:
		g = Sprite2D.new()
		g.centered = false
		g.light_mask = 2
		rig.add_child(g)
		rig.move_child(g, weapon_sprite.get_index())
		_ghosts.append(g)
	else:
		g = _ghosts.pop_front()
		_ghosts.append(g)
	g.texture = weapon_sprite.texture
	g.offset = weapon_sprite.offset
	g.position = weapon_sprite.position
	g.rotation = weapon_sprite.rotation
	g.modulate = Color(1.6, 1.5, 1.4, 0.45)
	g.visible = true

func _fade_ghosts(delta: float) -> void:
	for g in _ghosts:
		if g.visible:
			g.modulate.a -= delta * 5.0
			if g.modulate.a <= 0.0:
				g.visible = false

# ---------------------------------------------------------------- reload
## Play a reload over `dur` seconds. "mag": tilt, mag drops out, a fresh one
## comes up from the belt and slaps in, slide racked. "shell": shells go in
## one at a time, then the pump. "dual": both guns dump and reload in turn.
func reload_anim(dur: float, kind := "mag") -> void:
	if not weapon_sprite.visible:
		return
	_reload_k = 0.0
	_reload_dur = maxf(dur, 0.2)
	_reload_kind = kind
	_reload_step = 0

func cancel_reload() -> void:
	if _reload_k >= 0.0:
		_reload_k = -1.0
		weapon_sprite.rotation = 0.0
		weapon_sprite.position = _hand
		if _mag:
			_mag.queue_free()
			_mag = null

func _sfx(name: String, vol := -6.0) -> void:
	if is_inside_tree():
		Audio.play_at(name, global_position, vol, 0.06)

func _update_reload(delta: float) -> void:
	if _reload_k < 0.0:
		return
	_reload_k += delta / _reload_dur
	var k := _reload_k
	if k >= 1.0:
		_reload_k = -1.0
		weapon_sprite.rotation = 0.0
		weapon_sprite.position = _hand
		if _mag:
			_mag.queue_free()
			_mag = null
		return
	var tilt := 0.0
	var dip := Vector2.ZERO
	if _reload_kind == "shell":
		# tilt the gun, thumb in a shell every beat, pump at the end
		tilt = 0.55 * sin(clampf(k / 0.12, 0.0, 1.0) * PI * 0.5) * (1.0 - clampf((k - 0.86) / 0.1, 0.0, 1.0))
		var shells := 4
		var step := int(clampf((k - 0.12) / 0.72, 0.0, 0.999) * shells)
		var local := fmod(clampf((k - 0.12) / 0.72, 0.0, 0.999) * shells, 1.0)
		if k > 0.12 and k < 0.84:
			dip = Vector2(0, 1.2 * sin(local * PI))
			if step >= _reload_step:
				_reload_step = step + 1
				_sfx("shell_insert", -8.0)
		if k > 0.88 and _reload_step < 99:
			_reload_step = 99
			_sfx("slide_rack", -4.0)
			_gun_kick = 3.0
	else:
		# 0-15% tilt, 15% mag out, 30-65% new mag travels up, 65% slap in,
		# 80% rack, then back on target
		tilt = 0.8 * sin(clampf(k / 0.15, 0.0, 1.0) * PI * 0.5) * (1.0 - clampf((k - 0.82) / 0.14, 0.0, 1.0))
		if k > 0.15 and _reload_step == 0:
			_reload_step = 1
			_sfx("mag_out", -6.0)
			_drop_mag()
		if k > 0.3 and _reload_step == 1:
			_reload_step = 2
			_mag = _MagInHand.new()
			rig.add_child(_mag)
		if _mag and _reload_step == 2:
			var mk := clampf((k - 0.3) / 0.35, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - mk, 3.0)
			_mag.position = Vector2(-2, 7).lerp(_hand + Vector2(2, 2), e)
			_mag.rotation = lerpf(1.2, 0.3, e)
		if k > 0.65 and _reload_step == 2:
			_reload_step = 3
			_sfx("mag_in", -4.0)
			dip = Vector2(0, -1.5)
			if _mag:
				_mag.queue_free()
				_mag = null
		if k > 0.8 and _reload_step == 3:
			_reload_step = 4
			_sfx("slide_rack", -5.0)
			_gun_kick = 2.5
	weapon_sprite.rotation = tilt
	weapon_sprite.position = _hand + dip - Vector2(_gun_kick, 0) + Vector2(-2.0 * tilt, 1.5 * tilt)
	if dual:
		weapon_sprite2.rotation = -tilt * 0.7
		weapon_sprite2.position = _hand2 + Vector2(-2.0 * tilt, -1.0 * tilt)

## The empty magazine falls out and clatters on the floor (stays a moment).
func _drop_mag() -> void:
	if not is_inside_tree():
		return
	var fx := Effects.get_fx()
	if fx == null:
		return
	var m := _DroppedMag.new()
	m.start_pos = rig.to_global(_hand + Vector2(1, 3))
	m.rotation = rig.global_rotation + randf_range(-0.6, 0.6)
	m.vel = Vector2.from_angle(rig.global_rotation + PI * 0.6 * (1.0 if randf() < 0.5 else -1.0)) * randf_range(20.0, 40.0)
	fx.add_child.call_deferred(m)


class _MagInHand extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-1.5, -2.5, 3, 5), Color("0b0710"))
		draw_rect(Rect2(-1, -2, 2, 4), Color("3a3a44"))
		draw_rect(Rect2(-1, -2, 2, 1), Color("c8a040"))


class _DroppedMag extends Node2D:
	var vel := Vector2.ZERO
	var start_pos := Vector2.ZERO
	var t := 0.0
	func _ready() -> void:
		global_position = start_pos
		z_index = -1
	func _process(d: float) -> void:
		t += d
		position += vel * d
		vel = vel.move_toward(Vector2.ZERO, 160.0 * d)
		rotation += vel.length() * 0.02 * d * 10.0
		if t > 0.18 and t - d <= 0.18:
			Audio.play_at("metal_clang", global_position, -18.0, 0.2)
		if t > 6.0:
			modulate.a -= d
			if modulate.a <= 0.0:
				queue_free()
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(-1.5, -2.5, 3, 5), Color("0b0710"))
		draw_rect(Rect2(-1, -2, 2, 4), Color("2a2a32"))


## Soft elliptical contact shadow (does not rotate), grounds the character.
class DropShadow extends Node2D:
	func _ready() -> void:
		z_index = -1
		z_as_relative = true
		show_behind_parent = true
	func _draw() -> void:
		draw_set_transform(Vector2(1.5, 2.5), 0.0, Vector2(1.0, 0.62))
		draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.28))
		draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.22))
