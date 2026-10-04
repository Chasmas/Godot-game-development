class_name CharacterVisual
extends Node2D
## Layered top-down pixel character: legs (face movement), torso (faces aim),
## held weapon, optional persona overlay. Handles walk cycle, recoil kick,
## melee swings, punches and hit flashes. Shared by player, enemies, NPCs.

var palette := "guard"
var cast_sprite: CastSprite
var _cast_velocity := Vector2.ZERO
var legs: Sprite2D
var torso: Sprite2D
var weapon_sprite: Sprite2D
var _wd := 1.0          ## the held weapon sprite's pixel density (drawn at 1 / _wd)
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
	_leg = KickLeg.new()
	_leg.vis = self
	_leg.visible = false
	_leg.light_mask = 2
	rig.add_child(_leg)
	_arm = MeleeArm.new()
	_arm.vis = self
	_arm.visible = false
	_arm.light_mask = 2
	rig.add_child(_arm)
	rig.add_child(weapon_sprite)
	rig.add_child(weapon_sprite2)
	rig.add_child(overlay)
	legs.scale = Vector2(0.5, 0.5)
	torso.scale = Vector2(0.5, 0.5)
	legs.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for spr in [torso, weapon_sprite, weapon_sprite2, overlay]:
		if spr:
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	"bellhop": {"sway": 0.03, "lean": 1.2, "bounce": 0.45},
	"biker":  {"sway": 0.1, "lean": 0.3, "bounce": 0.4},
	"scrapper": {"sway": 0.06, "lean": 1.0, "bounce": 0.35},
	"welder": {"sway": 0.04, "lean": 0.2, "bounce": 0.5},
}
var _manner: Dictionary = {}
var _manner_off := 0.0
var _speed_k := 0.0

func setup(p_palette: String) -> void:
	if cast_sprite:
		cast_sprite.queue_free()
		cast_sprite = null
	legs.visible = true
	torso.visible = true
	palette = p_palette
	_manner = MANNER.get(SpriteForge.base_name(p_palette), {"sway": 0.04, "lean": 0.5, "bounce": 0.3})
	legs.texture = SpriteLib.legs(0, palette)
	set_weapon(null)
	# Cass now has an approved top-down PixelLab pose set.  Keep her in the
	# normal 2D combat rig when it is present: that preserves weapon grips,
	# recoil and smooth aiming instead of swapping to the older 3D cast.
	if p_palette == "cass" and not SpriteForge.has_pose_art(p_palette) and OS.get_environment("CAST_LEGACY") != "1":
		var candidate := CastSprite.new()
		if candidate.configure("cass"):
			cast_sprite = candidate
			rig.add_child(cast_sprite)
			rig.move_child(cast_sprite, 0)
			cast_sprite.play_sample("idle", 0.0)
			legs.visible = false
			torso.visible = false
		else:
			candidate.free()

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
	_rest_torso = null
	var pose := "aim_dual" if dual else SpriteLib.pose_for_hold(w.hold)
	torso.texture = SpriteLib.torso(pose, palette)
	weapon_sprite.texture = SpriteLib.weapon(w.sprite_key)
	weapon_sprite.visible = true
	_wd = SpriteLib.weapon_density(w.sprite_key)
	# a touch smaller than the painting's scale: guns in hand, not guns as big as her
	weapon_sprite.scale = Vector2.ONE * (0.8 if w.is_firearm() else 0.9) / _wd
	weapon_sprite2.scale = weapon_sprite.scale
	_hand = SpriteForge.hand_world("aim_dual") if dual else SpriteLib.hand_offset(w.hold)
	var tex_h := weapon_sprite.texture.get_height()
	# the grip in the hand: guns by the bottom of the handle's column, the
	# barrel line through the hand; melee weapons by the end of the handle
	_firearm = w.is_firearm()
	weapon_sprite.offset = _grip_offset(weapon_sprite.texture, false)
	weapon_sprite.position = _hand
	weapon_sprite.rotation = 0.0
	if dual:
		_hand2 = SpriteForge.hand_world("aim_dual_l")
		weapon_sprite2.texture = weapon_sprite.texture
		weapon_sprite2.offset = _grip_offset(weapon_sprite.texture, true)
		weapon_sprite2.position = _hand2
		weapon_sprite2.rotation = 0.0
		weapon_sprite2.visible = true

func set_aim(angle: float) -> void:
	aim_angle = angle
	if _roll_t >= 0.0:
		return   # mid-roll the body turns with the roll, not the aim
	rig.rotation = angle + _twist + _manner_off

func update_move(vel: Vector2, delta: float) -> void:
	if cast_sprite:
		_cast_velocity = vel
		_still_t = _still_t + delta if vel.length() < 8.0 and _roll_t < 0.0 and _swing_t < 0.0 and _punch_t < 0.0 else 0.0
		return
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
		legs.texture = SpriteLib.legs(0, palette)
		legs.position = Vector2.ZERO
		_leg.visible = true
		_leg.queue_redraw()
		if _kick_leg_t <= 0.0:
			_leg.visible = false
		return
	legs.position = Vector2.ZERO
	var speed := vel.length()
	var moving := clampf(speed / 105.0, 0.0, 1.0)
	_move_blend = lerpf(_move_blend, moving, minf(1.0, delta * 12.0))
	# standing still long enough, the fidgets start (see _apply_idle)
	if moving < 0.05 and _swing_t < 0.0 and _punch_t < 0.0 and _reload_k < 0.0 and _roll_t < 0.0:
		_still_t += delta
	else:
		_still_t = 0.0
	_breath_t += delta * (1.2 + _move_blend * 4.0)
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
	# breathing is applied to the whole rig in _process; the torso's own
	# offset belongs to manners, idle poses (dozing) and the handler's gait
	shadow.scale = Vector2(1.0 + _move_blend * 0.10, 1.0 - _move_blend * 0.07)

func set_alert_posture(p: int) -> void:
	_posture = clampi(p, 0, 2)

## Front kick: the leading leg snaps out along the aim and the body leans in.
func kick_leg() -> void:
	_kick_leg_t = KICK_TIME
	_kick = 2.0   # she leans back to put the foot through

const KICK_TIME := 0.3
var _leg: KickLeg
var _mount := false          ## astride someone on the floor (unarmed execution)
var _punch_reach := 6.5

func set_mount(on: bool) -> void:
	_mount = on
	_leg.visible = on or _kick_leg_t > 0.0
	_leg.queue_redraw()

## A punch on someone on the floor: the fist comes down from high, harder
## and slower for the last one.
func ground_punch(big: bool) -> void:
	_punch_reach = 9.0 if big else 7.5
	punch()
	_kick = -6.0 if big else -4.0

func kick_recoil(amount := 2.0) -> void:
	_still_t = 0.0
	_kick = amount

## One gun's slide/recoil when firing (the body kick is kick_recoil).
func gun_recoil(left: bool, amount: float) -> void:
	_still_t = 0.0
	if left:
		_gun_kick2 = amount
	else:
		_gun_kick = amount

var _stab := false
var _rest_torso: Texture2D   ## the pose to go back to after a swing
var _arm: MeleeArm           ## the striking arm(s), drawn live during melee
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
	# the live arms do the work: the torso drops its baked-in holding arms
	# for the blow and gets them back after
	if _rest_torso == null:
		_rest_torso = torso.texture
	torso.texture = SpriteLib.torso("unarmed", palette)
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

# ---------------------------------------------------------------- idle
## Only the player's character fidgets (idle_fidgets is set by Player).
var idle_fidgets := false
var _still_t := 0.0
var _fidget := ""
var _fidget_t := 0.0
var _cig: CigaretteFx

## Standing still, she's never quite still: a gun gets checked (tilted up,
## the cylinder spun), a blade flips over in her hand, bare fists bounce like
## a boxer's; left long enough she lights a cigarette. Anything she does
## breaks it off at once.
func _apply_idle(delta: float) -> void:
	if not idle_fidgets:
		return
	if _still_t < 2.5:
		if _fidget != "":
			_fidget = ""
			weapon_sprite.rotation = 0.0
			weapon_sprite.position = _hand
		if _cig and _still_t < 0.1:
			_cig.put_out()
			_cig = null
		return
	if _fidget == "":
		_fidget_t = 0.0
		if not weapon_sprite.visible:
			_fidget = "box"
		elif _hold in [WeaponData.Hold.MELEE_ONE] :
			_fidget = "flip"
		else:
			_fidget = "check"
	_fidget_t += delta
	var k := fmod(_fidget_t, 4.5)
	match _fidget:
		"check":
			# tilt the gun up to look it over, a little shake, back down
			var up := sin(clampf(k / 1.4, 0.0, 1.0) * PI)
			weapon_sprite.rotation = -0.9 * up
			weapon_sprite.position = _hand + Vector2(-2.0 * up, -1.5 * up)
			if k > 0.6 and k < 0.62 + delta:
				_sfx("slide_rack", -20.0)
		"flip":
			# the blade turns over in her fingers
			var f := clampf((k - 0.3) / 0.5, 0.0, 1.0)
			weapon_sprite.rotation = TAU * f * f * (3.0 - 2.0 * f) if k < 1.0 else 0.0
		"box":
			# up on her toes
			rig.position.y += sin(_fidget_t * 9.0) * 0.6
			rig.position.x += sin(_fidget_t * 4.5) * 0.4
	# a cigarette, eventually
	if _still_t > 9.0 and _cig == null and palette.begins_with("cass"):
		_cig = CigaretteFx.new()
		_cig.vis = self
		rig.add_child(_cig)
		_sfx("light_switch", -22.0)

## The cigarette: an ember at her lips that brightens as she draws on it,
## and smoke drifting up off it. Put out the moment she moves.
class CigaretteFx extends Node2D:
	var vis: Node
	var _t := 0.0
	var _puffs: Array = []
	var _out := -1.0
	var art: Texture2D
	var _mouth := Vector2.ZERO
	var _emit_t := 0.0
	func _ready() -> void:
		z_index = 4
		position = Vector2(4.5, -1.0)
		art = load("res://assets/art/sprites/cigarette_pixellab.png") as Texture2D
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func put_out() -> void:
		_out = 0.0
	func _process(delta: float) -> void:
		_t += delta
		if vis.cast_sprite != null and _out < 0.0:
			position = vis.cast_sprite.grip()
		if _out >= 0.0:
			_out += delta
			if _out > 0.6:
				queue_free()
		else:
			var phase := fposmod(float(vis.cast_sprite.clock), 4.0) / 4.0 if vis.cast_sprite != null else fposmod(_t, 4.0) / 4.0
			if phase >= 0.22 and phase <= 0.48:
				_mouth = to_global(Vector2.ZERO)
			var exhale := phase > 0.50 and phase < 0.68 and _mouth != Vector2.ZERO
			_emit_t -= delta
			if _emit_t <= 0.0:
				_emit_t = 0.12 if exhale else 0.55
				_puffs.append({"p": _mouth if exhale else to_global(Vector2(2.8, 0)), "t": 0.0, "big": exhale, "d": Vector2(randf_range(-1.5, 1.5), randf_range(-5, -3))})
		for p in _puffs:
			p.t = float(p.t) + delta
			p.p = (p.p as Vector2) + (p.d as Vector2) * delta + Vector2(sin(_t * 2.0 + float(p.t) * 3.0) * delta, 0)
		_puffs = _puffs.filter(func(p): return float(p.t) < 2.2)
		queue_redraw()
	func _draw() -> void:
		var draw_ := sin(_t * 0.9) > 0.6
		var a := 1.0 - clampf(_out / 0.6, 0.0, 1.0) if _out >= 0.0 else 1.0
		for p in _puffs:
			var k: float = float(p.t) / 2.2
			draw_circle(to_local(p.p as Vector2), (0.6 + k * 1.7) if p.big else (0.25 + k * 0.8), Color(0.8, 0.8, 0.85, (0.23 if p.big else 0.12) * (1.0 - k) * a))
		if art:
			draw_set_transform(Vector2.ZERO, 0.98, Vector2.ONE * 0.12)
			draw_texture(art, Vector2(-7, -28), Color(1, 1, 1, a))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_line(Vector2.ZERO, Vector2(2.5, 0), Color(0.95, 0.93, 0.88, a), 1.0)
		draw_circle(Vector2(2.8, 0), 0.18 if not draw_ else 0.28, Color(1.0, 0.45 if draw_ else 0.3, 0.1, a))

# ---------------------------------------------------------------- the roll
var _roll_t := -1.0
var _roll_dur := 0.3
var _roll_dir := Vector2.RIGHT
var _roll_ghost_t := 0.0

## A dodge roll: she tucks, goes over her shoulder in the direction of travel
## and comes up facing her aim again. Seen from above: the body squashes into
## a ball, turns a full circle along the roll, the legs fold away, the gun
## is tucked in, dust kicks up at the push-off and the landing.
func roll(dir: Vector2, dur: float) -> void:
	_roll_t = 0.0
	_roll_dur = maxf(dur, 0.12)
	_roll_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	_roll_ghost_t = 0.0

func is_rolling() -> bool:
	return _roll_t >= 0.0

func _apply_roll(delta: float) -> void:
	if _roll_t < 0.0:
		return
	_roll_t += delta
	var k := clampf(_roll_t / _roll_dur, 0.0, 1.0)
	if k >= 1.0:
		_roll_t = -1.0
		legs.visible = true
		weapon_sprite.modulate.a = 1.0
		shadow.scale = Vector2.ONE
		return
	# ease: quick tuck, the turn over the shoulder, a soft unfold
	var tuck := sin(k * PI)
	var turn := k * k * (3.0 - 2.0 * k)
	rig.rotation = _roll_dir.angle() + TAU * turn
	rig.scale = Vector2(1.0 - 0.38 * tuck, 1.0 - 0.18 * tuck)
	rig.position = _roll_dir * (-1.5 * tuck)
	legs.visible = k < 0.12 or k > 0.88
	weapon_sprite.modulate.a = 1.0 - 0.8 * tuck
	shadow.scale = Vector2.ONE * (1.0 - 0.25 * tuck)
	# afterimages while she's over
	_roll_ghost_t -= delta
	if _roll_ghost_t <= 0.0 and k > 0.1 and k < 0.8:
		_roll_ghost_t = 0.035
		var g := Sprite2D.new()
		g.texture = torso.texture
		g.scale = torso.scale * rig.scale
		g.global_position = rig.global_position
		g.rotation = rig.rotation
		g.modulate = Color(1.0, 0.5, 0.8, 0.35)
		g.z_index = z_index - 1
		g.top_level = true
		add_child(g)
		var tw := g.create_tween()
		tw.tween_property(g, "modulate:a", 0.0, 0.18)
		tw.tween_callback(g.queue_free)

## The pump racked back and forward after a shotgun blast.
func pump() -> void:
	_gun_kick = 3.2
	_kick = minf(_kick, -1.0)

func punch() -> void:
	_punch_t = 0.0
	_kick = -3.5
	torso.scale = Vector2(0.54, 0.48)
	create_tween().tween_property(torso, "scale", Vector2(0.5, 0.5), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_left = not _punch_left
	# the arm is drawn live (out from the shoulder and back); the torso keeps
	# its guard pose so there's never a second, frozen arm
	torso.texture = SpriteLib.torso("unarmed", palette)
	_arm.visible = true
	_arm.queue_redraw()

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

func muzzle_global(left := false) -> Vector2:
	var sp := weapon_sprite2 if (left and dual and weapon_sprite2.texture) else weapon_sprite
	if sp.visible and sp.texture:
		# the barrel's real tip in the picture, through the sprite's own
		# transform (tilt, recoil, the flip when aiming left)
		var tip := _barrel_tip(sp.texture)
		var y := tip.y - sp.texture.get_height() * 0.5
		if sp.flip_v:
			y = -y
		return sp.to_global(Vector2(sp.offset.x + tip.x, sp.offset.y + sp.texture.get_height() * 0.5 + y))
	return rig.to_global(Vector2(10, 0))

var _firearm := true

## Offset (texture px) that puts a weapon picture's grip on the hand. For a
## gun: the lowest solid point is the bottom of the handle; the hand holds
## just above it, the barrel line (the muzzle's height) runs through it.
static var _grips: Dictionary = {}
func _grip_offset(tex: Texture2D, flipped: bool) -> Vector2:
	var h := float(tex.get_height())
	var tip := _barrel_tip(tex)
	var gx: float
	if true:
		# seen from above: held a third of the way back (guns) or by the end
		# of the handle (melee), on the weapon's centre line
		gx = float(tex.get_width()) * (0.3 if _firearm else 0.12)
		return Vector2(-gx, -h * 0.5)
	if _firearm:
		var k := tex.get_rid()
		if not _grips.has(k):
			var img := tex.get_image()
			var gxx := tex.get_width() * 0.25
			if img:
				if img.is_compressed():
					img.decompress()
				# lowest row with pixels, in the back half of the gun
				for y in range(img.get_height() - 1, -1, -1):
					var xs := []
					for x in int(img.get_width() * 0.7):
						if img.get_pixel(x, y).a > 0.5:
							xs.append(x)
					if xs.size() > 0:
						gxx = (float(xs[0]) + float(xs[-1])) * 0.5
						break
			_grips[k] = gxx
		gx = _grips[k]
	else:
		gx = 2.0 * _wd
	var by := tip.y if not flipped else h - tip.y
	return Vector2(-gx, -by)

## Where the muzzle is in a weapon picture: the rightmost solid column,
## halfway down its solid run (painted guns aren't centred on the barrel).
static var _tips: Dictionary = {}
static func _barrel_tip(tex: Texture2D) -> Vector2:
	var k := tex.get_rid()
	if _tips.has(k):
		return _tips[k]
	var img := tex.get_image()
	var out := Vector2(tex.get_width() - 1, tex.get_height() * 0.5)
	if img:
		if img.is_compressed():
			img.decompress()
		for x in range(img.get_width() - 1, -1, -1):
			var ys := []
			for y in img.get_height():
				if img.get_pixel(x, y).a > 0.5:
					ys.append(y)
			if ys.size() > 0:
				out = Vector2(x, (float(ys[0]) + float(ys[-1])) * 0.5)
				break
	_tips[k] = out
	return out

func _process(delta: float) -> void:
	if cast_sprite:
		_process_cast(delta)
		return
	# side-view guns stay the right way up: aiming left, the picture flips
	var left_aim := cos(rig.global_rotation) < 0.0
	# one gun: kept the right way up. Two guns: a mirrored pair with both
	# grips turned outward, the same whichever way she faces
	# (a mirrored pair is symmetric about the aim line: it never flips with
	# the direction she's facing)
	# weapons are painted from above now: nothing to turn the right way up
	var f1 := false
	var f2 := false
	if weapon_sprite.flip_v != f1 and weapon_sprite.texture:
		weapon_sprite.flip_v = f1
		weapon_sprite.offset = _grip_offset(weapon_sprite.texture, f1)
	if weapon_sprite2.flip_v != f2 and weapon_sprite2.texture:
		weapon_sprite2.flip_v = f2
		weapon_sprite2.offset = _grip_offset(weapon_sprite2.texture, f2)
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
		if _stab:
			# knife: small draw-back, fast thrust, snap back
			var d := -2.5 * sin(clampf(k / 0.25, 0.0, 1.0) * PI * 0.5) if k < 0.25 else 6.5 * sin(clampf((k - 0.25) / 0.75, 0.0, 1.0) * PI)
			weapon_sprite.rotation = 0.0
			# the thrust comes in from the shoulder toward the centre line
			weapon_sprite.position = _hand + Vector2(d, -_hand.y * 0.35 * clampf(d / 6.5, 0.0, 1.0))
			_arm.visible = true
			_arm.queue_redraw()
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
			_arm.visible = true
			_arm.queue_redraw()
			_twist = _swing_dir * (sin(clampf((k - 0.1) / 0.7, 0.0, 1.0) * PI) * (0.32 if _heavy_swing else 0.24) - (0.12 if k < 0.22 else 0.0))
			_push_ghost()
		if _swing_t >= _swing_dur + 0.03:
			_swing_t = -1.0
			_twist = 0.0
			_arm.visible = false
			if _rest_torso:
				torso.texture = _rest_torso
				_rest_torso = null
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
		_arm.queue_redraw()
		if _punch_t > 0.14:
			_punch_t = -1.0
			_punch_reach = 6.5
			_arm.visible = _swing_t >= 0.0
			if _hold == WeaponData.Hold.NONE:
				torso.texture = SpriteLib.torso("unarmed", palette)
	if _flash > 0.0:
		_flash -= delta
		modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	_apply_roll(delta)
	_apply_idle(delta)


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
	g.scale = weapon_sprite.scale
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
	_arm.visible = _mag != null and is_instance_valid(_mag)
	if _arm.visible:
		_arm.queue_redraw()
	if k >= 1.0:
		_reload_k = -1.0
		_arm.visible = false
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
## The character's shadow: a small contact shadow under the feet, plus the
## body's own silhouette (legs, torso, gun) thrown away from each of the
## (up to two) lights that reach them - longer and fainter the further they
## stand from a lamp, turning as they walk past it, moving with every pose.
class DropShadow extends Node2D:
	var _smooth := LightProbe.Smoother.new()
	var _probe: Array = []
	func _ready() -> void:
		z_index = -1
		z_as_relative = true
		show_behind_parent = true
	var _off := false
	func _process(delta: float) -> void:
		# off screen nobody sees it: no light sampling, no redraw
		var vp := get_viewport()
		var sp := vp.get_canvas_transform() * global_position
		var off := not vp.get_visible_rect().grow(96.0).has_point(sp)
		if off:
			_off = true
			return
		if _off:
			_off = false
			_smooth.snap(get_tree(), global_position)
		_smooth.update(get_tree(), global_position, delta)
		_probe = _smooth.top(1)
		queue_redraw()
	func _draw() -> void:
		var v := get_parent() as CharacterVisual
		# contact shadow
		draw_set_transform(Vector2(0.5, 1.5), 0.0, Vector2(1.0, 0.62))
		draw_circle(Vector2.ZERO, 6.5, Color(0, 0, 0, 0.26))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if v == null or v.rig == null or not v.visible:
			return
		for pr in _probe:
			var dir: Vector2 = pr.dir
			var k: float = pr.k
			# one soft silhouette of the body, from the strongest light only:
			# drawing every part (legs, torso, gun) stacked darker patches
			var length := 2.0 + 4.0 * float(pr.far)
			var alpha := clampf(0.08 + 0.16 * k, 0.0, 0.22)
			var base := Transform2D(0.0, dir * length) * LightProbe.stretch(dir, 1.1 + 0.25 * float(pr.far))
			var col := Color(0.0, 0.0, 0.03, alpha)
			for spr in [v.cast_sprite if v.cast_sprite else v.torso]:
				var sp := spr as Sprite2D
				if sp == null or sp.texture == null or not sp.visible:
					continue
				var xf: Transform2D = sp.transform if sp.get_parent() == v else v.rig.transform * sp.transform
				draw_set_transform_matrix(base * xf)
				var ts := sp.texture.get_size()
				var r := Rect2(-ts * 0.5 if sp.centered else Vector2.ZERO, ts)
				r.position += sp.offset
				draw_texture_rect(sp.texture, r, false, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## The arms that do the hitting, drawn live over the torso art: sleeve from
## the shoulder through a bent elbow to the fist. A stab drives the fist
## out along the blade; a swing carries the grip round the arc (both hands
## on the handle for two-handed weapons); a punch throws the fist out from
## alternating shoulders and snaps it back.
class MeleeArm extends Node2D:
	var vis: Node

	func _limb(shoulder: Vector2, hand: Vector2, side: float, sleeve: Color, skin: Color, fist := 1.3) -> void:
		var reach := (hand - shoulder).length()
		var bend := clampf(1.0 - reach / 12.0, 0.0, 1.0)
		var elbow := shoulder.lerp(hand, 0.5) + Vector2(-1.2, 1.6 * side) * bend
		var dark := sleeve.darkened(0.6)
		var cloth := sleeve.darkened(0.15)
		draw_polyline(PackedVector2Array([shoulder, elbow, hand]), dark, 2.3)
		draw_polyline(PackedVector2Array([shoulder, elbow, hand]), cloth, 1.4)
		draw_circle(hand, fist * 0.8 + 0.35, skin.darkened(0.45))
		draw_circle(hand, fist * 0.8, skin)

	func _draw() -> void:
		var P: Dictionary = SpriteForge._pal(str(vis.palette))
		var sleeve: Color = P.get("j", Color(0.3, 0.3, 0.35))
		var skin: Color = P.get("s", Color.BISQUE)
		if float(vis._punch_t) >= 0.0:
			var k := clampf(float(vis._punch_t) / 0.14, 0.0, 1.0)
			# fast out (ease-out), slower back
			var e := sin(clampf(k / 0.4, 0.0, 1.0) * PI * 0.5) if k < 0.4 else 1.0 - (k - 0.4) / 0.6 * 0.85
			var side := -1.0 if vis._punch_left else 1.0
			var shoulder := Vector2(-1.0, 3.4 * side)
			var fist := Vector2(2.0 + float(vis._punch_reach) * e, 3.4 * side * (1.0 - 0.7 * e))
			_limb(shoulder, fist, side, sleeve, skin, 1.7)
			return
		var mag = vis._mag
		if float(vis._reload_k) >= 0.0 and mag and is_instance_valid(mag):
			# the off hand brings the fresh magazine up to the gun
			var s2 := -(signf(float(vis._hand.y)) if absf(float(vis._hand.y)) > 0.5 else 1.0)
			_limb(Vector2(-1.0, 3.2 * s2), (mag as Node2D).position, s2, sleeve, skin, 1.1)
			return
		var ws: Sprite2D = vis.weapon_sprite
		var grip := ws.position + Vector2(-1, 0).rotated(ws.rotation)
		var side1 := signf(float(vis._hand.y)) if absf(float(vis._hand.y)) > 0.5 else 1.0
		_limb(Vector2(-1.0, 3.2 * side1), grip, side1, sleeve, skin)
		if not vis._stab and int(vis._hold) == WeaponData.Hold.MELEE_TWO:
			# the other hand further up the handle
			var grip2 := ws.position + Vector2(3.5, 0).rotated(ws.rotation)
			_limb(Vector2(-1.0, -3.2 * side1), grip2, -side1, sleeve, skin)


## The kicking leg, drawn live under the torso: the knee comes up (chamber),
## the boot snaps out along the aim, then comes back. Also the knees either
## side of someone she's knelt on, for bare-handed executions.
class KickLeg extends Node2D:
	var vis: Node

	func _ready() -> void:
		show_behind_parent = false
		z_index = -1

	func _seg(a: Vector2, b: Vector2, c: Vector2, pants: Color, shoe: Color) -> void:
		var dark := pants.darkened(0.55)
		draw_polyline(PackedVector2Array([a, b, c]), dark, 3.2)
		draw_polyline(PackedVector2Array([a, b, c]), pants, 2.2)
		var d := (c - b).normalized()
		draw_line(c - d * 0.5, c + d * 2.2, shoe.darkened(0.3), 3.0)
		draw_line(c, c + d * 2.0, shoe, 2.0)

	func _draw() -> void:
		var P: Dictionary = SpriteForge._pal(str(vis.palette))
		var pants: Color = P.get("p", Color(0.2, 0.2, 0.25))
		var shoe: Color = P.get("P", Color(0.08, 0.06, 0.06))
		if vis._mount:
			# kneeling astride: both knees forward and out, shins tucked back
			for side in [-1.0, 1.0]:
				_seg(Vector2(-1, 2.0 * side), Vector2(3, 3.8 * side), Vector2(-1.5, 4.4 * side), pants, shoe)
			return
		var t: float = 1.0 - float(vis._kick_leg_t) / float(vis.KICK_TIME)
		# 0-35% chamber, 35-55% snap out, hold, 75-100% retract
		var ext: float
		if t < 0.35:
			ext = 0.0
		elif t < 0.55:
			ext = sin((t - 0.35) / 0.2 * PI * 0.5)
		elif t < 0.75:
			ext = 1.0
		else:
			ext = 1.0 - (t - 0.75) / 0.25
		var chamber := sin(clampf(t / 0.35, 0.0, 1.0) * PI * 0.5) * (1.0 - ext)
		var hip := Vector2(-1.0, 2.0)
		var knee := hip + Vector2(3.5 + 2.5 * chamber + 3.0 * ext, 1.5 - 1.0 * ext)
		var foot := knee + Vector2(-2.5 * (1.0 - ext) + 6.0 * ext, 1.0 - 1.5 * ext)
		_seg(hip, knee, foot, pants, shoe)


## Full-body playback uses the same action timers and weapon nodes as before.
func _process_cast(delta: float) -> void:
	var one_hand_melee := weapon_sprite.visible and not _firearm and _hold != WeaponData.Hold.MELEE_TWO
	var name := ("aim_dual" if dual else ("aim_melee" if one_hand_melee else "aim")) if weapon_sprite.visible else "idle"
	var progress := -1.0
	var speed := _cast_velocity.length()
	if speed > 8.0:
		name = "run" if speed > 145.0 else ("sneak" if speed < 85.0 else "walk")
		if weapon_sprite.visible:
			name = ("armed_dual_" if dual else ("armed_melee_" if one_hand_melee else "armed_")) + name
	rig.rotation = aim_angle
	if _roll_t >= 0.0:
		_roll_t += delta
		name = "roll"
		progress = clampf(_roll_t / _roll_dur, 0.0, 1.0)
		rig.rotation = _roll_dir.angle()
		if progress >= 1.0:
			_roll_t = -1.0
	elif _kick_leg_t > 0.0:
		_kick_leg_t = maxf(0.0, _kick_leg_t - delta)
		name = "kick"
		progress = 1.0 - _kick_leg_t / KICK_TIME
	elif _swing_t >= 0.0:
		_swing_t += delta
		name = "punch" if _stab else "melee"
		progress = clampf(_swing_t / _swing_dur, 0.0, 1.0)
		if progress >= 1.0:
			_swing_t = -1.0
	elif _punch_t >= 0.0:
		_punch_t += delta
		name = "punch_left" if _punch_left else "punch"
		progress = clampf(_punch_t / 0.2, 0.0, 1.0)
		if progress >= 1.0:
			_punch_t = -1.0
	elif _fall_t > 0.0:
		_fall_t = maxf(0.0, _fall_t - delta)
		name = "knocked"
		progress = 1.0 - _fall_t / 0.24
	if _reload_k >= 0.0 and _roll_t < 0.0:
		name = "reload_" + _reload_kind
		progress = clampf(_reload_k, 0.0, 1.0)
	if name == "idle" and idle_fidgets and _still_t > 9.0:
		name = "smoke"
	cast_sprite.play_sample(name, delta, progress)
	_hand = cast_sprite.grip()
	_hand2 = cast_sprite.grip(true)
	_kick = move_toward(_kick, 0.0, delta * 30.0)
	_gun_kick = move_toward(_gun_kick, 0.0, delta * 26.0)
	_gun_kick2 = move_toward(_gun_kick2, 0.0, delta * 26.0)
	rig.position = Vector2.RIGHT.rotated(rig.rotation) * -_kick
	rig.scale = Vector2.ONE
	weapon_sprite.position = _hand - Vector2(_gun_kick, 0)
	weapon_sprite2.position = _hand2 - Vector2(_gun_kick2, 0)
	weapon_sprite.rotation = cast_sprite.weapon_angle() if name == "melee" else -0.09 * _gun_kick
	weapon_sprite2.rotation = -0.09 * _gun_kick2
	weapon_sprite.modulate.a = 0.0 if name == "roll" else 1.0
	weapon_sprite2.modulate.a = weapon_sprite.modulate.a
	_update_reload(delta)
	if name.begins_with("reload_"):
		weapon_sprite.position = _hand - Vector2(_gun_kick, 0)
		weapon_sprite2.position = _hand2 - Vector2(_gun_kick2, 0)
	# The rendered body already contains its limbs.
	_arm.visible = false
	_leg.visible = false
	legs.visible = false
	torso.visible = false
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE

	if name == "smoke":
		if _cig == null:
			_cig = CigaretteFx.new()
			_cig.vis = self
			rig.add_child(_cig)
			_sfx("light_switch", -22.0)
		_cig.position = cast_sprite.grip()
	elif _cig:
		_cig.put_out()
		_cig = null

