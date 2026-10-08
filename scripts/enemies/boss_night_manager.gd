class_name BossNightManager
extends Enemy
## LYLE HARCOURT, NIGHT MANAGER of the Sunset Palms.
## Phase 1 "FRONT DESK": moves between cover, revolver volleys. His vest soaks
##   3 hits; every hit he retreats to new cover and calls security on the
##   intercom (reinforcements through the side doors).
## Phase 2 "LIGHTS OUT": he kills the power. Pitch dark, his flashlight is the
##   only light; he hunts you with a shotgun. One clean hit drops him.
## Finale: he's down and talking. Execute him - or walk away.

signal defeated(boss: BossNightManager)

var phase := 1
var cover_points: PackedVector2Array = []
var _cover_i := 0
var _bark := ""
var _bark_t := 0.0
var _relocating := false
var flashlight: PointLight2D
var _defeated := false
var active := false
var _phase_intro_t := 0.0
var _rage_pulse_t := 0.0
var p2_hits := 2               ## clean hits it takes to drop him in the dark
var _blind_t := 0.0            ## dazzled by the lights coming back (or doused, or foamed)

## Before the fight he's sitting in his office chair behind the desk,
## smoking, talking to nobody - or to whoever's on hold. You only hear it
## if you're close (the bubble is overheard chatter, like the guards').
const MONOLOGUE := [
	"Nineteen years behind this desk. Before that I was crew, you know. Continuity. I had an eye for continuity.",
	"Room 204 again. Nobody checks out of 204. They just... stop paying.",
	"Every tape that comes through here, I keep a copy. Insurance. Only religion this town ever had.",
	"The ice machine's been broken since '85. I like it broken. Keeps the guests out of the hallways.",
	"They want the cameras rolling, the cameras roll. Residuals keep the neon on, sweetheart.",
	"That stunt girl... if she ever walks in here, I'm on the first bus out of the county.",
	"You hear that? ...Nah. Just the rain. Always the rain.",
]
const HEAR_RADIUS := 190.0
var _mono_i := 0
var _mono_t := 1.5
var _chair: OfficeChair
var _smoke: IdleActivity

const BARKS_HIT := ["You're bleeding on my carpet!", "SECURITY! Front desk!", "Do you know who OWNS this place?"]
const BARKS_P2 := ["Let's see how you do in the dark, hotshot."]

func setup(p_data: EnemyData, p_level: Node, p_facing: Vector2) -> void:
	super.setup(p_data, p_level, p_facing)
	required = true
	flashlight = PointLight2D.new()
	flashlight.texture = SpriteLib.cone_texture(256)
	flashlight.offset = Vector2(128, 0)
	flashlight.texture_scale = 1.2
	flashlight.energy = 1.6
	flashlight.color = Color(1, 0.95, 0.8)
	flashlight.shadow_enabled = true
	flashlight.visible = false
	visual.rig.add_child(flashlight)
	# sat back in his office chair, a cigarette going, gun on the desk
	_chair = OfficeChair.new()
	_chair.z_index = -1
	_chair.rotation = p_facing.angle()
	add_child(_chair)
	_smoke = IdleActivity.new()
	visual.rig.add_child(_smoke)
	_smoke.setup(visual, IdleActivity.Kind.SMOKE, "harcourt")
	visual.legs.visible = false
	visual.weapon_sprite.visible = false
	# a rendered body sits for real (the seated clip, hands forward on the desk)
	if visual.has_clip("drive"):
		visual.pose_override = "drive"

func activate() -> void:
	_stand_up()
	active = true
	_enter_combat()
	Events.boss_hp.emit(self, hp, max_hp)

func _physics_process(delta: float) -> void:
	_bark_t = maxf(0.0, _bark_t - delta)
	_phase_intro_t = maxf(0.0, _phase_intro_t - delta)
	_rage_pulse_t += delta
	if phase == 2 and active and not _defeated and fmod(_rage_pulse_t, 2.4) < delta:
		flashlight.energy = 2.15
		var ft := create_tween()
		ft.tween_property(flashlight, "energy", 1.6, 0.22)
	if not active:
		visual.set_aim(facing.angle())
		_monologue(delta)
		return
	if _blind_t > 0.0 and not _defeated:
		# staggering, arm over the eyes: the opening
		_blind_t -= delta
		_knock = _knock.move_toward(Vector2.ZERO, 600.0 * delta)
		velocity = _knock + Vector2(sin(_blind_t * 9.0), cos(_blind_t * 7.0)) * 14.0
		move_and_slide()
		visual.set_aim(facing.angle() + sin(_blind_t * 6.0) * 0.6)
		visual.update_move(get_real_velocity(), delta)
		queue_redraw()
		return
	super._physics_process(delta)
	if _bark_t > 0.0:
		queue_redraw()

func _perceive() -> void:
	super._perceive()
	if phase == 2 and not _sees_player:
		# he knows this building in the dark: always roughly aware of you
		var p := _player()
		if p and p.alive and Engine.get_physics_frames() % 90 == 0:
			_last_known = p.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

func _combat(delta: float) -> Vector2:
	if _relocating and not cover_points.is_empty():
		var target := cover_points[_cover_i % cover_points.size()]
		if global_position.distance_to(target) < 10.0:
			_relocating = false
		else:
			return _go_to(target, data.run_speed)
	return super._combat(delta)

func _gun_combat(p: Player, dist: float, delta: float) -> Vector2:
	var move := super._gun_combat(p, dist, delta)
	if phase == 1:
		return move * 0.5    # holds his ground behind cover
	# phase 2: stalks you
	if dist > 60.0:
		return _go_to(p.global_position, data.walk_speed * 1.4)
	return move

var _hit_n := 0

func _on_armor_hit(_info: DamageInfo) -> void:
	_hit_n += 1
	_say(BARKS_HIT[_hit_n % BARKS_HIT.size()])
	Audio.play_at("intercom", global_position)
	_cover_i += 1
	_relocating = true
	if level and level.has_method("spawn_reinforcements"):
		level.spawn_reinforcements(1)
	Events.boss_phase.emit(1)

func _start_phase_two() -> void:
	phase = 2
	weapon = WeaponInstance.create(DB.weapon(&"shotgun"))
	visual.set_weapon(weapon.data)
	flashlight.visible = true
	data = data.duplicate()
	data.burst = 1
	data.reaction_time = 0.45
	data.aim_error_deg = 6.0
	_say(BARKS_P2[0])
	_phase_intro_t = 1.0
	visual.flash(0.22)
	PostFX.flash(Color(0.2, 0.35, 0.75), 0.18)
	Events.camera_shake.emit(6.0)
	Events.camera_punch.emit(1.16, 0.32)
	Audio.play_at("power_down", global_position, 2.0)
	Events.boss_phase.emit(2)
	if level and level.has_method("boss_lights_out"):
		level.boss_lights_out()

## Dazzled/soaked/foamed for `t` seconds: can't fight back, and a clean
## blow while he's like this ends it.
func blind(t: float, bark := "") -> void:
	if _defeated:
		return
	_blind_t = t
	flashlight.visible = false
	visual.hit_react(Vector2.from_angle(randf() * TAU), true, 0.3)
	if bark != "":
		_say(bark)
	Events.camera_punch.emit(1.1, 0.25)

## HEALTH. Every boss has a bar (HUD BossBar). Plain hits take a little;
## the room's trick (breaker, water main, extinguishers) leaves them open and
## the next blow takes a big chunk - never the whole bar at once. Phase two
## starts at PHASE2_AT of the bar.
var max_hp := 10.0
var hp := 10.0
const PHASE2_AT := 0.6
const HIT := 1.25             ## a bullet / blade / thrown thing, phase one
const HIT_P2 := 1.5           ## phase two: he's hurt, he's careless
const HIT_OPEN := 3.2         ## a blow while he's blinded / soaked / foamed
const HIT_BOOM := 2.5         ## explosions

## How hard each weapon hits a boss, in pistol shots: ~10 pistol rounds empty
## the bar, heavier guns take fewer. Pellet guns are split across the pellets,
## so a whole shotgun blast counts as about 1.6 shots, not 8.
const BOSS_WEIGHT := {
	&"pistol": 1.0, &"whisper": 0.9, &"smg": 0.6, &"revolver": 1.6, &"rifle": 1.3,
	&"hotshot": 1.4, &"shotgun": 1.6, &"boomstick": 2.0, &"flamethrower": 0.25,
	&"bat": 1.2, &"pipe": 1.2, &"machete": 1.1, &"knife": 0.9,
	&"bottle": 0.6, &"broken_bottle": 0.7, &"brick": 0.7, &"glass_shard": 0.5,
}
const HIT_UNIT := 1.0   ## one pistol shot (max_hp 10)

func _chip(info: DamageInfo) -> float:
	if info.type == DamageInfo.Type.EXPLOSIVE:
		return HIT_BOOM
	var w := DB.weapon(info.weapon_id) if info.weapon_id != &"" else null
	var weight: float = BOSS_WEIGHT.get(info.weapon_id, 1.0)
	if w and w.pellets > 1:
		weight /= float(w.pellets)
	return HIT_UNIT * weight

func _hurt(amount: float, info: DamageInfo) -> String:
	hp = maxf(0.0, hp - amount)
	Events.boss_hp.emit(self, hp, max_hp)
	if hp <= 0.0:
		_final_down(info)
		return "killed"
	visual.hit_react(info.dir, true, 0.2)
	_knock = info.dir * 170.0
	Effects.blood(global_position, info.dir)
	Audio.play_at("hit_flesh", global_position)
	Events.camera_punch.emit(1.08, 0.15)
	if phase == 1:
		_on_armor_hit(info)
		if hp <= max_hp * PHASE2_AT:
			_start_phase_two()
	else:
		_say("Is that it, hotshot?")
		_cover_i += 1
		_relocating = true
	return "absorbed"

func take_damage(info: DamageInfo) -> String:
	if _defeated:
		return "pass"
	if info.source is Enemy or (not info.from_player and not bool(info.get_meta("player_caused", false))):
		return "pass" if info.type == DamageInfo.Type.BALLISTIC else "blocked"
	if not active:
		activate()
	if not (info.lethal or info.type == DamageInfo.Type.EXPLOSIVE or info.type == DamageInfo.Type.BALLISTIC):
		# a shove or a punch: he rocks, nothing more
		visual.hit_react(info.dir, false, 0.12)
		_knock = info.dir * 120.0
		return "absorbed"
	if _blind_t > 0.0:
		_blind_t = 0.0
		PostFX.flash(Color(1, 0.9, 0.6), 0.25)
		Events.hit_stop.emit(0.12)
		return _hurt(HIT_OPEN, info)
	return _hurt(_chip(info), info)

func _final_down(info: DamageInfo) -> void:
	_defeated = true
	flashlight.visible = false
	state = State.DOWNED
	_down_t = 9999.0
	collision_layer = 0
	visual.torso.texture = SpriteLib.downed(data.palette)
	visual.legs.visible = false
	visual.weapon_sprite.visible = false
	visual.fall(info.dir)
	PostFX.flash(Color(1.0, 0.16, 0.22), 0.16)
	Events.camera_shake.emit(9.0)
	_knock = info.dir * 150.0
	Effects.blood(global_position, info.dir, true)
	Audio.play_at("body_fall", global_position)
	Events.hit_stop.emit(0.2)
	Events.camera_punch.emit(1.3, 1.0)
	if weapon:
		_drop_weapon(info.dir * 50.0)
	defeated.emit(self)

## Finale resolution from the level (after the dialogue choice).
func resolve(executed: bool, by: Node) -> void:
	if executed:
		var info := DamageInfo.make(DamageInfo.Type.MELEE, by, global_position, Vector2.RIGHT, &"fists", &"execution")
		info.lethal = true
		info.from_player = true
		Score.add_bonus("CHECKED OUT", 5000, global_position)
		state = State.COMBAT
		_die(info)
	else:
		Score.add_bonus("MERCY", 2500, global_position)
		_say("...you'll regret that, kid.")
		state = State.EXECUTED   # removed from fight, lies there alive
		remove_from_group("enemies")
		remove_from_group("damageable")

func is_downed() -> bool:
	return false   # can't be executed with the normal prompt - the finale handles it

## Talking to himself in the chair. Only when Cass is near enough to
## overhear - nobody reads a bubble from across the motel.
func _monologue(delta: float) -> void:
	if _defeated or Dialogue.active:
		return
	var p := _player()
	if p == null or not p.alive or p.global_position.distance_to(global_position) > HEAR_RADIUS:
		_mono_t = minf(_mono_t, 1.2)
		return
	_mono_t -= delta
	if _mono_t <= 0.0:
		var line: String = MONOLOGUE[_mono_i % MONOLOGUE.size()]
		_mono_i += 1
		_say(line)
		_bark_t = 5.5
		var bl := BarkLayer.find(get_tree())
		if bl:
			bl.say(self, line, 5.5, Color(1.0, 0.85, 0.7))
		_mono_t = 7.0

## The fight starts: he kicks the chair back, stubs the cigarette out and
## picks the revolver up off the desk.
func _stand_up() -> void:
	if _smoke and is_instance_valid(_smoke):
		_smoke.drop()
		_smoke = null
	visual.legs.visible = true
	visual.weapon_sprite.visible = true
	visual.pose_override = ""
	if _chair and is_instance_valid(_chair):
		var back := Vector2.from_angle(_chair.rotation) * -12.0
		var ch := _chair
		ch.seated = false
		ch.queue_redraw()
		ch.reparent(get_parent())
		var tw := ch.create_tween().set_parallel(true)
		tw.tween_property(ch, "position", ch.position + back, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ch, "rotation", ch.rotation + 0.9, 0.35)
		Audio.play_at("door_kick", global_position, -12.0, 0.1)
		_chair = null

func _say(t: String) -> void:
	_bark = t
	_bark_t = 3.0
	# screen-space bubble: never clips through the lobby furniture
	var bl := BarkLayer.find(get_tree())
	if bl:
		bl.say(self, t, 3.0, Color(1.0, 0.75, 0.75))

func _draw() -> void:
	super._draw()


## A manager's swivel chair: five-star base, oxblood leather seat with
## buttoned tufts, a tall back. He sits back in it, ankles crossed on the
## floor in front.
class OfficeChair extends Node2D:
	var seated := true
	func _draw() -> void:
		var ink := Color("0b0710")
		var chrome := Color(0.55, 0.56, 0.62)
		var leather := Color(0.42, 0.1, 0.12)
		draw_set_transform(Vector2(1, 2), 0.0, Vector2(1.0, 0.75))
		draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.32))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var pt := ArtLib.sprite("office_chair")
		if pt:
			# the painted chair, its back behind him (it faces the way he does)
			draw_set_transform(Vector2(-2, 0), -PI * 0.5, Vector2.ONE)
			draw_texture_rect(pt, Rect2(-11, -11, 22, 22), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if not seated:
				return
			draw_rect(Rect2(6, -3.5, 8, 3), ink)
			draw_rect(Rect2(6, 0.5, 8, 3), ink)
			draw_rect(Rect2(6.5, -3, 7, 2), Color(0.16, 0.14, 0.2))
			draw_rect(Rect2(6.5, 1, 7, 2), Color(0.16, 0.14, 0.2))
			return
		# the five-star base with casters
		for k in 5:
			var d := Vector2.from_angle(k * TAU / 5.0 + 0.3)
			draw_line(Vector2.ZERO, d * 9.0, ink, 2.6)
			draw_line(Vector2.ZERO, d * 8.5, chrome, 1.2)
			draw_circle(d * 9.0, 1.4, ink)
		# the seat and its tufts
		draw_rect(Rect2(-7, -6.5, 13, 13), ink)
		draw_rect(Rect2(-6, -5.5, 11, 11), leather)
		draw_rect(Rect2(-6, -5.5, 11, 2), leather.lightened(0.25))
		for b in [Vector2(-3, -2), Vector2(1, -2), Vector2(-3, 2), Vector2(1, 2)]:
			draw_circle(b, 0.6, leather.darkened(0.45))
		# the tall back behind him, armrests either side
		draw_rect(Rect2(-11.5, -7.5, 5, 15), ink)
		draw_rect(Rect2(-10.8, -6.8, 3.6, 13.6), leather.darkened(0.1))
		draw_rect(Rect2(-10.8, -6.8, 1.2, 13.6), leather.lightened(0.3))
		for sy in [-8.0, 6.5]:
			draw_rect(Rect2(-6, sy, 9, 2), ink)
			draw_rect(Rect2(-5.5, sy + 0.4, 8, 1.2), Color(0.18, 0.12, 0.1))
		# his shoes out in front, ankles crossed
		draw_rect(Rect2(6, -3.5, 8, 3), ink)
		draw_rect(Rect2(6, 0.5, 8, 3), ink)
		draw_rect(Rect2(6.5, -3, 7, 2), Color(0.16, 0.14, 0.2))
		draw_rect(Rect2(6.5, 1, 7, 2), Color(0.16, 0.14, 0.2))
		draw_rect(Rect2(13, -3.8, 2.5, 3.4), Color(0.08, 0.05, 0.04))
		draw_rect(Rect2(13, 0.4, 2.5, 3.4), Color(0.08, 0.05, 0.04))
