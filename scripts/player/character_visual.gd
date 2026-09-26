class_name CharacterVisual
extends Node2D
## Layered top-down pixel character: legs (face movement), torso (faces aim),
## held weapon, optional persona overlay. Handles walk cycle, recoil kick,
## melee swings, punches and hit flashes. Shared by player, enemies, NPCs.

var palette := "guard"
var legs: Sprite2D
var torso: Sprite2D
var weapon_sprite: Sprite2D
var overlay: Sprite2D
var rig: Node2D          ## rotates with aim; holds torso (0.5x hi-res art) + weapon (1x)
var shadow: Node2D
var outline_color := Color(0, 0, 0, 0)

var _walk_t := 0.0
var _breath_t := 0.0
var _move_blend := 0.0
var _kick := 0.0
var _swing_t := -1.0
var _swing_dur := 0.14
var _swing_dir := 1.0
var _swing_arc := 1.9
var _punch_t := -1.0
var _punch_left := true
var _flash := 0.0
var _hit_t := 0.0
var _hit_dir := Vector2.ZERO
var _fall_t := 0.0
var _death_t := 0.0
var _death_dir := Vector2.ZERO
var _hold: int = WeaponData.Hold.NONE
var _hand := Vector2(5, 0)
var aim_angle := 0.0

func _init() -> void:
	legs = Sprite2D.new()
	torso = Sprite2D.new()
	weapon_sprite = Sprite2D.new()
	overlay = Sprite2D.new()
	rig = Node2D.new()
	shadow = DropShadow.new()
	add_child(shadow)
	add_child(legs)
	add_child(rig)
	rig.add_child(torso)
	rig.add_child(weapon_sprite)
	rig.add_child(overlay)
	legs.scale = Vector2(0.5, 0.5)
	torso.scale = Vector2(0.5, 0.5)
	legs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = false
	overlay.visible = false
	for s in [legs, torso, weapon_sprite, overlay]:
		s.light_mask = 2

func setup(p_palette: String) -> void:
	palette = p_palette
	legs.texture = SpriteLib.legs(0, palette)
	set_weapon(null)

func set_persona_overlay(enabled: bool) -> void:
	overlay.visible = false   # v2 art bakes the persona into the sprite
	return
	if enabled:
		overlay.texture = SpriteLib.persona_overlay(palette)

func set_weapon(w: WeaponData) -> void:
	if w == null:
		_hold = WeaponData.Hold.NONE
		torso.texture = SpriteLib.torso("unarmed", palette)
		weapon_sprite.visible = false
		return
	_hold = w.hold
	torso.texture = SpriteLib.torso(SpriteLib.pose_for_hold(w.hold), palette)
	weapon_sprite.texture = SpriteLib.weapon(w.sprite_key)
	weapon_sprite.visible = true
	_hand = SpriteLib.hand_offset(w.hold)
	var tex_h := weapon_sprite.texture.get_height()
	# grip sits on the hand: offset so the handle end is at the hand position
	weapon_sprite.offset = Vector2(-2 if w.is_firearm() else -3, -tex_h * 0.5)
	weapon_sprite.position = _hand
	weapon_sprite.rotation = 0.0

func set_aim(angle: float) -> void:
	aim_angle = angle
	rig.rotation = angle + _twist

func update_move(vel: Vector2, delta: float) -> void:
	var speed := vel.length()
	var moving := clampf(speed / 105.0, 0.0, 1.0)
	_move_blend = lerpf(_move_blend, moving, minf(1.0, delta * 12.0))
	_breath_t += delta * (1.2 + _move_blend * 4.0)
	var breathe := sin(_breath_t) * (0.32 + _move_blend * 0.18)
	if speed > 8.0:
		_walk_t += delta * speed * 0.09
		legs.rotation = vel.angle()
		var f := int(_walk_t) % 4
		legs.texture = SpriteLib.legs([0, 1, 0, 2][f], palette)
		var stride := sin(_walk_t * 0.5)
		legs.position.y = stride * 0.7
		legs.scale = Vector2(0.5 + absf(stride) * 0.018, 0.5 - absf(stride) * 0.012)
	else:
		legs.texture = SpriteLib.legs(0, palette)
		legs.rotation = lerp_angle(legs.rotation, rig.rotation, minf(1.0, delta * 10.0))
		legs.position.y = 0.0
		legs.scale = Vector2.ONE * 0.5
	# Subtle breathing + movement lean make the sprite feel alive even when aiming.
	torso.position.y = breathe
	shadow.scale = Vector2(1.0 + _move_blend * 0.10, 1.0 - _move_blend * 0.07)

func kick_recoil(amount := 2.0) -> void:
	_kick = amount

var _stab := false
var _twist := 0.0

func swing(heavy := false, stab := false) -> void:
	_swing_t = 0.0
	_stab = stab and not heavy
	_swing_dur = 0.13 if heavy else (0.06 if _stab else 0.075)
	_swing_arc = 3.0 if heavy else 2.3
	_swing_dir *= -1.0
	_kick = -4.0 if _stab else -2.5   # body lunges forward with the blow

func punch() -> void:
	_punch_t = 0.0
	_punch_left = not _punch_left
	torso.texture = SpriteLib.torso("punch_l" if _punch_left else "punch_r", palette)

func flash(t := 0.08) -> void:
	_flash = t

func hit_react(dir: Vector2, heavy := false, duration := 0.12) -> void:
	_hit_dir = dir.normalized()
	_hit_t = maxf(duration, 0.08) * (1.35 if heavy else 1.0)
	_flash = maxf(_flash, 0.07 if not heavy else 0.12)
	_kick = 3.8 if heavy else 2.2

func fall(dir: Vector2) -> void:
	_fall_t = 0.24
	_hit_dir = dir.normalized()
	weapon_sprite.visible = false

func recover() -> void:
	_fall_t = 0.0
	_death_t = 0.0
	modulate = Color.WHITE
	scale = Vector2.ONE
	rig.scale = Vector2.ONE
	rig.position = Vector2.ZERO

func death_burst(dir: Vector2, heavy := false) -> void:
	_death_dir = dir.normalized()
	_death_t = 0.18 if heavy else 0.12
	_flash = 0.06

func is_swinging() -> bool:
	return _swing_t >= 0.0

func hand_global() -> Vector2:
	return rig.to_global(_hand + Vector2(6, 0))

func muzzle_global() -> Vector2:
	if weapon_sprite.visible and weapon_sprite.texture:
		var w := weapon_sprite.texture.get_width()
		return rig.to_global(_hand + Vector2(w - 2, 0))
	return rig.to_global(Vector2(10, 0))

func _process(delta: float) -> void:
	# recoil: torso pushed back along aim, with a tiny breathing pulse.
	_hit_t = maxf(0.0, _hit_t - delta)
	_fall_t = maxf(0.0, _fall_t - delta)
	_death_t = maxf(0.0, _death_t - delta)
	_kick = move_toward(_kick, 0.0, delta * 30.0)
	var breathe := sin(_breath_t) * (0.32 + _move_blend * 0.18)
	var hit_push := _hit_dir * (sin((_hit_t / 0.18) * PI) * 2.8 if _hit_t > 0.0 else 0.0)
	rig.position = Vector2.RIGHT.rotated(rig.rotation) * -_kick + Vector2(0, breathe) + hit_push
	if _hit_t > 0.0:
		rig.scale = Vector2(0.96, 1.05)
	else:
		rig.scale = rig.scale.lerp(Vector2.ONE, minf(1.0, delta * 18.0))
	if _fall_t > 0.0:
		var fk := 1.0 - _fall_t / 0.24
		rig.rotation = aim_angle + lerpf(0.0, _swing_dir * 0.7, fk)
		scale = Vector2(1.0 + fk * 0.08, 1.0 - fk * 0.18)
	elif _death_t > 0.0:
		var dk := 1.0 - _death_t / 0.18
		rig.position += _death_dir * dk * 4.0
		scale = Vector2(1.0 + dk * 0.12, 1.0 - dk * 0.16)
	else:
		scale = scale.lerp(Vector2.ONE, minf(1.0, delta * 14.0))
	if _swing_t >= 0.0:
		_swing_t += delta
		var k := clampf(_swing_t / _swing_dur, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 4.0)
		if _stab:
			weapon_sprite.rotation = 0.0
			weapon_sprite.position = _hand + Vector2(sin(k * PI) * 7.0, 0)
		else:
			weapon_sprite.rotation = _swing_dir * lerpf(-_swing_arc * 0.5, _swing_arc * 0.5, e)
			_twist = _swing_dir * sin(k * PI) * 0.2   # shoulders twist into the swing
		if _swing_t >= _swing_dur + 0.03:
			_swing_t = -1.0
			_twist = 0.0
			weapon_sprite.position = _hand
			var tw := create_tween()
			tw.tween_property(weapon_sprite, "rotation", 0.0, 0.08)
	if _punch_t >= 0.0:
		_punch_t += delta
		if _punch_t > 0.12:
			_punch_t = -1.0
			if _hold == WeaponData.Hold.NONE:
				torso.texture = SpriteLib.torso("unarmed", palette)
	if _flash > 0.0:
		_flash -= delta
		modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE


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
