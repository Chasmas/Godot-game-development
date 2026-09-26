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
	# posture: guns drift down to a low-ready carry when calm and snap up
	# fast when alerted (raising is quicker than lowering)
	var want_relax: float = [1.0, 0.5, 0.0][_posture]
	_relax = move_toward(_relax, want_relax, delta * (1.2 if want_relax > _relax else 6.0))
	if _swing_t < 0.0 and weapon_sprite.visible and _hold in [WeaponData.Hold.ONE_HAND, WeaponData.Hold.TWO_HAND]:
		weapon_sprite.rotation = 0.6 * _relax
	# per-gun recoil: the gun snaps back along its barrel and returns
	_gun_kick = move_toward(_gun_kick, 0.0, delta * 26.0)
	_gun_kick2 = move_toward(_gun_kick2, 0.0, delta * 26.0)
	if _swing_t < 0.0 and weapon_sprite.visible:
		weapon_sprite.position = _hand - Vector2(_gun_kick, 0)
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
