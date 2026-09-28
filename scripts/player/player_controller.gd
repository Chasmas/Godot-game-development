class_name Player
extends CharacterBody2D
## The player. One hit kills you; you kill everyone in one hit too.
## Handles movement (accel, sprint, dash/vault/window-dive), aiming (mouse or
## stick with optional aim assist), firearms, melee (quick/heavy/counter),
## punches, throws, pickups, kicks, executions, ability and equipment.

signal died(info: Dictionary)

const RADIUS := 5.0
const EXEC_RANGE := 20.0
const KICK_RANGE := 22.0
const TAKEDOWN_RANGE := 22.0
const LOCK_RANGE := 300.0

var data: CharacterData
var persona: PersonaData
var visual: CharacterVisual
var ability: AbilitySystem
var slots: Array = [null, null]      # WeaponInstance or null
var slot := 0
var alive := true
var god_mode := false
## Seconds after respawning at a checkpoint during which no enemy can see
## or hear you: time to get your bearings. Attacking ends it at once.
var respawn_grace := 0.0
var noclip := false
var aim_dir := Vector2.RIGHT
var aim_point := Vector2.ZERO
var prompt := ""
var equipment_left := 2
var bones := 0
## Stamina: a roll costs a chunk, sprinting burns it steadily; it comes back
## quickly once she stops spending it. Run it dry sprinting and she's winded
## (no sprint) until a third is back.
const STAMINA_MAX := 100.0
const ROLL_COST := 30.0
const SPRINT_DRAIN := 20.0      ## per second: five seconds of flat-out running
const STAMINA_REGEN := 34.0     ## per second, after the pause below
const STAMINA_DELAY := 0.55
var stamina := STAMINA_MAX
var _stamina_rest := 0.0
var _winded := false
var _stamina_denied := 0.0
var _stamina_ring: Node2D   ## meat bones to throw to the dogs (thrown before flares)
var extra_hits := 0
var _volley_ready := false   ## the cowboy's fan shot, armed by a dash
var input_enabled := true
var level: Node                       # the Level node (for spawning)

var _fire_cd := 0.0
var _bloom := 0.0
var _reload_t := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_extend := 0.0
var _iframes := 0.0
var _melee_cd := 0.0
var _hold_t := 0.0
var _heavy_ready := false
var _pending_melee := -1.0
var _pending_heavy := false
var _locked_t := 0.0
var _exec_target: Enemy = null
var _exec_hits := 0
var _exec_total := 0.5
var _exec_elapsed := 0.0
var _exec_done := 0
var _step_t := 0.0
var _kick_cd := 0.0
var _stagger := 0.0
var _tackled: Array = []
var _last_move := Vector2.ZERO
var _exec_move: Dictionary = {}
var _exec_standing := false
# lock-on
var lock_target: Node2D = null
var _lock_hold := 0.0
var _lock_press_locked := false
var _lock_flick_ready := true
# stealth / upgrades
var sneak_held := false
var upgrades: Dictionary = {}          ## id -> true
var armor_hits := 0
var _adrenaline_t := 0.0
var _dash_total := 0.15
var _dash_avg := 400.0
## Easy difficulty: hits absorbed before a lethal one lands; regenerates
## after a quiet spell (see Tuning.player_guard_*).
var guard_hits := 0
var _dual_left := false                ## which gun fires next when dual wielding
var _reload_weapon: WeaponInstance = null
var _guard_regen_t := 0.0
var _laser: Node2D
var _vest: Node2D

func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WALK_MASK_PLAYER
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	shape.shape = c
	add_child(shape)
	visual = CharacterVisual.new()
	add_child(visual)
	ability = AbilitySystem.new()
	add_child(ability)
	z_index = 2
	Events.enemy_killed.connect(_on_any_kill)

## Re-reads the mask after it's been picked at the start of a job.
func apply_mask() -> void:
	persona = Masks.current() if data.id == &"cass" else DB.persona(data.persona)
	ability.setup(data.ability, self, persona.ability_charge_mult if persona else 1.0)
	extra_hits = 1 if (persona and persona.extra_hit) else 0
	guard_hits = 0 if (persona and persona.first_hit_kills) else int(Difficulty.value("player_guard_hits"))
	if persona and persona.first_hit_kills:
		extra_hits = 0
	if persona and persona.no_guns:
		for i in slots.size():
			if slots[i] and (slots[i] as WeaponInstance).data.is_firearm():
				slots[i] = null
		_refresh_weapon()
	Events.hint.emit(tr(persona.display_name) if persona else "", 1.6)

func setup(p_data: CharacterData) -> void:
	data = p_data
	if data == null:
		data = CharacterData.new()
	# Cass wears the mask chosen for the job; the others their own persona
	persona = Masks.current() if data.id == &"cass" else DB.persona(data.persona)
	visual.setup(data.palette)
	visual.idle_fidgets = true
	visual.set_persona_overlay(persona != null)
	ability.setup(data.ability, self, persona.ability_charge_mult if persona else 1.0)
	equipment_left = data.equipment_count
	extra_hits = 1 if (persona and persona.extra_hit) else 0
	guard_hits = int(Difficulty.value("player_guard_hits"))
	if persona and persona.first_hit_kills:
		guard_hits = 0
		extra_hits = 0
	if data.start_weapon != &"":
		var w := DB.weapon(data.start_weapon)
		if w:
			slots[0] = WeaponInstance.create(w)
	_refresh_weapon()

func current() -> WeaponInstance:
	return slots[slot]

# =============================================================== main loop
func _physics_process(delta: float) -> void:
	if not alive:
		return
	var tm := ability.player_time_mult()
	var pd := delta * tm
	_tick_timers(pd)
	_update_lock(pd)
	_update_aim()
	if _locked_t > 0.0:
		_locked_t -= pd
		_process_execution(pd)
		velocity = Vector2.ZERO
		visual.update_move(Vector2.ZERO, pd)
		return
	var move := Vector2.ZERO
	if input_enabled:
		move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move.length() > 1.0:
		move = move.normalized()
	_last_move = move
	_movement(move, pd)
	if input_enabled:
		_actions(pd)
	# spotlight: scale motion so the player keeps near-normal speed while the world slows
	var real_vel := velocity
	velocity *= tm
	move_and_slide()
	velocity = real_vel
	_after_move()
	visual.update_move(velocity, pd)
	visual.set_aim(aim_dir.angle())
	_update_prompt()
	_footsteps(pd)

func _tick_timers(pd: float) -> void:
	respawn_grace = maxf(0.0, respawn_grace - pd)
	_fire_cd = maxf(0.0, _fire_cd - pd)
	_dash_cd = maxf(0.0, _dash_cd - pd)
	_stamina_denied = maxf(0.0, _stamina_denied - pd * 2.5)
	if _stamina_rest > 0.0:
		_stamina_rest -= pd
	elif stamina < STAMINA_MAX:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * pd)
	if _winded and stamina >= STAMINA_MAX * 0.34:
		_winded = false
	if _stamina_ring == null:
		_stamina_ring = StaminaRing.new()
		_stamina_ring.player = self
		add_child(_stamina_ring)
	_iframes = maxf(0.0, _iframes - pd)
	_melee_cd = maxf(0.0, _melee_cd - pd)
	_kick_cd = maxf(0.0, _kick_cd - pd)
	_stagger = maxf(0.0, _stagger - pd)
	_bloom = move_toward(_bloom, 0.0, pd * 14.0)
	_adrenaline_t = maxf(0.0, _adrenaline_t - pd)
	var guard_max := int(Difficulty.value("player_guard_hits"))
	if guard_hits < guard_max:
		_guard_regen_t -= pd
		if _guard_regen_t <= 0.0:
			guard_hits += 1
			Events.hint.emit("GUARD BACK UP", 0.8)
			Audio.play("blip", -10.0, 1.3)
	if _reload_t > 0.0:
		_reload_t -= pd
		if _reload_t <= 0.0:
			_finish_reload()
	if _pending_melee >= 0.0:
		_pending_melee -= pd
		if _pending_melee < 0.0:
			_melee_hit(_pending_heavy)

func _update_aim() -> void:
	if lock_target and is_instance_valid(lock_target):
		var tv: Vector2 = lock_target.velocity if lock_target is CharacterBody2D else Vector2.ZERO
		var tp := lock_target.global_position + tv * 0.05
		var d0 := tp - global_position
		if d0.length() > 2.0:
			aim_dir = d0.normalized()
		aim_point = lock_target.global_position
		return
	var pad := InputSetup.using_gamepad
	if pad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.3:
			aim_dir = stick.normalized()
		elif _last_move.length() > 0.2:
			aim_dir = aim_dir.slerp(_last_move.normalized(), 0.25)
		aim_dir = _aim_assist(aim_dir, float(SaveManager.get_setting("aim_assist", 0.5)))
		aim_point = global_position + aim_dir * 120.0
	else:
		aim_point = get_global_mouse_position()
		var d := aim_point - global_position
		if d.length() > 2.0:
			aim_dir = d.normalized()
		var assist := float(SaveManager.get_setting("aim_assist", 0.5)) * 0.25
		if assist > 0.0:
			aim_dir = _aim_assist(aim_dir, assist)

func _aim_assist(dir: Vector2, strength: float) -> Vector2:
	if strength <= 0.01:
		return dir
	var best: Node2D = null
	var best_ang := deg_to_rad(4.0 + 10.0 * strength)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector2 = (e as Node2D).global_position - global_position
		if to.length() > 320.0:
			continue
		var a := absf(angle_difference(dir.angle(), to.angle()))
		if a < best_ang and _has_los(global_position, (e as Node2D).global_position):
			best_ang = a
			best = e
	if best:
		var target := (best.global_position - global_position).normalized()
		return dir.slerp(target, clampf(0.35 + 0.5 * strength, 0.0, 1.0)).normalized()
	return dir

# =============================================================== lock-on
func _lock_candidates() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var d := (e as Node2D).global_position.distance_to(global_position)
		if d > LOCK_RANGE or not _has_los(global_position, (e as Node2D).global_position, e):
			continue
		out.append([d, e])
	out.sort_custom(func(a, b): return a[0] < b[0])
	var res: Array = []
	for pair in out:
		res.append(pair[1])
	return res

func set_lock(t: Node2D) -> void:
	if t == lock_target:
		return
	lock_target = t
	Events.lock_changed.emit(t)
	if t:
		Audio.play("blip", -6.0, 1.6)

func _update_lock(pd: float) -> void:
	var real := pd / maxf(Engine.time_scale, 0.05)
	if lock_target != null:
		var lost: bool = not is_instance_valid(lock_target) or not lock_target.is_alive() \
			or lock_target.global_position.distance_to(global_position) > LOCK_RANGE * 1.4
		if lost:
			lock_target = null
			var nxt: Array = _lock_candidates() if SaveManager.get_setting("lock_auto_next", true) else []
			set_lock(nxt[0] if not nxt.is_empty() else null)
			if lock_target == null:
				Events.lock_changed.emit(null)
	if not input_enabled:
		return
	if Input.is_action_just_pressed("lock_on"):
		_lock_hold = 0.0
		_lock_press_locked = lock_target != null
		var c := _lock_candidates()
		if lock_target == null:
			if c.is_empty():
				Audio.play("empty", -10.0)
			else:
				set_lock(c[0])
		else:
			var i := c.find(lock_target)
			if c.size() > 1:
				set_lock(c[(i + 1) % c.size()])
	elif Input.is_action_pressed("lock_on") and _lock_press_locked:
		_lock_hold += real
		if _lock_hold > 0.4 and lock_target:
			set_lock(null)
			Events.lock_changed.emit(null)
			Audio.play("blip", -8.0, 0.8)
			_lock_press_locked = false
	# flick the right stick to hop to the target in that direction
	if lock_target and InputSetup.using_gamepad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > 0.85 and _lock_flick_ready:
			_lock_flick_ready = false
			var best: Node2D = null
			var best_a := 1.0
			for e in _lock_candidates():
				if e == lock_target:
					continue
				var to: Vector2 = (e as Node2D).global_position - lock_target.global_position
				var a := absf(angle_difference(stick.angle(), to.angle()))
				if a < best_a:
					best_a = a
					best = e
			if best:
				set_lock(best)
		elif stick.length() < 0.35:
			_lock_flick_ready = true

# =============================================================== movement
func _movement(move: Vector2, pd: float) -> void:
	if _dash_t > 0.0:
		_dash_t -= pd
		# fast push-off easing into the roll-out: reads as a shove, not a
		# teleport, and the distance stays exactly speed * time * scale
		var tn := Tuning.get_t()
		var k := clampf(1.0 - _dash_t / maxf(_dash_total, 0.001), 0.0, 1.0)
		var shape := lerpf(tn.dash_start_mult, tn.dash_end_mult, 1.0 - pow(1.0 - k, 2.0))
		var mean := (tn.dash_start_mult + 2.0 * tn.dash_end_mult) / 3.0   # average of the eased curve
		velocity = _dash_dir * _dash_avg * shape / mean
		if _dash_t <= 0.0:
			if _overlaps(Layers.LOW | Layers.PIT) and _dash_extend < 0.25:
				_dash_t = 0.02
				_dash_extend += 0.02
			else:
				_end_dash()
		return
	var speed := data.move_speed * (persona.move_mult if persona else 1.0)
	sneak_held = input_enabled and Input.is_action_pressed("sneak")
	if sneak_held:
		speed *= 0.45
	elif Input.is_action_pressed("sprint") and move.length() > 0.1 and not _winded and stamina > 0.0:
		speed *= data.sprint_mult
		stamina = maxf(0.0, stamina - SPRINT_DRAIN * pd)
		_stamina_rest = STAMINA_DELAY * 0.5
		if stamina <= 0.0:
			_winded = true   # run dry: no sprinting until she's got a third back
	if _adrenaline_t > 0.0:
		speed *= 1.3
	if _stagger > 0.0:
		speed *= 0.3
	var target := move * speed
	var rate := data.accel if move.length() > 0.05 else data.decel
	# quick turns: reversing direction uses the (higher) decel rate
	if move.length() > 0.05 and velocity.dot(target) < 0.0:
		rate = data.decel * 1.3
	velocity = velocity.move_toward(target, rate * pd)

func _start_dash() -> void:
	if _dash_cd > 0.0 or _dash_t > 0.0:
		return
	if stamina < ROLL_COST:
		# out of breath: no roll, just a stumble of the shoulders
		_stamina_denied = 1.0
		Events.tutorial.emit("stamina")
		Audio.play_at("dash", global_position, -18.0, 0.0)
		return
	stamina -= ROLL_COST
	_stamina_rest = STAMINA_DELAY
	_dash_dir = _last_move.normalized() if _last_move.length() > 0.2 else aim_dir
	# shorter dodge: split the reduction between speed and time so it keeps
	# its snap but doesn't cross a room
	var sc := sqrt(Tuning.get_t().dash_distance_scale)
	# a roll, not a blink: longer and a little slower, so the body has time
	# to go over and come up - about the same ground covered
	_dash_total = data.dash_time * sc * 1.8
	_dash_avg = data.dash_speed * sc * 0.62
	_dash_t = _dash_total
	_dash_extend = 0.0
	_dash_cd = data.dash_cooldown * (persona.dash_cd_mult if persona else 1.0)
	_volley_ready = persona != null and persona.dash_volley
	_iframes = 0.2
	visual.roll(_dash_dir, _dash_total)
	Effects.dust(global_position, -_dash_dir, 0.8)
	_tackled.clear()
	collision_mask = Layers.WALK_MASK_PLAYER & ~Layers.LOW & ~Layers.GLASS & ~Layers.ENEMY
	Audio.play_at("dash", global_position, -4.0)
	Effects.smoke(global_position)
	Events.camera_punch.emit(1.045, 0.11)
	Events.camera_nudge.emit(-_dash_dir * 2.5)

func _end_dash() -> void:
	_dash_t = 0.0
	Effects.dust(global_position, _dash_dir, 0.5)
	collision_mask = Layers.WALK_MASK_PLAYER
	velocity = _dash_dir * data.move_speed * 0.8   # roll out of it

func is_dashing() -> bool:
	return _dash_t > 0.0

## Moving slowly (sneak key, or a light touch on the stick) or standing still:
## no footstep noise, and unaware enemies won't sense you from behind.
func is_quiet() -> bool:
	if _dash_t > 0.0:
		return false
	var limit := data.move_speed * (1.05 if upgrades.has(&"soft_soles") else 0.6)
	return velocity.length() <= limit

func has_upgrade(id: StringName) -> bool:
	return upgrades.has(id)

func _after_move() -> void:
	if _dash_t > 0.0 and _dash_t < _dash_total - 0.02 and _dash_extend <= 0.0:
		# ran into a wall: end the dodge cleanly instead of grinding along it
		var got := get_real_velocity().length()
		if got < _dash_avg * Tuning.get_t().dash_blocked_fraction and not _overlaps(Layers.LOW | Layers.PIT):
			_end_dash()
			velocity = Vector2.ZERO
			Events.camera_shake.emit(1.5)
			Effects.dust(global_position + _dash_dir * 5.0, -_dash_dir, 0.5)
			return
	if _dash_t > 0.0:
		# dive through windows, shoulder-check enemies
		var space := get_world_2d().direct_space_state
		var q := PhysicsShapeQueryParameters2D.new()
		var c := CircleShape2D.new()
		c.radius = RADIUS + 3.0
		q.shape = c
		q.transform = global_transform
		q.collision_mask = Layers.GLASS | Layers.ENEMY
		q.exclude = [get_rid()]
		for r in space.intersect_shape(q, 8):
			var col: Object = r.collider
			if col == null or _tackled.has(col):
				continue
			_tackled.append(col)
			if col.is_in_group("glass"):
				col.shatter(_dash_dir)
				Events.camera_shake.emit(3.0)
			elif col.is_in_group("enemies") and col.has_method("take_damage"):
				var info := DamageInfo.make(DamageInfo.Type.PUNCH, self, global_position, _dash_dir, &"tackle", &"punch")
				info.lethal = false
				info.knockback = 220.0
				var res := str(col.take_damage(info))
				Audio.play_at("punch", global_position)
				Events.camera_shake.emit(4.0)
				Events.hit_stop.emit(0.05)
				if res == "blocked":
					_end_dash()
					velocity = -_dash_dir * 120.0
					_stagger = 0.3

func _overlaps(mask: int) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	q.shape = c
	q.transform = global_transform
	q.collision_mask = mask
	return not space.intersect_shape(q, 1).is_empty()

func _footsteps(pd: float) -> void:
	var sp := velocity.length()
	if sp < 30.0 or _dash_t > 0.0:
		return
	_step_t -= pd * (sp / data.move_speed)
	if _step_t <= 0.0:
		_step_t = 0.27
		Audio.play_at("step%d" % (randi() % 3), global_position, -24.0 if is_quiet() else -16.0)
		var sprinting := sp > data.move_speed * 1.1
		if is_quiet():
			return
		var r := 120.0 if sprinting else 36.0
		if upgrades.has(&"soft_soles"):
			r *= 0.5
		Events.noise.emit(global_position, r, &"step", self)

# =============================================================== actions
func _actions(pd: float) -> void:
	if Input.is_action_just_pressed("dash"):
		_start_dash()
	var w := current()
	# --- fire / attack
	if w and w.data.is_firearm():
		var want := Input.is_action_pressed("fire") if w.data.automatic else Input.is_action_just_pressed("fire")
		if want:
			_try_shoot(w)
	elif w and (w.data.is_melee() or w.data.kind == WeaponData.Kind.THROWABLE):
		if Input.is_action_just_pressed("fire"):
			_hold_t = 0.0
			_heavy_ready = false
			_melee_attack(false)
		elif Input.is_action_pressed("fire"):
			_hold_t += pd
			if not _heavy_ready and _hold_t >= w.data.heavy_charge + 0.12:
				_heavy_ready = true
				visual.flash(0.05)
				Audio.play("blip", -8.0, 0.7)
		elif Input.is_action_just_released("fire") and _heavy_ready:
			_heavy_ready = false
			_melee_cd = 0.0
			_melee_attack(true)
	else:
		if Input.is_action_just_pressed("fire"):
			_punch()
	if Input.is_action_just_pressed("secondary"):
		_throw_current()
	if Input.is_action_just_pressed("reload"):
		_start_reload()
	if Input.is_action_just_pressed("swap"):
		_swap()
	if Input.is_action_just_pressed("interact"):
		_interact()
	if Input.is_action_just_pressed("execute"):
		_execute_or_kick()
	if Input.is_action_just_pressed("ability"):
		ability.activate()
	if Input.is_action_just_pressed("equipment"):
		_use_equipment()

# ---------------------------------------------------------------- firearms
func _try_shoot(w: WeaponInstance) -> void:
	if _fire_cd > 0.0 or _reload_t > 0.0:
		return
	respawn_grace = 0.0
	if Game.modifiers.get("melee_only", false):
		Events.hint.emit("MELEE ONLY — throw it (RMB)", 1.2)
		_fire_cd = 0.3
		return
	# dual wielding: guns take turns; if the one whose turn it is is dry,
	# the other fires
	var left := false
	if w.dual:
		left = _dual_left
		if (w.ammo2 if left else w.ammo) <= 0:
			left = not left
	if (w.ammo2 if left else w.ammo) <= 0:
		_fire_cd = 0.25
		if w.reserve > 0:
			_start_reload()
		else:
			Audio.play_at("empty", global_position)
			Events.hint.emit("EMPTY — throw it", 1.0)
		return
	if Game.modifiers.get("infinite_ammo", false):
		pass   # arcade: the magazine never runs dry
	elif left:
		w.ammo2 -= 1
	else:
		w.ammo -= 1
		if w.ammo == 0 and w.reserve > 0:
			Events.tutorial.emit("reload")
	_dual_left = not left
	# two guns: faster combined fire, but wilder (see _dual_* below)
	_fire_cd = 1.0 / (w.data.fire_rate * (DUAL_RATE if w.dual else 1.0))
	var move_factor := clampf(velocity.length() / data.move_speed, 0.0, 1.3)
	var spread := w.data.spread_deg + w.data.move_spread_deg * move_factor + _bloom
	if w.dual:
		spread *= DUAL_SPREAD
	if upgrades.has(&"laser"):
		spread *= 0.4
	_bloom = minf(_bloom + w.data.recoil_deg * (0.6 if upgrades.has(&"laser") else 1.0) * (DUAL_BLOOM if w.dual else 1.0), 14.0)
	var origin := visual.muzzle_global(left)
	# never spawn the bullet on the far side of a wall we're hugging
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, origin, Layers.WORLD | Layers.DOOR | Layers.PROP, [get_rid()])
	var block := space.intersect_ray(q)
	if not block.is_empty():
		origin = global_position
	if w.data.id == &"flamethrower":
		_flame_shot(origin, aim_dir)
		_emit_weapon()
		return
	var bs := BulletSystem.get_system()
	if bs:
		bs.fire(origin, _forgiving_shot(aim_dir), w.data, self, spread)
		if _volley_ready and _dash_cd > 0.0:
			# the cowboy: out of a dash, the first shot fans out three
			for side in [-1.0, 1.0]:
				bs.fire(origin, _forgiving_shot(aim_dir).rotated(side * 0.12), w.data, self, spread)
		_volley_ready = false
	visual.kick_recoil(w.data.camera_kick * (0.35 if w.dual else 0.6))
	visual.gun_recoil(left, 1.5 + w.data.camera_kick * 0.4)
	var silenced := upgrades.has(&"silencer") or w.data.suppressed
	var mscale := w.data.muzzle_scale * (0.5 if upgrades.has(&"silencer") else 1.0)
	Effects.muzzle(origin, aim_dir, w.data.muzzle_color if not upgrades.has(&"silencer") else Color(1, 0.9, 0.7), w.data.pellets > 1 and not silenced, mscale)
	if w.data.id == &"shotgun":
		# pump gun: the shell comes out when she racks it, a beat later
		var sw := w
		get_tree().create_timer(0.2, false).timeout.connect(func():
			if not is_instance_valid(self) or current() != sw:
				return
			Audio.play_at("slide_rack", global_position, -9.0, 0.08)
			visual.pump()
			Effects.casing(visual.muzzle_global(false) - aim_dir * 7.0, aim_dir, false, true))
	elif w.data.ejects_shells:
		Effects.casing(origin - aim_dir * 5.0, aim_dir, left, w.data.pellets > 1)
	Audio.play_at("suppressed" if upgrades.has(&"silencer") else w.data.sfx_fire, global_position, 0.0, 0.05)
	Events.noise.emit(global_position, gun_noise(w), &"gunshot", self)
	# every gun has its own weight: the shotgun shoves the camera back and
	# freezes a hair, the SMG just buzzes
	Events.camera_shake.emit(w.data.camera_kick * (0.8 if w.dual else 1.0))
	# every shot shoves the view back along the barrel: a tap for the 9mm,
	# a shove for the shotgun
	Events.camera_nudge.emit(-aim_dir * w.data.camera_kick * (0.8 if w.data.camera_kick >= 4.0 else 0.45))
	if w.data.fire_hit_stop > 0.0:
		Events.hit_stop.emit(w.data.fire_hit_stop)
	InputSetup.vibrate(0.2, clampf(w.data.camera_kick * 0.06, 0.08, 0.45), 0.08)
	# punch: a hair of zoom per shot, more for heavy guns, and smoke that
	# hangs where the gun went off
	Events.camera_punch.emit(1.0 + clampf(w.data.camera_kick * 0.006, 0.004, 0.035), 0.07)
	Effects.gun_smoke(origin, aim_dir, 1.4 if w.data.pellets > 1 else (0.6 if silenced else 1.0))
	_emit_weapon()

## The flamethrower: a short cone that kills what it touches and leaves
## the floor burning (the player's own fire doesn't catch the player).
func _flame_shot(origin: Vector2, dir: Vector2) -> void:
	var reach := 96.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector2 = (e as Node2D).global_position - origin
		# the flame spreads as it goes: a wide mouth close up
		var cone := 0.42 if to.length() > 36.0 else 0.9
		if to.length() < reach and absf(dir.angle_to(to)) < cone:
			var info := DamageInfo.make(DamageInfo.Type.FIRE, self, (e as Node2D).global_position, to.normalized(), &"flamethrower", &"fire")
			info.lethal = true
			info.from_player = true
			e.take_damage(info)
	if randf() < 0.45 and level:
		var at: Vector2 = level.nearest_open_point(origin + dir.rotated(randf_range(-0.25, 0.25)) * randf_range(30.0, reach), origin)
		var fz := FireZone.ignite(level.actors_root, at, randf_range(7.0, 10.0), randf_range(1.0, 1.8))
		fz.friendly = true
	var fx := FireZone.ignite(level.actors_root if level else get_parent(), origin + dir * 14.0, 5.0, 0.18)
	fx.friendly = true
	fx.harmless = true
	Audio.play_at("flame_burst", global_position, -8.0)
	Events.noise.emit(global_position, 380.0, &"gunshot", self)
	Events.camera_shake.emit(0.6)

func gun_noise(w: WeaponInstance) -> float:
	var nm := persona.noise_mult if persona else 1.0
	if upgrades.has(&"silencer"):
		return minf(w.data.noise_radius, 60.0) * 0.5 * nm
	return w.data.noise_radius * nm

const DUAL_RATE := 1.6      ## combined fire rate vs one gun (not 2x)
const DUAL_SPREAD := 1.35   ## each shot is less accurate
const DUAL_BLOOM := 1.3     ## and walks off target faster
const DUAL_RELOAD := 1.5    ## two magazines take longer

func mag_size(w: WeaponInstance) -> int:
	if upgrades.has(&"ext_mag") and w.data.is_firearm():
		return int(ceil(w.data.magazine * 1.5))
	return w.data.magazine

func _start_reload() -> void:
	var w := current()
	if w == null or not w.data.is_firearm() or w.reserve <= 0 or _reload_t > 0.0:
		return
	if w.ammo >= mag_size(w) and (not w.dual or w.ammo2 >= mag_size(w)):
		return
	_reload_t = w.data.reload_time * data.reload_mult * (persona.reload_mult if persona else 1.0) * (0.55 if upgrades.has(&"quick_hands") else 1.0) * (DUAL_RELOAD if w.dual else 1.0)
	_reload_weapon = w
	visual.reload_anim(_reload_t, "dual" if w.dual else ("shell" if w.data.pellets > 1 else "mag"))
	# guns that keep their brass dump it all on the floor when reloading:
	# the revolver's cylinder, the boomstick's two barrels
	if not w.data.ejects_shells or w.data.id == &"boomstick":
		var spent: int = mag_size(w) - w.ammo
		var at := global_position + aim_dir * 4.0
		for i in mini(spent, 8):
			get_tree().create_timer(0.12 + i * 0.03, false).timeout.connect(func():
				if is_instance_valid(self):
					Effects.casing(at, aim_dir.rotated(randf_range(2.2, 4.0)), randf() < 0.5, w.data.pellets > 1))

func _finish_reload() -> void:
	var w := current()
	# switched or threw the gun mid-reload: the reload is simply lost
	if w == null or not w.data.is_firearm() or w != _reload_weapon:
		_reload_weapon = null
		return
	_reload_weapon = null
	var take := mini(mag_size(w) - w.ammo, w.reserve)
	w.ammo += take
	w.reserve -= take
	if w.dual:
		var take2 := mini(mag_size(w) - w.ammo2, w.reserve)
		w.ammo2 += take2
		w.reserve -= take2
	_emit_weapon()

func is_reloading() -> bool:
	return _reload_t > 0.0

# ---------------------------------------------------------------- melee
func _melee_attack(heavy: bool) -> void:
	var w := current()
	if w == null or _melee_cd > 0.0:
		return
	respawn_grace = 0.0
	_melee_cd = w.data.melee_cooldown * (1.45 if heavy else 1.0) * (0.75 if upgrades.has(&"quick_hands") else 1.0)
	_turn_into_target(w.data.melee_range + (6.0 if heavy else 0.0), w.data.melee_arc_deg * 0.5)
	var stab := w.data.id in [&"knife", &"broken_bottle", &"glass_shard"]
	visual.swing(heavy, stab)
	Audio.play_at("swing_heavy" if heavy else "swing", global_position, -2.0, 0.15)
	_pending_melee = w.data.melee_windup * 0.5 + (0.04 if heavy else 0.0)
	_pending_heavy = heavy
	velocity += aim_dir * (150.0 if heavy else 85.0)   # lunge into the swing
	var blade := w.data.sfx_hit == "hit_blade"
	var tint := Color(0.75, 0.95, 1.0) if blade else Color(1.0, 0.8, 0.45)
	Effects.slash(global_position + aim_dir * 3.0, aim_dir.angle(), w.data.melee_range + (8.0 if heavy else 3.0),
		deg_to_rad(w.data.melee_arc_deg + (40.0 if heavy else 0.0)), tint, heavy, stab, visual._swing_dir)

func _punch() -> void:
	if _melee_cd > 0.0:
		return
	respawn_grace = 0.0
	_melee_cd = 0.22
	_turn_into_target(17.0, 50.0)
	visual.punch()
	Audio.play_at("swing", global_position, -8.0, 0.2)
	velocity += aim_dir * 60.0
	Effects.slash(global_position + aim_dir * 4.0, aim_dir.angle(), 14.0, 0.5, Color(1, 0.95, 0.85), false, true, 1.0)
	_pending_melee = 0.02
	_pending_heavy = false

func _melee_hit(heavy: bool) -> void:
	var w := current()
	var unarmed := w == null
	# forgiving by design: the crosshair says which way you swing, it doesn't
	# have to sit on the body - a little extra reach and a wider arc
	var rng := (17.0 if unarmed else w.data.melee_range + (6.0 if heavy else 0.0)) + MELEE_REACH_BONUS
	var arc := (100.0 if unarmed else w.data.melee_arc_deg + (40.0 if heavy else 0.0)) + MELEE_ARC_BONUS
	var hit_any := false
	var killed_any := false
	for n in get_tree().get_nodes_in_group("damageable"):
		if n == self or not is_instance_valid(n) or not (n is Node2D):
			continue
		var p: Vector2 = n.call("hit_point", global_position) if n.has_method("hit_point") else (n as Node2D).global_position
		var to := p - global_position
		var r: float = n.get("hit_radius") if n.get("hit_radius") != null else 6.0
		if to.length() - r > rng:
			continue
		if to.length() > 7.0 and absf(angle_difference(aim_dir.angle(), to.angle())) > deg_to_rad(arc * 0.5):
			continue
		if not _has_los(global_position, p, n, Layers.WORLD | Layers.DOOR):
			continue
		var method := &"punch" if unarmed else &"melee"
		if n.has_method("is_winding_up") and n.is_winding_up():
			method = &"counter"
		var info := DamageInfo.make(DamageInfo.Type.PUNCH if unarmed else DamageInfo.Type.MELEE, self, p, to, &"fists" if unarmed else w.data.id, method)
		info.lethal = (not unarmed and (w.data.lethal or heavy)) or method == &"counter"
		info.heavy = heavy
		info.knockback = 200.0 if heavy else 140.0
		if unarmed and (data.melee_damage_mult > 1.5 or upgrades.has(&"brass_knuckles") or (persona and persona.lethal_punch)):
			info.lethal = true
		var res := str(n.take_damage(info))
		if res == "blocked":
			visual.kick_recoil(5.0)
			Events.camera_nudge.emit(-aim_dir * 5.0)
			Audio.play_at("shield_block", p)
			Events.camera_shake.emit(2.0)
			continue
		if res == "pass" or res == "ignored":
			continue
		hit_any = true
		if res == "killed":
			killed_any = true
	if hit_any:
		visual.kick_recoil(-4.8 if heavy else -3.0)
		Events.camera_punch.emit(1.055 if heavy else 1.025, 0.10 if heavy else 0.065)
		Audio.play_at("punch" if unarmed else w.data.sfx_hit, global_position)
		Events.hit_stop.emit((0.085 if heavy else 0.065) if killed_any else 0.04)
		Events.camera_shake.emit(5.0 if heavy else 3.0)
		Events.camera_nudge.emit(aim_dir * (7.0 if heavy else 4.0))
		Effects.impact(global_position + aim_dir * (rng * 0.7), aim_dir, killed_any, not unarmed and w.data.sfx_hit == "hit_blade")
		InputSetup.vibrate(0.4, 0.4, 0.1)
		Events.noise.emit(global_position, 90.0, &"voice", self)
		if not unarmed and w.durability > 0:
			w.durability -= 1
			if persona and persona.melee_wear_mult > 1.0 and w.durability > 0 and randf() < persona.melee_wear_mult - 1.0:
				w.durability -= 1
			if w.durability == 0:
				_break_weapon(w)

func _break_weapon(w: WeaponInstance) -> void:
	var into := w.data.breaks_into
	Audio.play_at("bottle_break" if w.data.id == &"bottle" else "door_break", global_position, -4.0)
	Effects.debris(visual.hand_global(), aim_dir)
	if w.data.id == &"bottle":
		Effects.glass(visual.hand_global(), aim_dir)
	Events.hint.emit(tr("%s broke") % tr(w.data.display_name), 0.8)
	if into != &"" and DB.weapon(into):
		slots[slot] = WeaponInstance.create(DB.weapon(into))
	else:
		slots[slot] = null
	_refresh_weapon()

func _has_los(a: Vector2, b: Vector2, target: Object = null, mask := Layers.WORLD | Layers.PROP) -> bool:
	var space := get_world_2d().direct_space_state
	var ex: Array[RID] = [get_rid()]
	if target is CollisionObject2D:
		ex.append((target as CollisionObject2D).get_rid())
	var q := PhysicsRayQueryParameters2D.create(a, b, mask, ex)
	return space.intersect_ray(q).is_empty()

# ------------------------------------------------------- aim forgiveness
## The crosshair is a direction, not a pixel test. These stay deliberately
## small: you still have to point the right way - nothing on screen is
## auto-targeted, nothing is locked.
const MELEE_REACH_BONUS := 5.0     ## px beyond the weapon's own reach
const MELEE_ARC_BONUS := 40.0      ## degrees added to the swing arc
const MELEE_TURN_EXTRA := 30.0     ## how far off-aim a swing will turn into a target
const GUN_PAD_PX := 12.0           ## a shot "counts" within this many px of a body
const GUN_MIN_DEG := 2.5
const GUN_MAX_DEG := 11.0
const GUN_RANGE := 420.0

## Nearest enemy the swing could reasonably mean: in reach and roughly in
## front. The swing (and lunge) turns into it.
func _turn_into_target(reach: float, half_arc: float) -> void:
	if lock_target and is_instance_valid(lock_target):
		return
	var best: Node2D = null
	var best_score := INF
	var lim := deg_to_rad(half_arc + MELEE_TURN_EXTRA)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to: Vector2 = (e as Node2D).global_position - global_position
		var r: float = e.get("hit_radius") if e.get("hit_radius") != null else 6.0
		if to.length() - r > reach + MELEE_REACH_BONUS + 6.0:
			continue
		var a := absf(angle_difference(aim_dir.angle(), to.angle()))
		if a > lim:
			continue
		if not _has_los(global_position, (e as Node2D).global_position, e, Layers.WORLD | Layers.DOOR):
			continue
		var sc := a * 40.0 + to.length()
		if sc < best_score:
			best_score = sc
			best = e
	if best:
		aim_dir = aim_dir.slerp((best.global_position - global_position).normalized(), 0.85).normalized()
		visual.set_aim(aim_dir.angle())

## A shot fired close to someone goes to them: the tolerance is a few px
## of body width at any distance (a wider angle up close, a hair at range).
func _forgiving_shot(dir: Vector2) -> Vector2:
	if lock_target and is_instance_valid(lock_target):
		return dir
	var best: Node2D = null
	var best_k := 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to: Vector2 = (e as Node2D).global_position - global_position
		var d := to.length()
		if d < 4.0 or d > GUN_RANGE:
			continue
		var r: float = e.get("hit_radius") if e.get("hit_radius") != null else 6.0
		var tol := clampf(atan2(r + GUN_PAD_PX, d), deg_to_rad(GUN_MIN_DEG), deg_to_rad(GUN_MAX_DEG))
		var k := absf(angle_difference(dir.angle(), to.angle())) / tol
		if k >= best_k:
			continue
		if not _has_los(global_position, (e as Node2D).global_position, e, Layers.WORLD | Layers.PROP | Layers.DOOR):
			continue
		best_k = k
		best = e
	if best == null:
		return dir
	var tv: Vector2 = best.velocity if best is CharacterBody2D else Vector2.ZERO
	return ((best.global_position + tv * 0.04) - global_position).normalized()

# ---------------------------------------------------------------- throwing
func _throw_current() -> void:
	var w := current()
	if w == null:
		return
	var parent: Node = level.pickup_root() if level and level.has_method("pickup_root") else get_parent()
	var spd := w.data.throw_speed
	if w.dual:
		# toss the off-hand gun (with what's left in it), keep the other
		var off := WeaponInstance.create(w.data, false)
		off.ammo = w.ammo2
		w.dual = false
		w.ammo2 = 0
		WeaponPickup.spawn(parent, off, visual.muzzle_global(true), aim_dir * spd + velocity * 0.3, self)
		Audio.play_at("throw", global_position)
		visual.punch()
		_reload_t = 0.0
		visual.cancel_reload()
		_refresh_weapon()
		return
	WeaponPickup.spawn(parent, w, visual.hand_global(), aim_dir * spd + velocity * 0.3, self)
	slots[slot] = null
	Audio.play_at("throw", global_position)
	visual.punch()
	_reload_t = 0.0
	visual.cancel_reload()
	# auto-draw the holstered weapon
	var other := 1 - slot
	if slots[other] != null:
		slot = other
	_refresh_weapon()

# ---------------------------------------------------------------- interact
func _interact() -> void:
	var it := _nearest_interactable()
	var pk := WeaponPickup.nearest(global_position, get_tree())
	if it and (pk == null or it.global_position.distance_to(global_position) <= pk.global_position.distance_to(global_position) + 4.0):
		it.interact(self)
		return
	if pk:
		_pick_up(pk)
		return
	if current() and current().data.is_firearm():
		_start_reload()

## Picking up a second copy of a dual-wieldable gun you're holding pairs it.
func can_dual_with(pk: WeaponPickup) -> bool:
	var cur := current()
	return pk != null and cur != null and not cur.dual and pk.weapon and pk.weapon.data == cur.data and cur.data.dual_wieldable

func _pick_up(pk: WeaponPickup) -> void:
	if level and level.get("rules") and not level.rules.allows_pickup(pk.weapon):
		Events.hint.emit(tr("NOT IN THIS MODE"), 1.0)
		return
	if persona and persona.no_guns and pk.weapon and pk.weapon.data.is_firearm():
		Events.hint.emit(tr("THE SAINT DOESN'T TOUCH GUNS"), 1.2)
		return
	if persona and persona.remix and pk.weapon and not pk.has_meta("remixed"):
		# the fool: whatever was on the floor, something else is in her hands
		var pool: Array = DB.all_weapons().filter(func(wd): return wd.id != &"hotshot" and wd.id != &"whisper" and not (persona.no_guns and wd.is_firearm()))
		if not pool.is_empty():
			pk.weapon = WeaponInstance.create(pool[randi() % pool.size()])
			pk.set_meta("remixed", true)
	var new_w: WeaponInstance = pk.weapon
	Events.tutorial.emit("weapon")
	var parent: Node = level.pickup_root() if level and level.has_method("pickup_root") else get_parent()
	var cur := current()
	if can_dual_with(pk):
		cur.dual = true
		cur.ammo2 = mini(new_w.ammo, mag_size(cur))
		cur.reserve += new_w.reserve
		pk.queue_free()
		_reload_t = 0.0
		visual.cancel_reload()
		_dual_left = true
		Audio.play_at("pickup", global_position)
		Audio.play_at("reload", global_position, -8.0, 0.1)
		Events.hint.emit(tr("DUAL %s") % tr(cur.data.display_name).to_upper(), 1.2)
		_refresh_weapon()
		return
	if cur != null:
		var other := 1 - slot
		if slots[other] == null:
			slots[other] = cur
		else:
			WeaponPickup.spawn(parent, cur, global_position + aim_dir.orthogonal() * 6.0, aim_dir.orthogonal() * 40.0)
	slots[slot] = new_w
	_apply_ext_mag(new_w)
	pk.queue_free()
	_reload_t = 0.0
	visual.cancel_reload()
	Audio.play_at("pickup", global_position)
	Events.weapon_picked_up.emit(new_w.data.id)
	_refresh_weapon()

func _swap() -> void:
	if slots[1 - slot] == null and slots[slot] == null:
		return
	slot = 1 - slot
	_reload_t = 0.0
	visual.cancel_reload()
	Audio.play("pickup", -10.0, 1.3)
	_refresh_weapon()

func _nearest_interactable() -> Node2D:
	var best: Node2D = null
	var bd := 22.0
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node2D) or not n.has_method("interact"):
			continue
		if n.has_method("can_interact") and not n.can_interact(self):
			continue
		var d := (n as Node2D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = n
	return best

# ---------------------------------------------------------------- execute / kick
func _find_downed() -> Enemy:
	var best: Enemy = null
	var bd := EXEC_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.has_method("is_downed") and e.is_downed():
			var d := (e as Node2D).global_position.distance_to(global_position)
			if d < bd:
				bd = d
				best = e
	return best

## Unaware enemy (or dog) you can grab: from behind, in the dark, or asleep.
func _find_takedown() -> Enemy:
	var best: Enemy = null
	var bd := TAKEDOWN_RANGE
	var dark: bool = level != null and level.has_method("darkness_at") and level.darkness_at(global_position) == 2
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("can_be_taken_down") or not e.can_be_taken_down():
			continue
		var en := e as Enemy
		var d := en.global_position.distance_to(global_position)
		if d >= bd or not _has_los(global_position, en.global_position, en):
			continue
		var from_me := global_position - en.global_position
		var behind := absf(angle_difference(en.facing.angle(), from_me.angle())) > deg_to_rad(en.data.view_angle_deg * 0.5)
		var asleep: bool = en.has_method("is_asleep") and en.is_asleep()
		if behind or dark or asleep:
			bd = d
			best = en
	return best

func _execute_or_kick() -> void:
	var target := _find_downed()
	if target:
		_begin_execution(target)
		return
	var td := _find_takedown()
	if td:
		_begin_execution(td, true)
		return
	if _kick_cd > 0.0:
		return
	_kick_cd = 0.4
	visual.kick_leg()
	velocity += aim_dir * 40.0
	# doors first: the nearest door whose leaf is in reach and in front
	var best_door: Node2D = null
	var best_d := INF
	for d in get_tree().get_nodes_in_group("door"):
		if not (d is Door) or not d.has_method("kick"):
			continue
		var dd: float = (d as Door).hit_point(global_position).distance_to(global_position)
		if dd < KICK_RANGE + 6.0 and dd < best_d:
			best_d = dd
			best_door = d
	if best_door and best_door.kick(global_position, aim_dir):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var to: Vector2 = (e as Node2D).global_position - global_position
		if to.length() < KICK_RANGE and absf(angle_difference(aim_dir.angle(), to.angle())) < 1.2:
			var info := DamageInfo.make(DamageInfo.Type.PUNCH, self, e.global_position, to, &"kick", &"punch")
			info.lethal = false
			info.knockback = 260.0
			if str(e.take_damage(info)) != "blocked":
				Audio.play_at("punch", global_position)
				Events.hit_stop.emit(0.04)
			return
	Audio.play_at("swing", global_position, -10.0)

func _begin_execution(target: Enemy, standing := false) -> void:
	_exec_target = target
	_exec_standing = standing
	var w := current()
	var is_dog := target is Dog
	_exec_move = Executions.pick(w.data if w else null, w.ammo if w else 0, standing, is_dog)
	target.begin_execution(self)
	_exec_hits = int(_exec_move.hits)
	_locked_t = float(_exec_move.time)
	if persona and persona.id == &"angel":
		_locked_t *= 0.4
	_exec_total = _locked_t
	_exec_elapsed = 0.0
	_exec_done = 0
	aim_dir = (target.global_position - global_position).normalized()
	global_position = target.global_position - aim_dir * (8.0 if standing else 9.0)
	visual.set_aim(aim_dir.angle())
	Events.camera_punch.emit(1.18, 0.45)
	Effects.popup(tr(str(_exec_move.name)), target.global_position + Vector2(0, -8), UIStyle.HOT)
	if standing:
		Audio.play_at("punch", global_position, -14.0)

func _process_execution(pd: float) -> void:
	if _exec_target == null or not is_instance_valid(_exec_target):
		_locked_t = 0.0
		return
	_exec_elapsed += pd
	var w := current()
	var due := 0
	for i in _exec_hits:
		if _exec_elapsed >= (float(i) + 0.5) / float(_exec_hits) * _exec_total:
			due += 1
	var tpos := _exec_target.global_position
	while _exec_done < due:
		_exec_done += 1
		var last := _exec_done >= _exec_hits
		var anim := str(_exec_move.get("anim", "punch"))
		var blood := float(_exec_move.get("blood", 1.0))
		var noise := float(_exec_move.get("noise", 0.0))
		match anim:
			"swing":
				visual.swing(true)
				Audio.play_at(w.data.sfx_hit if w and w.data.is_melee() else "hit_blunt", global_position)
			"stab":
				visual.swing(false, true)
				Audio.play_at("hit_blade", global_position, -2.0)
			"stomp":
				visual.punch()
				visual.kick_recoil(-3.0)
				Audio.play_at("hit_blunt", global_position)
				Events.camera_shake.emit(4.0)
			"shot":
				if w and w.data.is_firearm() and w.ammo > 0:
					w.ammo -= 1
					var silenced := upgrades.has(&"silencer")
					Effects.muzzle(visual.muzzle_global(), aim_dir, w.data.muzzle_color, false)
					Audio.play_at("suppressed" if silenced else w.data.sfx_fire, global_position)
					noise = gun_noise(w)
					Events.camera_shake.emit(w.data.camera_kick)
					_emit_weapon()
			"grab":
				visual.punch()
				Audio.play_at("punch", global_position, -10.0)
			_:
				if w == null and not _exec_standing:
					# astride them: fists coming down, the last one wound up
					visual.set_mount(true)
					visual.ground_punch(last)
					Audio.play_at("punch", global_position, 2.0 if last else 0.0, 0.1)
					Audio.play_at("hit_flesh", tpos, -4.0, 0.15)
					Effects.blood(tpos, aim_dir.rotated(randf_range(-1.2, 1.2)), last)
				else:
					visual.punch()
					Audio.play_at("punch", global_position)
		if blood > 0.0:
			Gore.splatter(tpos, aim_dir.rotated(randf_range(-0.6, 0.6)), blood * (1.3 if last else 0.8))
			Audio.play_at("gore", tpos, -6.0 if not last else -2.0, 0.15)
		if last and str(_exec_move.get("finisher", "")) == "neck":
			Audio.play_at("neck_snap", tpos, -2.0)
		if noise > 0.0:
			Events.noise.emit(global_position, noise, &"gunshot" if anim == "shot" else &"scuffle", self)
		Events.hit_stop.emit(0.11 if last else 0.05)
		Events.camera_punch.emit(1.08 if last else 1.025, 0.12 if last else 0.055)
		if not last or anim != "grab":
			Events.camera_shake.emit(3.5 if last else 2.0)
		InputSetup.vibrate(0.6, 0.6 if last else 0.3, 0.12)
	if _locked_t <= 0.0:
		visual.set_mount(false)
		var wid: StringName = w.data.id if w else &"fists"
		var t := _exec_target
		_exec_target = null
		Events.camera_nudge.emit(aim_dir * 6.0)
		t.finish_execution(self, wid, str(_exec_move.get("finisher", "")))
		Events.execution_performed.emit(t)
		if _exec_standing:
			Score.add_bonus("TAKEDOWN", 400, global_position)

# ---------------------------------------------------------------- equipment
func _use_equipment() -> void:
	if bones > 0:
		bones -= 1
		var bp: Node = level.pickup_root() if level and level.has_method("pickup_root") else get_parent()
		var mb := MeatBone.new()
		mb.global_position = visual.hand_global()
		mb.velocity = aim_dir * 300.0 + velocity * 0.3
		bp.add_child(mb)
		Audio.play_at("throw", global_position)
		return
	if equipment_left <= 0:
		Events.hint.emit("NO FLARES LEFT", 0.8)
		return
	equipment_left -= 1
	var parent: Node = level.pickup_root() if level and level.has_method("pickup_root") else get_parent()
	var f := Flare.new()
	f.global_position = visual.hand_global()
	f.velocity = aim_dir * 330.0 + velocity * 0.3
	parent.add_child(f)
	Audio.play_at("throw", global_position)
	Events.hint.emit(tr("FLARE  (%d left)") % equipment_left, 0.8)

# =============================================================== damage
func take_damage(info: DamageInfo) -> String:
	if not alive:
		return "pass"
	if noclip or god_mode:
		visual.flash()
		return "absorbed"
	if _iframes > 0.0 and info.type != DamageInfo.Type.EXPLOSIVE:
		return "pass"   # dodged through it
	if persona and persona.first_hit_kills and info.lethal:
		_die(info)   # the crown: no vest, no second chance
		return "killed"
	if not info.lethal and info.type != DamageInfo.Type.EXPLOSIVE:
		_stagger = 0.35
		velocity += info.dir * 160.0
		visual.flash()
		Score.on_player_hurt()
		Events.camera_shake.emit(3.0)
		return "hurt"
	if armor_hits > 0 and info.type != DamageInfo.Type.EXPLOSIVE:
		armor_hits -= 1
		_iframes = 0.45
		visual.flash(0.25)
		velocity += info.dir * 140.0
		_stagger = 0.25
		Effects.sparks(global_position + info.dir * -3.0, -info.dir)
		Audio.play_at("armor_break", global_position)
		Events.camera_shake.emit(6.0)
		Events.hit_stop.emit(0.08)
		InputSetup.vibrate(0.8, 0.8, 0.2)
		Events.hint.emit("VEST TOOK IT", 1.2)
		if _vest:
			_vest.queue_free()
			_vest = null
		return "absorbed"
	if guard_hits > 0 and info.type != DamageInfo.Type.EXPLOSIVE:
		guard_hits -= 1
		_guard_regen_t = float(Difficulty.value("player_guard_regen"))
		_iframes = 0.6
		_stagger = 0.3
		velocity += info.dir * 150.0
		visual.flash(0.3)
		Score.on_player_hurt()
		Audio.play_at("hit_blunt", global_position)
		Events.camera_shake.emit(6.0)
		Events.hit_stop.emit(0.07)
		PostFX.flash(Color(0.8, 0.1, 0.15, 0.6), 0.2)
		InputSetup.vibrate(0.7, 0.7, 0.2)
		Events.hint.emit("HIT — GET TO COVER", 1.2)
		return "absorbed"
	if extra_hits > 0:
		extra_hits -= 1
		visual.flash(0.2)
		Score.on_player_hurt()
		Events.camera_shake.emit(5.0)
		Audio.play_at("hit_blunt", global_position)
		return "absorbed"
	_die(info)
	return "killed"

func _die(info: DamageInfo) -> void:
	alive = false
	ability.force_end()
	collision_layer = 0
	collision_mask = 0
	visual.visible = false
	var corpse := Corpse.new()
	corpse.setup(data.palette, info.dir, true)
	corpse.global_position = global_position
	get_parent().add_child(corpse)
	Effects.blood(global_position, info.dir, true)
	Audio.play_at("death", global_position)
	Audio.play("heartbeat", -4.0)
	Events.camera_shake.emit(8.0)
	Events.camera_punch.emit(1.25, 0.8)
	InputSetup.vibrate(1.0, 1.0, 0.3)
	PostFX.flash(Color(0.8, 0.0, 0.1), 0.4)
	PostFX.vhs_glitch(1.0)
	var d := {"type": info.type, "weapon": info.weapon_id, "pos": global_position}
	died.emit(d)
	Events.player_died.emit(d)

# =============================================================== helpers
func _refresh_weapon() -> void:
	var w := current()
	visual.set_weapon(w.data if w else null, w != null and w.dual)
	_emit_weapon()

func _emit_weapon() -> void:
	var w := current()
	if w:
		Events.weapon_changed.emit(w.data.id, w.ammo if w.data.is_firearm() else w.durability, w.reserve)
	else:
		Events.weapon_changed.emit(&"", 0, 0)

func _update_prompt() -> void:
	prompt = ""
	if _find_downed():
		prompt = tr("[%s] EXECUTE") % InputSetup.binding_text("execute", InputSetup.using_gamepad)
		return
	var td := _find_takedown()
	if td:
		prompt = tr("[%s] TAKEDOWN") % InputSetup.binding_text("execute", InputSetup.using_gamepad)
		return
	var it := _nearest_interactable()
	if it and it.has_method("get_prompt"):
		prompt = "[%s] %s" % [InputSetup.binding_text("interact", InputSetup.using_gamepad), tr(it.get_prompt())]
		return
	var pk := WeaponPickup.nearest(global_position, get_tree())
	if pk:
		var what := tr(pk.weapon.data.display_name).to_upper()
		if can_dual_with(pk):
			what = tr("DUAL WIELD  ") + what
		prompt = "[%s] %s" % [InputSetup.binding_text("interact", InputSetup.using_gamepad), what]

func give_weapon(id: StringName) -> void:
	var d := DB.weapon(id)
	if d == null:
		return
	slots[slot] = WeaponInstance.create(d)
	_refresh_weapon()

func weapon_state() -> Array:
	## for checkpoints: [[id, ammo, reserve, durability] or null, ...]
	var out := []
	for w in slots:
		out.append([w.data.id, w.ammo, w.reserve, w.durability, w.dual, w.ammo2] if w else null)
	return out

func restore_weapons(state: Array) -> void:
	for i in mini(state.size(), 2):
		var s: Variant = state[i]
		if s is Array and DB.weapon(StringName(s[0])):
			var w := WeaponInstance.create(DB.weapon(StringName(s[0])))
			w.ammo = int(s[1])
			w.reserve = int(s[2])
			w.durability = int(s[3])
			if s.size() >= 6 and w.data.dual_wieldable:
				w.dual = bool(s[4])
				w.ammo2 = int(s[5])
			slots[i] = w
	_refresh_weapon()

# =============================================================== upgrades
func add_upgrade(id: StringName, quiet := false) -> void:
	if id == &"" or upgrades.has(id):
		return
	upgrades[id] = true
	match id:
		&"armor":
			armor_hits = 1
			_ensure_vest()
		&"laser":
			if _laser == null:
				_laser = Upgrades.LaserBeam.new()
				_laser.player = self
				add_child(_laser)
		&"ext_mag":
			for w in slots:
				if w:
					_apply_ext_mag(w)
			_emit_weapon()
	if not quiet:
		var d := Upgrades.def(id)
		Audio.play("upgrade")
		Events.upgrade_collected.emit(id)
		if level and level.get("hud"):
			level.hud.show_upgrade(id)

func _ensure_vest() -> void:
	if _vest == null and armor_hits > 0:
		_vest = Upgrades.Vest.new()
		visual.rig.add_child(_vest)

func _apply_ext_mag(w: WeaponInstance) -> void:
	if w == null or not upgrades.has(&"ext_mag") or not w.data.is_firearm() or w.has_meta("ext"):
		return
	w.set_meta("ext", true)
	w.ammo = mini(mag_size(w), int(ceil(w.ammo * 1.5)))

func upgrade_state() -> Dictionary:
	return {"ids": upgrades.keys(), "armor": armor_hits}

func restore_upgrades(st: Dictionary) -> void:
	for id in st.get("ids", []):
		add_upgrade(StringName(id), true)
	armor_hits = int(st.get("armor", armor_hits))
	if armor_hits <= 0 and _vest:
		_vest.queue_free()
		_vest = null

func _on_any_kill(_e: Node, info: Dictionary) -> void:
	if not alive or not upgrades.has(&"adrenaline"):
		return
	_dash_cd = 0.0
	_adrenaline_t = 1.6
	ability.add_charge(0.08)
	if info.has("pos"):
		Effects.popup("ADRENALINE", global_position + Vector2(0, -10), Color("ff8a20"))


## The stamina indicator: a thin arc round her feet, only there while
## stamina isn't full. White while it's fine, amber when low, red and
## shaking when a roll was refused or she's winded; fades once it's back.
class StaminaRing extends Node2D:
	var player: Node
	var _a := 0.0
	func _ready() -> void:
		z_index = 30
		z_as_relative = false
	func _process(delta: float) -> void:
		var frac: float = player.stamina / player.STAMINA_MAX
		var want := 0.0 if frac >= 0.999 and player._stamina_denied <= 0.0 else 1.0
		_a = move_toward(_a, want, delta * (6.0 if want > _a else 2.0))
		queue_redraw()
	func _draw() -> void:
		if _a <= 0.01:
			return
		var frac: float = clampf(player.stamina / player.STAMINA_MAX, 0.0, 1.0)
		var denied: float = player._stamina_denied
		var col := Color(1, 1, 1)
		if player._winded or frac < 0.3:
			col = Color(1.0, 0.65, 0.2)
		if denied > 0.0 or player._winded:
			col = col.lerp(UIStyle.HOT, maxf(denied, 0.6 if player._winded else 0.0))
		var shake := Vector2(sin(Time.get_ticks_msec() * 0.08) * 1.2 * denied, 0)
		# five short slanted dashes in a shallow arc under her feet: quiet
		# (half-see-through) while it's fine, lit neon when it runs low
		var n := 5
		var r := 10.0
		var span := PI * 0.55
		var start := PI * 0.5 - span * 0.5
		var low: bool = frac < 0.3 or player._winded or denied > 0.0
		var alpha := _a * (0.9 if low else 0.45)
		var roll_seg: int = int(ceil(float(player.ROLL_COST) / player.STAMINA_MAX * n))
		for i in n:
			var a0 := start + span * (float(i) + 0.15) / n
			var a1 := start + span * (float(i) + 0.85) / n
			var fill := clampf(frac * n - i, 0.0, 1.0)
			var p0 := Vector2.from_angle(a0) * r + shake
			var p1 := Vector2.from_angle(a1) * r + shake
			draw_line(p0, p1, Color(0, 0, 0, 0.3 * alpha), 2.6, true)
			if fill > 0.0:
				var c2: Color = col if i >= roll_seg or frac >= float(player.ROLL_COST) / player.STAMINA_MAX else Color(1.0, 0.65, 0.2)
				if low:
					draw_line(p0, p0.lerp(p1, fill), Color(c2, 0.25 * alpha), 4.0, true)   # the glow
				draw_line(p0, p0.lerp(p1, fill), Color(c2, alpha), 1.3, true)
