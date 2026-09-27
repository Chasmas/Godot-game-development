class_name BossFireman
extends BossNightManager
## DUTCH "THE FIREMAN" KOWALSKI, pyrotechnician, Stage Nine.
## Phase 1 "LIVE": stalks you with a flamethrower. He winds up (pilot click,
##   the nozzle glows), then sprays a cone that tracks you slowly and leaves
##   the floor burning. His aluminised suit soaks 3 hits; every hit he backs
##   off to new cover and the floor crew comes running.
## Phase 2 "FIRE ON SET": he lights the stage. The sprinklers cough dry. He
##   moves faster and adds a ring of fire around himself, telegraphed by a
##   glowing circle. One clean hit (or a propane tank) drops him.
## Fire never hurts him. Everything else burns.

const BARKS_FIRE := ["You're standing on my mark!", "More light! MORE LIGHT!", "Rudy! Get me some bodies out here!"]
const BARKS_P2_FIRE := ["Let's give 'em a finale."]
const SPRAY_RANGE := 132.0
const SPRAY_ARC := 0.34            ## half-angle, radians
const SPRAY_TIME := 1.15
const WINDUP := 0.55
const RING_EVERY := 6.5

var _flame_cd := 2.0
var _windup := 0.0
var _spray := 0.0
var _spray_dir := Vector2.RIGHT
var _drop_t := 0.0
var _ring_t := RING_EVERY
var _ring_wind := 0.0
var _flame: FlameFx

func setup(p_data: EnemyData, p_level: Node, p_facing: Vector2) -> void:
	super.setup(p_data, p_level, p_facing)
	flashlight.visible = false
	p2_hits = 1
	_flame = FlameFx.new()
	_flame.boss = self
	add_child(_flame)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not active or _defeated:
		_windup = 0.0
		_spray = 0.0
		return
	_flame_cd -= delta
	var p := _player()
	# the ring (phase 2): telegraphed by a glowing circle, then a wall of fire
	if phase == 2:
		_ring_t -= delta
		if _ring_t <= 0.0 and _ring_wind <= 0.0 and _spray <= 0.0:
			_ring_wind = 1.0
			Audio.play_at("flame_ignite", global_position, 2.0)
			_say("Stand back!")
		if _ring_wind > 0.0:
			_ring_wind -= delta
			if _ring_wind <= 0.0:
				_ring_t = RING_EVERY
				_fire_ring()
	if _windup > 0.0:
		_windup -= delta
		if p:
			_spray_dir = _spray_dir.slerp((p.global_position - global_position).normalized(), 1.0 - exp(-delta * 6.0))
		if _windup <= 0.0:
			_spray = SPRAY_TIME * (1.25 if phase == 2 else 1.0)
			Audio.play_at("flame_burst", global_position, 3.0)
	elif _spray > 0.0:
		_spray -= delta
		if p:
			# tracks you, but slowly: sidestep it
			var turn := 1.6 if phase == 1 else 2.3
			var want := (p.global_position - global_position).normalized()
			_spray_dir = _spray_dir.rotated(clampf(_spray_dir.angle_to(want), -turn * delta, turn * delta))
		_burn_cone(delta)
		if _spray <= 0.0:
			_flame_cd = randf_range(1.6, 2.6) if phase == 1 else randf_range(1.0, 1.7)
	elif p and p.alive and _flame_cd <= 0.0 and _ring_wind <= 0.0:
		var d := global_position.distance_to(p.global_position)
		if d < SPRAY_RANGE * 1.15 and _clear_line(global_position, p.global_position):
			_windup = WINDUP
			_spray_dir = (p.global_position - global_position).normalized()
			Audio.play_at("flame_ignite", global_position, 0.0)
	if _windup > 0.0 or _spray > 0.0:
		facing = _spray_dir
		visual.set_aim(_spray_dir.angle())

## Everything in the cone burns; the floor catches every few frames.
func _burn_cone(delta: float) -> void:
	var origin := global_position + _spray_dir * 10.0
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_t = 0.1
		var a := randf_range(-SPRAY_ARC, SPRAY_ARC) * 0.8
		var dist := randf_range(0.35, 1.0) * SPRAY_RANGE
		var at := origin + _spray_dir.rotated(a) * dist
		if level and level.has_method("nearest_open_point"):
			at = level.nearest_open_point(at, origin)
		FireZone.ignite(get_parent(), at, randf_range(9.0, 13.0), randf_range(3.5, 5.5))
	var p := _player()
	if p and p.alive:
		var to := p.global_position - origin
		if to.length() < SPRAY_RANGE and absf(_spray_dir.angle_to(to)) < SPRAY_ARC and _clear_line(origin, p.global_position):
			var info := DamageInfo.make(DamageInfo.Type.FIRE, self, origin, to.normalized(), &"flamethrower", &"fire")
			info.lethal = true
			p.take_damage(info)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not e.is_alive():
			continue
		var to2: Vector2 = (e as Node2D).global_position - origin
		if to2.length() < SPRAY_RANGE and absf(_spray_dir.angle_to(to2)) < SPRAY_ARC:
			var info2 := DamageInfo.make(DamageInfo.Type.FIRE, self, origin, to2.normalized(), &"flamethrower", &"fire")
			info2.lethal = true
			e.take_damage(info2)

func _fire_ring() -> void:
	Audio.play_at("flame_burst", global_position, 4.0)
	Events.camera_shake.emit(4.0)
	for i in 14:
		var a := i * TAU / 14.0
		var at := global_position + Vector2.from_angle(a) * randf_range(46.0, 60.0)
		if level and level.has_method("nearest_open_point"):
			at = level.nearest_open_point(at, global_position)
		FireZone.ignite(get_parent(), at, 12.0, 4.5)

func _hit_barks() -> Array:
	return BARKS_FIRE

func _phase_two_bark() -> String:
	return BARKS_P2_FIRE[0]

func _gun_combat(p: Player, dist: float, delta: float) -> Vector2:
	# no bullets: he walks the flame onto you
	if _windup > 0.0 or _spray > 0.0 or _ring_wind > 0.0:
		return Vector2.ZERO if _spray <= 0.0 else _spray_dir * data.walk_speed * 0.25
	var want := 70.0 if phase == 2 else 95.0
	if dist > want:
		return _go_to(p.global_position, data.walk_speed * (1.35 if phase == 2 else 1.0))
	if dist < 40.0:
		return -(p.global_position - global_position).normalized() * data.walk_speed
	return (p.global_position - global_position).normalized().orthogonal() * data.walk_speed * 0.4

func _on_armor_hit(_info: DamageInfo) -> void:
	var hb := _hit_barks()
	_say(hb[(data.armor - armor_left - 1) % hb.size()])
	Audio.play_at("intercom", global_position)
	_windup = 0.0
	_spray = 0.0
	_cover_i += 1
	_relocating = true
	if level and level.has_method("spawn_reinforcements"):
		level.spawn_reinforcements(2 if armor_left > 0 else 1)
	Events.boss_phase.emit(1)
	if armor_left <= 0:
		_start_phase_two()

func _start_phase_two() -> void:
	phase = 2
	data = data.duplicate()
	data.reaction_time = 0.4
	data.walk_speed *= 1.25
	data.run_speed *= 1.2
	_say(_phase_two_bark())
	_ring_t = 2.5
	visual.flash(0.22)
	PostFX.flash(Color(1.0, 0.45, 0.1), 0.22)
	Events.camera_shake.emit(6.0)
	Events.camera_punch.emit(1.16, 0.32)
	Audio.play_at("flame_burst", global_position, 4.0)
	Events.boss_phase.emit(2)
	if level and level.has_method("boss_set_ablaze"):
		level.boss_set_ablaze()

func take_damage(info: DamageInfo) -> String:
	if info.type == DamageInfo.Type.FIRE:
		return "pass"    # aluminised suit
	return super.take_damage(info)

func _final_down(info: DamageInfo) -> void:
	_windup = 0.0
	_spray = 0.0
	_ring_wind = 0.0
	super._final_down(info)

func resolve(executed: bool, by: Node) -> void:
	if executed:
		var info := DamageInfo.make(DamageInfo.Type.MELEE, by, global_position, Vector2.RIGHT, &"fists", &"execution")
		info.lethal = true
		info.from_player = true
		Score.add_bonus("RATINGS WINNER", 5000, global_position)
		state = State.COMBAT
		_die(info)
	else:
		Score.add_bonus("FEED CUT", 3000, global_position)
		_say("...they'll cut to a commercial, kid.")
		state = State.EXECUTED
		remove_from_group("enemies")
		remove_from_group("damageable")


## The spray and the wind-up glow, drawn over the floor fires.
class FlameFx extends Node2D:
	var boss: BossFireman
	var _t := 0.0

	func _ready() -> void:
		z_index = 5
		z_as_relative = false

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if boss == null:
			return
		var dir := boss._spray_dir
		var o := dir * 10.0
		if boss._windup > 0.0:
			var k := 1.0 - boss._windup / WINDUP
			draw_circle(o, 2.0 + k * 3.0, Color(0.4, 0.7, 1.0, 0.8))
			# a faint preview of where it will reach
			for s in [-1.0, 1.0]:
				draw_line(o, o + dir.rotated(SPRAY_ARC * s) * SPRAY_RANGE, Color(1.0, 0.5, 0.2, 0.12 + 0.2 * k), 1.0)
		if boss._spray > 0.0:
			for i in 26:
				var f := fmod(_t * 3.2 + i * 0.137, 1.0)
				var a := sin(i * 12.9898 + floor(_t * 3.2 + i * 0.137) * 3.1) * SPRAY_ARC * f
				var p := o + dir.rotated(a) * SPRAY_RANGE * f
				var r := 2.0 + f * 9.0
				var col := Color(1.0, 0.95 - f * 0.6, 0.5 - f * 0.45, 0.85 * (1.0 - f * 0.6))
				draw_circle(p, r, col)
			draw_circle(o, 4.0, Color(1, 1, 0.8, 0.9))
		if boss._ring_wind > 0.0:
			var k2 := 1.0 - boss._ring_wind
			draw_arc(Vector2.ZERO, 53.0, 0.0, TAU, 40, Color(1.0, 0.45, 0.1, 0.25 + 0.6 * k2), 2.0 + k2 * 3.0)
			draw_arc(Vector2.ZERO, 53.0 * k2, 0.0, TAU, 32, Color(1.0, 0.8, 0.3, 0.3), 1.0)
