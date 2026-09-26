class_name Enemy
extends CharacterBody2D
## Readable, aggressive enemy AI driven by EnemyData.
## States: IDLE PATROL SUSPICIOUS INVESTIGATE SEARCH COMBAT FLANK RETREAT
##         CALL_REINFORCEMENTS PANIC FLEE DOWNED STUNNED DEAD
## Perception: vision cone + line of sight (darkness shortens it), hearing
## through Events.noise, body discovery, alarms.

signal died(enemy: Enemy, info: DamageInfo)
signal state_changed(enemy: Enemy, state: int)

enum State { IDLE, PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, COMBAT, FLANK, RETREAT, CALL_REINFORCEMENTS, PANIC, FLEE, DOWNED, STUNNED, DEAD, EXECUTED }
const STATE_NAMES := ["IDLE", "PATROL", "SUSPICIOUS", "INVESTIGATE", "SEARCH", "COMBAT", "FLANK", "RETREAT", "CALL_REINF", "PANIC", "FLEE", "DOWNED", "STUNNED", "DEAD", "EXECUTED"]

const RADIUS := 5.5
const DOWN_TIME := 2.8
const MELEE_REACH := 20.0

var data: EnemyData
var weapon: WeaponInstance
var enemy_id := ""                  # stable id from the level file (checkpoint restores)
var level: Node
var visual: CharacterVisual
var state: State = State.IDLE
var facing := Vector2.RIGHT
var hit_radius := 6.0
var armor_left := 0
var patrol_points: PackedVector2Array = []
var required := true                # counts toward "clear the floor"
var debug_draw := false

var _state_t := 0.0
var _perceive_t := 0.0
var _repath_t := 0.0
var _path: PackedVector2Array = []
var _path_i := 0
var _goal := Vector2.ZERO
var _last_known := Vector2.ZERO
var _sees_player := false
var _seen_time := 0.0
var _suspicion := 0.0
var _fire_cd := 0.0
var _burst_left := 0
var _reload_t := 0.0
var _windup_t := -1.0
var _melee_cd := 0.0
var _knock := Vector2.ZERO
var _down_t := 0.0
var _shield_down := 0.0
var _stun_t := 0.0
var _patrol_i := 0
var _look_t := 0.0
var _home := Vector2.ZERO
var _alert_icon := 0.0
var _alert_char := ""
var _was_unaware_when_killed := true
var _executor: Node = null
var _strafe := 1.0
var _panic_rolled := false
var _fix_target: Node2D = null       ## a light switch this enemy is walking over to flip back on
var _held := false                   ## grabbed from behind for a takedown
var _dark_confused := 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("damageable")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WALK_MASK_ENEMY
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	shape.shape = c
	add_child(shape)
	visual = CharacterVisual.new()
	add_child(visual)
	z_index = 1
	Events.noise.connect(_on_noise)
	Events.alarm_raised.connect(_on_alarm)
	Events.lights_changed.connect(_on_lights_changed)
	_perceive_t = randf() * 0.1
	_strafe = 1.0 if randf() > 0.5 else -1.0

func setup(p_data: EnemyData, p_level: Node, p_facing: Vector2) -> void:
	data = p_data
	level = p_level
	facing = p_facing.normalized() if p_facing.length() > 0.1 else Vector2.RIGHT
	armor_left = data.armor
	_home = global_position
	visual.setup(data.palette)
	if data.weapon_id != &"" and DB.weapon(data.weapon_id):
		weapon = WeaponInstance.create(DB.weapon(data.weapon_id))
	visual.set_weapon(weapon.data if weapon else null)
	visual.set_aim(facing.angle())
	if not patrol_points.is_empty():
		_set_state(State.PATROL)

# ======================================================================= queries
func is_alive() -> bool:
	return state != State.DEAD and state != State.EXECUTED

func is_downed() -> bool:
	return state == State.DOWNED

func is_winding_up() -> bool:
	return _windup_t >= 0.0

func is_aware() -> bool:
	return state in [State.COMBAT, State.FLANK, State.RETREAT, State.CALL_REINFORCEMENTS, State.SEARCH, State.PANIC, State.FLEE]

func state_name() -> String:
	return STATE_NAMES[state]

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

# ======================================================================= loop
func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_state_t += delta
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_shield_down = maxf(0.0, _shield_down - delta)
	_alert_icon = maxf(0.0, _alert_icon - delta)
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0 and weapon:
			weapon.ammo = weapon.data.magazine
	_dark_confused = maxf(0.0, _dark_confused - delta)
	_perceive_t -= delta
	if _perceive_t <= 0.0:
		_perceive_t = 0.1
		_perceive()
	var desired := Vector2.ZERO
	match state:
		State.DOWNED:
			_down_t -= delta
			if _down_t <= 0.0:
				_get_up()
		State.STUNNED:
			_stun_t -= delta
			if _held:
				pass
			elif _stun_t <= 0.0:
				_set_state(State.COMBAT if _sees_player else State.SEARCH)
		State.IDLE:
			_look_t -= delta
			if _look_t <= 0.0:
				_look_t = randf_range(2.0, 4.5)
				if randf() < 0.35:
					facing = facing.rotated(randf_range(-1.2, 1.2))
		State.PATROL:
			desired = _patrol(delta)
		State.SUSPICIOUS:
			facing = facing.slerp((_last_known - global_position).normalized(), minf(1.0, delta * 5.0))
			if _state_t > 1.2:
				_set_state(State.INVESTIGATE)
				_goal = _last_known
		State.INVESTIGATE:
			desired = _go_to(_goal, data.walk_speed * 1.3)
			if global_position.distance_to(_goal) < 12.0 or _path_done():
				if _fix_target and is_instance_valid(_fix_target) and _fix_target.global_position.distance_to(global_position) < 24.0:
					if _fix_target.has_method("enemy_use"):
						_fix_target.enemy_use(self)
					_fix_target = null
					_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)
				else:
					_fix_target = null
					_set_state(State.SEARCH)
		State.SEARCH:
			desired = _search(delta)
		State.COMBAT, State.FLANK, State.RETREAT:
			desired = _combat(delta)
		State.CALL_REINFORCEMENTS:
			desired = _call_reinforcements(delta)
		State.PANIC, State.FLEE:
			desired = _flee(delta)
	if state == State.DOWNED or state == State.STUNNED:
		desired = Vector2.ZERO
	desired += _separation()
	velocity = desired + _knock
	move_and_slide()
	if desired.length() > 5.0 and not (state in [State.COMBAT, State.RETREAT] and _sees_player):
		facing = facing.slerp(desired.normalized(), minf(1.0, delta * 10.0))
	visual.set_aim(facing.angle())
	visual.update_move(velocity, delta)
	if debug_draw or _alert_icon > 0.0 or data.shield_arc_deg > 0.0:
		queue_redraw()

# ======================================================================= perception
func _perceive() -> void:
	var p := _player()
	_sees_player = false
	if p == null or not p.alive or state == State.DOWNED or _held:
		return
	var to := p.global_position - global_position
	var dist := to.length()
	var view := data.view_distance
	var aware := is_aware()
	var dk: int = level.darkness_at(p.global_position) if level != null and level.has_method("darkness_at") else 0
	var dark := dk == 2
	if dk == 2:
		# pitch dark: the unaware are practically blind, the alert still squint
		view *= 0.45 if aware else 0.17
	elif dk == 1:
		view *= 0.45
	if _dark_confused > 0.0:
		view *= 0.5
	if p.persona and p.persona.id == &"ghost":
		view *= 0.6
	var in_cone := absf(angle_difference(facing.angle(), to.angle())) < deg_to_rad(data.view_angle_deg * 0.5)
	# you can creep right up behind someone if you move slowly; running is heard/felt
	var close := 10.0 if (p.is_quiet() or dark) else 34.0
	if dist < view * (1.4 if aware else 1.0) and (in_cone or dist < close or aware) and _clear_line(global_position, p.global_position):
		_sees_player = true
		_last_known = p.global_position
		_seen_time += 0.1
		if aware:
			if state == State.SEARCH:
				_enter_combat()
		else:
			# closer = faster recognition; fairness: never instant at range
			var rate := 3.5 if dist < 90.0 else 1.6
			_suspicion += 0.1 * rate
			if _suspicion >= 0.3 and state in [State.IDLE, State.PATROL]:
				_set_state(State.SUSPICIOUS)
				_show_icon("?")
			if _suspicion >= 0.55 or dist < 50.0:
				_enter_combat()
	else:
		_seen_time = 0.0
		_suspicion = maxf(0.0, _suspicion - 0.02)
	# body discovery
	if not aware and Engine.get_physics_frames() % 3 == 0:
		for c in get_tree().get_nodes_in_group("corpses"):
			var corpse := c as Corpse
			if corpse == null or corpse.discovered or corpse.is_player:
				continue
			var tc := corpse.global_position - global_position
			if tc.length() < data.view_distance * 0.8 and absf(angle_difference(facing.angle(), tc.angle())) < deg_to_rad(data.view_angle_deg * 0.5) and _clear_line(global_position, corpse.global_position):
				corpse.discovered = true
				_last_known = corpse.global_position
				_goal = corpse.global_position
				_show_icon("!")
				Audio.play_at("alert", global_position, -6.0)
				Events.noise.emit(global_position, 150.0, &"voice", self)
				_set_state(State.INVESTIGATE)
				break

func _clear_line(a: Vector2, b: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, Layers.SIGHT_MASK, [get_rid()])
	return space.intersect_ray(q).is_empty()

func _on_noise(pos: Vector2, radius: float, kind: StringName, source: Node) -> void:
	if not is_alive() or state == State.DOWNED or source == self or _held:
		return
	var d := global_position.distance_to(pos)
	var r := radius * data.hearing_mult
	if d > r:
		return
	if kind != &"voice" and kind != &"alarm" and not _clear_line(global_position, pos):
		if d > r * 0.55:
			return   # walls muffle sound
	if kind == &"voice" and source is Enemy and (source as Enemy).is_aware() and source != self:
		# an ally shouting: pass the alert along
		if not is_aware():
			_last_known = (source as Enemy)._last_known
			_goal = _last_known
			_set_state(State.INVESTIGATE)
		return
	if is_aware():
		if not _sees_player and kind in [&"gunshot", &"explosion"]:
			_last_known = pos
		return
	_last_known = pos
	_goal = pos
	if kind in [&"gunshot", &"explosion", &"alarm", &"glass", &"door"] or d < r * 0.5:
		_show_icon("!" if kind == &"gunshot" else "?")
		_set_state(State.INVESTIGATE)
	else:
		_set_state(State.SUSPICIOUS)
		_show_icon("?")

func zone_name() -> String:
	if level and level.has_method("zone_at"):
		return level.zone_at(global_position)
	return ""

func _on_lights_changed(zone: StringName, on: bool) -> void:
	if not is_alive() or state == State.DOWNED or _held:
		return
	if String(zone) != zone_name():
		return
	if on:
		_dark_confused = 0.0
		return
	_dark_confused = 4.0
	if not is_aware():
		_show_icon("?")
		_last_known = global_position + Vector2.from_angle(randf() * TAU) * 40.0
		_set_state(State.SUSPICIOUS)

## Level asks this enemy to walk over and flip the lights back on.
func go_fix(target: Node2D) -> void:
	if not can_fix_lights():
		return
	_fix_target = target
	_goal = target.global_position
	_last_known = _goal
	_show_icon("?")
	_set_state(State.INVESTIGATE)

func can_fix_lights() -> bool:
	var calm := not is_aware() or (state == State.SEARCH and not _sees_player)
	return is_alive() and calm and state != State.DOWNED and state != State.STUNNED and not _held and _fix_target == null \
		and data.combat != EnemyData.Combat.BOSS and data.combat != EnemyData.Combat.ALERTER

## Can be grabbed from behind (unaware, not already down).
func can_be_taken_down() -> bool:
	return is_alive() and not is_aware() and state != State.DOWNED and state != State.STUNNED and data.combat != EnemyData.Combat.BOSS

func _on_alarm(pos: Vector2) -> void:
	if not is_alive() or state == State.DOWNED:
		return
	var p := _player()
	if p:
		_last_known = p.global_position
	_goal = _last_known
	if not is_aware():
		_set_state(State.SEARCH)

func _enter_combat() -> void:
	if _held:
		return
	if state in [State.COMBAT, State.FLANK, State.RETREAT, State.CALL_REINFORCEMENTS, State.DOWNED]:
		return
	_show_icon("!")
	Audio.play_at("alert", global_position, -8.0)
	Events.enemy_alerted.emit(self)
	Events.noise.emit(global_position, data.alert_others_radius, &"voice", self)
	if data.combat == EnemyData.Combat.ALERTER:
		_set_state(State.CALL_REINFORCEMENTS)
		return
	_set_state(State.COMBAT)
	_seen_time = 0.0
	_fire_cd = data.reaction_time
	_burst_left = data.burst

# ======================================================================= behaviours
func _patrol(_delta: float) -> Vector2:
	if patrol_points.is_empty():
		return Vector2.ZERO
	var target := patrol_points[_patrol_i % patrol_points.size()]
	if global_position.distance_to(target) < 8.0:
		_patrol_i += 1
		_path = []
		return Vector2.ZERO
	return _go_to(target, data.walk_speed)

func _search(_delta: float) -> Vector2:
	if _state_t > 7.0:
		_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)
		_path = []
		return Vector2.ZERO
	if _path_done() or _path.is_empty():
		if _repath_t <= 0.0:
			_repath_t = 1.2
			var off := Vector2(randf_range(-60, 60), randf_range(-60, 60))
			_goal = _last_known + off
			_path = []
	_repath_t -= 0.016
	return _go_to(_goal, data.walk_speed * 1.5)

func _combat(delta: float) -> Vector2:
	var p := _player()
	if p == null or not p.alive:
		_set_state(State.SEARCH)
		return Vector2.ZERO
	var to := _last_known - global_position
	var dist := global_position.distance_to(p.global_position)
	if not _sees_player and _state_t > 0.2:
		# lost sight: hunt last known position, maybe flank
		if global_position.distance_to(_last_known) < 14.0:
			_set_state(State.SEARCH)
			return Vector2.ZERO
		return _go_to(_last_known, data.run_speed)
	facing = facing.slerp(to.normalized(), minf(1.0, delta * 14.0))
	match data.combat:
		EnemyData.Combat.MELEE_RUSHER, EnemyData.Combat.SHIELD:
			return _melee_combat(p, dist, delta)
		EnemyData.Combat.ALERTER:
			_set_state(State.CALL_REINFORCEMENTS)
			return Vector2.ZERO
		_:
			return _gun_combat(p, dist, delta)

func _gun_combat(p: Player, dist: float, _delta: float) -> Vector2:
	if weapon == null or not weapon.data.is_firearm():
		return _melee_combat(p, dist, _delta)
	var move := Vector2.ZERO
	var to := (p.global_position - global_position).normalized()
	if dist < 36.0:
		move = -to * data.walk_speed * 1.2        # back off
	elif dist > data.preferred_range * 1.6:
		move = _go_to(p.global_position, data.walk_speed * 1.2)
	else:
		move = to.orthogonal() * _strafe * data.walk_speed * 0.5
		if randf() < 0.01:
			_strafe *= -1.0
	if _reload_t > 0.0:
		return move * 0.6
	if weapon.ammo <= 0:
		_reload_t = weapon.data.reload_time * 1.35
		Audio.play_at("reload", global_position, -8.0)
		return move
	if _fire_cd <= 0.0:
		_shoot(p)
	return move

func _shoot(p: Player) -> void:
	var aim := (p.global_position + p.velocity * 0.05 - global_position).normalized()
	var err := data.aim_error_deg + (6.0 if p.is_dashing() else 0.0)
	var origin := visual.muzzle_global()
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, origin, Layers.WORLD | Layers.DOOR | Layers.PROP, [get_rid()])
	if not space.intersect_ray(q).is_empty():
		origin = global_position
	var bs := BulletSystem.get_system()
	if bs:
		bs.fire(origin, aim, weapon.data, self, err + weapon.data.spread_deg * 0.5)
	weapon.ammo -= 1
	visual.kick_recoil(2.0)
	Effects.muzzle(origin, aim, weapon.data.muzzle_color, weapon.data.pellets > 1)
	Effects.casing(global_position, aim)
	Audio.play_at(weapon.data.sfx_fire, global_position, -2.0)
	Events.noise.emit(global_position, weapon.data.noise_radius * 0.8, &"gunshot", self)
	_burst_left -= 1
	if _burst_left > 0:
		_fire_cd = data.burst_gap
	else:
		_burst_left = data.burst
		_fire_cd = maxf(1.0 / (weapon.data.fire_rate * 0.55), 0.35) + randf_range(0.0, 0.25)

func _melee_combat(p: Player, dist: float, delta: float) -> Vector2:
	var to := (p.global_position - global_position).normalized()
	if _windup_t >= 0.0:
		_windup_t += delta
		if _windup_t >= data.melee_windup:
			_windup_t = -1.0
			_melee_cd = 0.6
			visual.swing(true)
			Effects.slash(global_position + facing * 3.0, facing.angle(), MELEE_REACH + 4.0, 2.0, Color(1.0, 0.35, 0.35), false, false, visual._swing_dir)
			Audio.play_at("swing", global_position)
			if p.global_position.distance_to(global_position) < MELEE_REACH + 6.0 and absf(angle_difference(facing.angle(), to.angle())) < 1.2:
				var info := DamageInfo.make(DamageInfo.Type.MELEE, self, p.global_position, to, weapon.data.id if weapon else &"fists", &"melee")
				info.lethal = true
				p.take_damage(info)
		return to * 20.0
	if dist < MELEE_REACH and _melee_cd <= 0.0:
		_windup_t = 0.0
		visual.flash(0.06)
		return Vector2.ZERO
	var speed := data.run_speed
	if data.combat == EnemyData.Combat.SHIELD:
		speed = data.walk_speed * (1.8 if _shield_down > 0.0 else 1.0)
	if _clear_line(global_position, p.global_position) and dist < 120.0:
		return to * speed
	return _go_to(p.global_position, speed)

func _call_reinforcements(_delta: float) -> Vector2:
	# run to the nearest alarm panel; if none, scream and flee
	var alarm := _nearest_alarm()
	if alarm == null:
		if _state_t < 0.1:
			Events.noise.emit(global_position, 320.0, &"voice", self)
			Audio.play_at("alert", global_position)
		_set_state(State.FLEE)
		return Vector2.ZERO
	if global_position.distance_to(alarm.global_position) < 16.0:
		alarm.trigger(self)
		_set_state(State.FLEE)
		return Vector2.ZERO
	return _go_to(alarm.global_position, data.run_speed)

func _nearest_alarm() -> Node2D:
	var best: Node2D = null
	var bd := 900.0
	for a in get_tree().get_nodes_in_group("alarm"):
		if a.has_method("is_armed") and not a.is_armed():
			continue
		var d := global_position.distance_to((a as Node2D).global_position)
		if d < bd:
			bd = d
			best = a
	return best

func _flee(_delta: float) -> Vector2:
	var p := _player()
	if _state_t > (2.5 if state == State.PANIC else 5.0):
		_set_state(State.COMBAT if weapon else State.SEARCH)
		return Vector2.ZERO
	if p == null:
		return Vector2.ZERO
	if _path_done() or _path.is_empty():
		var away := (global_position - p.global_position).normalized()
		_goal = global_position + away.rotated(randf_range(-0.7, 0.7)) * 140.0
		_path = []
	return _go_to(_goal, data.run_speed)

func _separation() -> Vector2:
	var push := Vector2.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not e.is_alive():
			continue
		var d: Vector2 = global_position - (e as Node2D).global_position
		var l := d.length()
		if l < 14.0 and l > 0.01:
			push += d / l * (14.0 - l) * 6.0
	return push

# ======================================================================= navigation
func _go_to(target: Vector2, speed: float) -> Vector2:
	_repath_t -= get_physics_process_delta_time()
	if _path.is_empty() or _repath_t <= 0.0 or (_path.size() > 0 and _path[_path.size() - 1].distance_to(target) > 24.0):
		_repath_t = 0.45 + randf() * 0.2
		if level and level.has_method("get_nav_path"):
			_path = level.get_nav_path(global_position, target)
		else:
			_path = PackedVector2Array([target])
		_path_i = 0
	while _path_i < _path.size() and global_position.distance_to(_path[_path_i]) < 6.0:
		_path_i += 1
	if _path_i >= _path.size():
		var d := target - global_position
		return d.normalized() * speed if d.length() > 4.0 else Vector2.ZERO
	return (_path[_path_i] - global_position).normalized() * speed

func _path_done() -> bool:
	return not _path.is_empty() and _path_i >= _path.size()

# ======================================================================= damage
func hit_point(_from: Vector2) -> Vector2:
	return global_position

func take_damage(info: DamageInfo) -> String:
	if not is_alive():
		return "pass"
	# no friendly fire between enemies' bullets: rounds pass through allies
	if info.type == DamageInfo.Type.BALLISTIC and info.source is Enemy and info.source != self:
		return "pass"
	var from_front := absf(angle_difference(facing.angle(), (-info.dir).angle())) < deg_to_rad(data.shield_arc_deg * 0.5)
	if state == State.DOWNED:
		if info.lethal or info.type == DamageInfo.Type.BALLISTIC:
			_die(info)
			return "killed"
		return "ignored"
	# riot shield
	if data.shield_arc_deg > 0.0 and _shield_down <= 0.0 and from_front:
		match info.type:
			DamageInfo.Type.BALLISTIC, DamageInfo.Type.PUNCH:
				Audio.play_at("shield_block", global_position, -4.0)
				Effects.sparks(info.pos, -info.dir)
				_react_to_attack(info)
				return "blocked"
			DamageInfo.Type.MELEE:
				if not info.heavy and info.method != &"counter":
					Audio.play_at("shield_block", global_position)
					_react_to_attack(info)
					return "blocked"
			DamageInfo.Type.THROWN, DamageInfo.Type.DOOR:
				_shield_down = 1.4
				_stun(0.6, info.dir)
				Audio.play_at("shield_block", global_position)
				return "hurt"
	# body armour soaks bullets
	if armor_left > 0 and info.type == DamageInfo.Type.BALLISTIC:
		armor_left -= 1
		visual.flash(0.1)
		_knock = info.dir * 90.0
		Effects.sparks(info.pos, -info.dir)
		Audio.play_at("metal_clang", global_position, -6.0)
		_react_to_attack(info)
		_on_armor_hit(info)
		return "absorbed"
	if not info.lethal:
		if data.immune_to_punch and not info.heavy and info.type in [DamageInfo.Type.PUNCH, DamageInfo.Type.THROWN, DamageInfo.Type.DOOR]:
			_knock = info.dir * 40.0
			_react_to_attack(info)
			return "blocked" if info.type == DamageInfo.Type.PUNCH else "hurt"
		if data.can_be_knocked_down:
			knock_down(info)
			return "hurt"
		_stun(0.35, info.dir)
		return "hurt"
	if info.type == DamageInfo.Type.MELEE and data.immune_to_punch and not info.heavy and armor_left > 0:
		return "blocked"
	_die(info)
	return "killed"

func _on_armor_hit(_info: DamageInfo) -> void:
	pass   # boss override

func _react_to_attack(info: DamageInfo) -> void:
	if info.source and is_instance_valid(info.source) and info.source is Node2D:
		_last_known = (info.source as Node2D).global_position
	_enter_combat()

func knock_down(info: DamageInfo) -> void:
	_windup_t = -1.0
	_set_state(State.DOWNED)
	_down_t = DOWN_TIME
	_knock = info.dir * info.knockback
	visual.torso.texture = SpriteLib.downed(data.palette)
	visual.legs.visible = false
	visual.weapon_sprite.visible = false
	facing = -info.dir
	collision_layer = Layers.DOWNED   # still shootable, no longer blocks movement
	Audio.play_at("body_fall", global_position)
	# downed enemies drop their weapon: grab it and execute them with it
	if weapon and randf() < 0.75:
		_drop_weapon(info.dir.rotated(randf_range(-1.0, 1.0)) * 90.0)
	Events.enemy_downed.emit(self)

func _get_up() -> void:
	visual.legs.visible = true
	visual.set_weapon(weapon.data if weapon else null)
	collision_layer = Layers.ENEMY
	_set_state(State.COMBAT)
	_fire_cd = data.reaction_time + 0.2
	var p := _player()
	if p:
		_last_known = p.global_position

func _stun(t: float, dir: Vector2) -> void:
	_windup_t = -1.0
	_stun_t = t
	_knock = dir * 120.0
	_set_state(State.STUNNED)

func begin_execution(by: Node) -> void:
	_executor = by
	_down_t = 99.0
	if state != State.DOWNED:
		# stealth takedown: grabbed from behind, frozen in place
		_held = true
		_windup_t = -1.0
		_stun_t = 99.0
		_knock = Vector2.ZERO
		state = State.STUNNED
		_state_t = 0.0

func finish_execution(by: Node, weapon_id: StringName, finisher := "") -> void:
	var info := DamageInfo.make(DamageInfo.Type.MELEE, by, global_position, global_position - (by as Node2D).global_position, weapon_id, &"execution")
	info.lethal = true
	info.set_meta("finisher", finisher)
	_die(info)

func _die(info: DamageInfo) -> void:
	_was_unaware_when_killed = not is_aware() and state != State.DOWNED
	var prev_state := state
	state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	remove_from_group("damageable")
	var src_pos := global_position - info.dir * 40.0
	if info.source and is_instance_valid(info.source) and info.source is Node2D:
		src_pos = (info.source as Node2D).global_position
	var missing := _gore_kill(info, src_pos)
	_spawn_corpse(info, missing)
	Effects.blood(global_position, info.dir, info.type in [DamageInfo.Type.EXPLOSIVE, DamageInfo.Type.BALLISTIC] or info.method == &"execution")
	Audio.play_at("death", global_position, -3.0)
	if weapon and info.method != &"execution":
		_drop_weapon(info.dir * 60.0)
	var p := _player()
	var from_player: bool = info.from_player or bool(info.get_meta("player_caused", false))
	if from_player:
		var method: StringName = info.method
		if info.type == DamageInfo.Type.DOOR:
			method = &"door"
		elif info.type == DamageInfo.Type.EXPLOSIVE:
			method = &"explosion"
		elif info.type == DamageInfo.Type.ENVIRONMENT or info.type == DamageInfo.Type.ELECTRIC or info.type == DamageInfo.Type.FIRE:
			method = &"environment"
		Events.enemy_killed.emit(self, {"method": method, "weapon_id": info.weapon_id, "pos": global_position,
			"silent": _was_unaware_when_killed and prev_state != State.DOWNED, "while_dashing": p != null and p.is_dashing(),
			"slowmo": Game.get_slowmo() < 0.99})
	SaveManager.add_stat("kills")
	# nearby allies may panic
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.is_alive() and e.global_position.distance_to(global_position) < 120.0:
			e.ally_died(global_position)
	died.emit(self, info)
	queue_free()

func _gore_kill(info: DamageInfo, src_pos: Vector2) -> String:
	return Gore.on_kill(global_position, info, data.palette, src_pos)

func _spawn_corpse(info: DamageInfo, missing: String) -> void:
	var corpse := Corpse.new()
	corpse.setup(data.palette, info.dir, false, missing)
	corpse.global_position = global_position
	get_parent().add_child(corpse)

func ally_died(pos: Vector2) -> void:
	if _panic_rolled or data.panic_chance <= 0.0 or state == State.DOWNED:
		return
	_panic_rolled = true
	if randf() < data.panic_chance:
		_set_state(State.PANIC)
		_show_icon("!")
		_last_known = pos

func _drop_weapon(vel: Vector2) -> void:
	if weapon == null:
		return
	var parent: Node = level.pickup_root() if level and level.has_method("pickup_root") else get_parent()
	weapon.reserve = weapon.data.reserve_on_pickup() / 2 if weapon.data.is_firearm() else weapon.reserve
	WeaponPickup.spawn(parent, weapon, global_position, vel)
	weapon = null   # disarmed shooters fall back to brawling (see _gun_combat)

# ======================================================================= misc
func _set_state(s: State) -> void:
	if s == state:
		return
	state = s
	_state_t = 0.0
	_path = []
	_windup_t = -1.0 if s != State.COMBAT else _windup_t
	state_changed.emit(self, s)

func _show_icon(ch: String) -> void:
	_alert_char = ch
	_alert_icon = 0.9
	queue_redraw()

func _draw() -> void:
	if data and data.shield_arc_deg > 0.0 and is_alive() and state != State.DOWNED:
		var a := facing.angle()
		var col := Color(0.6, 0.66, 0.78, 0.95) if _shield_down <= 0.0 else Color(0.6, 0.66, 0.78, 0.3)
		draw_arc(Vector2.ZERO, 9.0, a - 0.9, a + 0.9, 8, col, 3.0)
		draw_arc(Vector2.ZERO, 10.5, a - 0.8, a + 0.8, 8, Color(0.1, 0.1, 0.15), 1.0)
	if _alert_icon > 0.0:
		var c := UIStyle.HOT if _alert_char == "!" else UIStyle.GOLD
		draw_string(UIStyle.font_bold(), Vector2(-3, -12), _alert_char, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
	if debug_draw:
		draw_string(UIStyle.font_mono(), Vector2(-20, 18), state_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.YELLOW)
		var a2 := facing.angle()
		var hv := deg_to_rad(data.view_angle_deg * 0.5)
		draw_line(Vector2.ZERO, Vector2.from_angle(a2 - hv) * data.view_distance * 0.3, Color(1, 1, 0, 0.4))
		draw_line(Vector2.ZERO, Vector2.from_angle(a2 + hv) * data.view_distance * 0.3, Color(1, 1, 0, 0.4))
		for i in range(maxi(0, _path_i), _path.size()):
			draw_circle(to_local(_path[i]), 1.5, Color(0, 1, 1, 0.6))
