class_name Dog
extends Enemy
## Guard dog. Sleeps, sniffs around, patrols with its handlers. Smells you
## if you move fast nearby (sneak past, or kill it while it sleeps), barks to
## alert every human in earshot, then sprints and lunges. The lunge has a
## crouch tell: hit it during the crouch to counter. Drawn procedurally in a
## cel-shaded style: trot/gallop gait, independent head that tracks what the
## dog is looking at, tail, ears, hackles, panting, curled sleep, and eyes
## that burn red once it has spotted you.

## "saddle" is the black back patch of a German Shepherd; "mask" its dark
## muzzle. Breeds without them just reuse the base colour.
const DOG_COLORS := {
	# authored darker than they read: levels brighten actors for readability
	"shepherd":   {"base": Color("7e4a20"), "shade": Color("4e2c12"), "light": Color("a4692e"), "tan": Color("b98648"),
		"saddle": Color("120c0a"), "saddle_hi": Color("2e221c"), "mask": Color("0f0a08"), "collar": Color("b01822")},
	"doberman":   {"base": Color("2c211b"), "shade": Color("15100d"), "light": Color("54423a"), "tan": Color("a8602c"), "collar": Color("c81e28")},
	"hellhound":  {"base": Color("3a0808"), "shade": Color("1a0404"), "light": Color("6a1410"), "tan": Color("ff5a1a"), "saddle": Color("120404"), "saddle_hi": Color("5a1008"), "mask": Color("0a0202"), "collar": Color("ffd23f")},
	"rottweiler": {"base": Color("1c1612"), "shade": Color("0e0a08"), "light": Color("33271f"), "tan": Color("8a4a22"), "collar": Color("d4a020")},
}
const BITE_REACH := 15.0
const DRAW_SCALE := 0.62     ## art is authored ~1.6x; a dog should be about a person's length
const LUNGE_SPEED := 255.0
const LUNGE_TIME := 0.2

var sleeping := false
var sniff_mode := false
var colors: Dictionary = {}
var _t := 0.0
var _gait := 0.0
var _sniff_t := 0.0
var _sniff_cd := 2.0
var _bark_t := 0.0
var _bark_anim := 0.0
var _lunge_t := -1.0
var _lunge_dir := Vector2.RIGHT
var _bit := false
var _recover_t := 0.0
var _wander_goal := Vector2.ZERO
var _wander_t := 0.0
var _growl_t := 0.0
var _speed_now := 0.0
var _head_rel := 0.0         ## head angle relative to the body (radians)
var _pant := 0.0             ## out of breath after running: tongue out, sides heave
var _ear_twitch := 0.0
var _ear_t := 3.0
var _eye_glow := 0.0         ## 0..1, red eyes once it has spotted you
var _spot_flash := 0.0
var _eye_light: PointLight2D

func setup(p_data: EnemyData, p_level: Node, p_facing: Vector2) -> void:
	super(p_data, p_level, p_facing)
	visual.visible = false
	light_mask = 2   # same light layer as the other characters, or room lights blow the painting out
	hit_radius = 5.5
	colors = DOG_COLORS.get(data.palette, DOG_COLORS["shepherd"])
	_t = randf() * 10.0
	_wander_goal = global_position
	# a small red light so the eyes read in pitch-dark rooms too
	_eye_light = PointLight2D.new()
	_eye_light.texture = SpriteLib.light_texture(64)
	_eye_light.texture_scale = 0.35
	_eye_light.color = Color(1.0, 0.1, 0.08)
	_eye_light.energy = 0.0
	_eye_light.range_item_cull_mask = 1 | 2
	add_child(_eye_light)

func is_asleep() -> bool:
	return sleeping and is_alive() and state == State.IDLE

func can_fix_lights() -> bool:
	return false

func _wake(pos: Vector2) -> void:
	if not sleeping:
		return
	sleeping = false
	_show_icon("!")
	_last_known = pos
	facing = (pos - global_position).normalized() if pos.distance_to(global_position) > 1.0 else facing
	Audio.play_at("growl", global_position, -4.0)

# ======================================================================= perception
func _perceive() -> void:
	var p := _player()
	_sees_player = false
	if p == null or not p.alive or state == State.DOWNED or _held or p.respawn_grace > 0.0:
		return
	if p.persona and p.persona.dogs_ignore and state != State.COMBAT:
		return   # the dog mask: one of the pack
	var to := p.global_position - global_position
	var dist := to.length()
	if sleeping:
		# only something right next to it wakes it (or noise, see _on_noise)
		if dist < 14.0 and not p.is_quiet():
			_wake(p.global_position)
		return
	var aware := is_aware()
	var dark: bool = level != null and level.has_method("darkness_at") and level.darkness_at(p.global_position) >= 1
	var view := data.view_distance * (0.5 if dark else 1.0)
	var in_cone := absf(angle_difference(facing.angle(), to.angle())) < deg_to_rad(data.view_angle_deg * 0.5)
	var seen := dist < view * (1.4 if aware else 1.0) and (in_cone or aware) and _clear_line(global_position, p.global_position)
	# the nose: works in the dark and behind its back, but sneaking beats it
	var smell_r := 22.0 if p.is_quiet() else 64.0
	var smelled := dist < smell_r and _clear_line(global_position, p.global_position)
	if seen or smelled:
		_sees_player = true
		_last_known = p.global_position
		if aware:
			if state == State.SEARCH:
				_enter_combat()
		else:
			_suspicion += 0.1 * (4.0 if dist < 70.0 else 1.8)
			if _suspicion >= 0.25 and state in [State.IDLE, State.PATROL]:
				_set_state(State.SUSPICIOUS)
				_show_icon("?")
				_growl_t = 0.8
				Audio.play_at("growl", global_position, -8.0)
			if _suspicion >= 0.5 or dist < 36.0:
				_enter_combat()
	else:
		_suspicion = maxf(0.0, _suspicion - 0.03)
	# a dead body sets it off howling
	if not aware and Engine.get_physics_frames() % 4 == 0:
		for c in get_tree().get_nodes_in_group("corpses"):
			var corpse := c as Corpse
			if corpse == null or corpse.discovered or corpse.is_player:
				continue
			if corpse.global_position.distance_to(global_position) < 90.0 and _clear_line(global_position, corpse.global_position):
				corpse.discovered = true
				_last_known = corpse.global_position
				_goal = corpse.global_position
				_show_icon("!")
				_bark()
				_set_state(State.INVESTIGATE)
				break

func _on_noise(pos: Vector2, radius: float, kind: StringName, source: Node) -> void:
	if not is_alive() or state == State.DOWNED or source == self or _held or _food != null:
		return
	if source is Player and (source as Player).respawn_grace > 0.0:
		return
	if sleeping:
		var d := global_position.distance_to(pos)
		var r := radius * data.hearing_mult
		if kind in [&"step", &"scuffle", &"voice"]:
			r *= 0.35
		if d > r:
			return
		_wake(pos)
	super(pos, radius, kind, source)

func _enter_combat() -> void:
	if _held or state in [State.COMBAT, State.FLANK, State.RETREAT, State.DOWNED]:
		return
	sleeping = false
	super()
	_bark()
	_spot_flash = 1.0   # the "I see you" moment: eyes flare

func _bark() -> void:
	_bark_anim = 0.35
	_bark_t = randf_range(1.0, 1.8)
	Audio.play_at("bark", global_position, -1.0, 0.12)
	Events.noise.emit(global_position, data.alert_others_radius, &"voice", self)

# ======================================================================= loop
var _food: MeatBone = null
var _chew_t := 0.0

## A meat bone landed nearby: go and eat it (unless already mid-fight with
## her in its teeth, or down, or leashed). Returns whether it took the bait.
func lure(food: MeatBone) -> bool:
	if not is_alive() or state in [State.DOWNED, State.STUNNED] or _held or _lunge_t >= 0.0:
		return false
	sleeping = false
	_food = food
	_set_state(State.IDLE)
	_sees_player = false
	return true

func is_eating(food: MeatBone) -> bool:
	return _food == food

func stop_eating() -> void:
	_food = null
	_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)

func _eat(delta: float) -> Vector2:
	var to := _food.global_position - global_position
	if to.length() > 9.0:
		return _go_to(_food.global_position, data.walk_speed * 2.2)
	facing = facing.slerp(to.normalized(), minf(1.0, delta * 8.0))
	_chew_t -= delta
	if _chew_t <= 0.0:
		_chew_t = randf_range(0.5, 1.1)
		_bark_anim = 0.12   # head dips into it
		Audio.play_at("splat", global_position, -24.0, 0.3)
		if randf() < 0.25:
			Audio.play_at("growl", global_position, -20.0, 0.2)
	return Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	if _food != null and not is_instance_valid(_food):
		stop_eating()
	if _food != null and state != State.DOWNED:
		# dinner: nothing else in the world exists
		_t += delta
		_state_t += delta
		_bark_anim = maxf(0.0, _bark_anim - delta)
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		_move_vel = _move_vel.move_toward(_eat(delta) + _separation() * 0.3, 1200.0 * delta)
		velocity = _move_vel + _knock
		move_and_slide()
		_speed_now = get_real_velocity().length()
		if _move_vel.length() > 5.0:
			facing = facing.slerp(_move_vel.normalized(), minf(1.0, delta * 6.5))
		_update_head(delta)
		_update_eyes(delta)
		_gait += delta * _speed_now * 0.16
		queue_redraw()
		return
	_t += delta
	_state_t += delta
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_alert_icon = maxf(0.0, _alert_icon - delta)
	_bark_anim = maxf(0.0, _bark_anim - delta)
	_growl_t = maxf(0.0, _growl_t - delta)
	_dark_confused = maxf(0.0, _dark_confused - delta)
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
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
			if not _held and _stun_t <= 0.0:
				_set_state(State.COMBAT if _sees_player else State.SEARCH)
		State.IDLE:
			if not sleeping:
				desired = _sniff_wander(delta, _home, 48.0 if sniff_mode else 0.0)
		State.PATROL:
			if _sniff_t > 0.0:
				_sniff_t -= delta
			else:
				var before := _patrol_i
				desired = _patrol(delta)
				if _patrol_i != before:
					_sniff_t = randf_range(0.8, 2.0)   # stop and sniff at every waypoint
		State.SUSPICIOUS:
			facing = facing.slerp((_last_known - global_position).normalized(), minf(1.0, delta * 6.0))
			if _state_t > 0.8:
				_set_state(State.INVESTIGATE)
				_goal = _last_known
		State.INVESTIGATE:
			desired = _go_to(_goal, data.walk_speed * 2.0)
			if global_position.distance_to(_goal) < 12.0 or _path_done():
				_set_state(State.SEARCH)
		State.SEARCH:
			desired = _sniff_wander(delta, _last_known, 56.0) * 1.4
			if _state_t > 6.0:
				_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)
		State.COMBAT, State.FLANK, State.RETREAT:
			desired = _dog_combat(delta)
		State.PANIC, State.FLEE:
			desired = _flee(delta)
	if state == State.DOWNED or state == State.STUNNED:
		desired = Vector2.ZERO
	if _lunge_t >= 0.0:
		velocity = _lunge_dir * LUNGE_SPEED * (1.0 - _lunge_t / LUNGE_TIME * 0.5) + _knock
		_move_vel = velocity - _knock
	else:
		# dogs accelerate hard but still ease into turns and stops
		_move_vel = _move_vel.move_toward(desired + _separation(), 1500.0 * delta)
		velocity = _move_vel + _knock
	move_and_slide()
	_speed_now = get_real_velocity().length()
	if _move_vel.length() > 5.0 and state != State.DOWNED:
		# the body turns a bit slower than the head: turns curve
		facing = facing.slerp(_move_vel.normalized(), minf(1.0, delta * 6.5))
	_update_head(delta)
	_update_eyes(delta)
	_pant = clampf(_pant + (delta * 0.35 if _speed_now > 120.0 else -delta * 0.12), 0.0, 1.0)
	_ear_t -= delta
	if _ear_t <= 0.0:
		_ear_t = randf_range(2.5, 6.0)
		_ear_twitch = 0.25
	_ear_twitch = maxf(0.0, _ear_twitch - delta)
	_gait += delta * _speed_now * 0.16
	if _speed_now > 6.0 and Engine.get_physics_frames() % 20 == 0 and _speed_now > 120.0:
		Audio.play_at("step%d" % (randi() % 3), global_position, -22.0, 0.3)
	queue_redraw()

## On the leash: the handler drives where the dog goes, but it still
## walks for real - trotting legs, bobbing, head turning, panting.
func heel_follow(delta: float, heel: Vector2, face: Vector2) -> void:
	_t += delta
	var off := heel - global_position
	var want := off * 7.0
	if want.length() > 150.0:
		want = want.normalized() * 150.0
	if off.length() < 1.5:
		want = Vector2.ZERO
	_move_vel = _move_vel.move_toward(want, 900.0 * delta)
	velocity = _move_vel
	move_and_slide()
	var travelled := get_real_velocity()
	_speed_now = travelled.length()
	var dir := travelled.normalized() if _speed_now > 8.0 else face
	facing = facing.slerp(dir, minf(1.0, delta * 6.0)).normalized()
	_update_head(delta)
	_update_eyes(delta)
	_pant = clampf(_pant + (delta * 0.2 if _speed_now > 40.0 else -delta * 0.1), 0.0, 0.6)
	_gait += delta * maxf(_speed_now, 0.0) * 0.16
	_ear_t -= delta
	if _ear_t <= 0.0:
		_ear_t = randf_range(2.5, 6.0)
		_ear_twitch = 0.25
	_ear_twitch = maxf(0.0, _ear_twitch - delta)
	queue_redraw()

## The head leads: it looks at the player when the dog is suspicious or
## hunting, at the next waypoint while walking, and sweeps when sniffing.
func _update_head(delta: float) -> void:
	var want := 0.0
	var p := _player()
	if p and (is_aware() or state == State.SUSPICIOUS) and _sees_player:
		want = angle_difference(facing.angle(), (p.global_position - global_position).angle())
	elif state == State.SUSPICIOUS or state == State.INVESTIGATE:
		want = angle_difference(facing.angle(), (_last_known - global_position).angle())
	elif _sniff_t > 0.0:
		want = sin(_t * 2.2) * 0.5
	want = clampf(want, -0.8, 0.8)
	_head_rel = lerp_angle(_head_rel, want, minf(1.0, delta * 8.0))

func _update_eyes(delta: float) -> void:
	var t := Tuning.get_t()
	var target := 1.0 if (is_aware() and state != State.DOWNED) else 0.0
	_eye_glow = move_toward(_eye_glow, target, delta * (5.0 if target > _eye_glow else 1.5))
	_spot_flash = maxf(0.0, _spot_flash - delta * 2.5)
	if _eye_light:
		var head := Vector2.from_angle(facing.angle() + _head_rel) * 9.0 * DRAW_SCALE
		_eye_light.position = head
		_eye_light.energy = (_eye_glow * t.dog_eye_light_energy + _spot_flash * 0.6) * t.dog_eye_glow

func _sniff_wander(delta: float, center: Vector2, radius: float) -> Vector2:
	if _sniff_t > 0.0:
		_sniff_t -= delta
		return Vector2.ZERO
	if radius <= 0.0:
		_look_t -= delta
		if _look_t <= 0.0:
			_look_t = randf_range(2.0, 4.0)
			facing = facing.rotated(randf_range(-1.4, 1.4))
			_sniff_t = randf_range(0.6, 1.4)
		return Vector2.ZERO
	_wander_t -= delta
	if _wander_t <= 0.0 or global_position.distance_to(_wander_goal) < 6.0:
		_wander_t = randf_range(2.0, 4.0)
		_wander_goal = center + Vector2.from_angle(randf() * TAU) * randf_range(8.0, radius)
		_sniff_t = randf_range(0.7, 1.6)
		_path = []
		return Vector2.ZERO
	return _go_to(_wander_goal, data.walk_speed)

func _dog_combat(delta: float) -> Vector2:
	var p := _player()
	if p == null or not p.alive:
		_set_state(State.SEARCH)
		return Vector2.ZERO
	var to := p.global_position - global_position
	var dist := to.length()
	# dogs track by scent: they keep the trail when close even without sight
	if dist < 160.0:
		_last_known = p.global_position
	_bark_t -= delta
	if _bark_t <= 0.0 and _lunge_t < 0.0:
		_bark()
	if _lunge_t >= 0.0:
		_lunge_t += delta
		if not _bit and p.global_position.distance_to(global_position) < BITE_REACH:
			_bit = true
			Audio.play_at("dog_bite", global_position)
			var info := DamageInfo.make(DamageInfo.Type.MELEE, self, p.global_position, _lunge_dir, &"dog_bite", &"melee")
			info.lethal = true
			p.take_damage(info)
		if _lunge_t >= LUNGE_TIME:
			_lunge_t = -1.0
			_recover_t = 0.6
			_melee_cd = 1.0
		return Vector2.ZERO
	if _recover_t > 0.0:
		_recover_t -= delta
		return to.normalized() * data.walk_speed * 0.5
	if _windup_t >= 0.0:
		_windup_t += delta
		facing = facing.slerp(to.normalized(), minf(1.0, delta * 16.0))
		if _windup_t >= data.melee_windup:
			_windup_t = -1.0
			_lunge_t = 0.0
			_bit = false
			_lunge_dir = to.normalized()
			Audio.play_at("bark", global_position, -3.0, 0.2)
		return Vector2.ZERO
	# perception already knows if the dog can see you; only re-check the
	# line up close where a lunge through a wall would matter
	var clear := _clear_line(global_position, p.global_position) if dist < 60.0 else _sees_player
	if dist < 44.0 and _melee_cd <= 0.0 and clear:
		_windup_t = 0.0
		_growl_t = 0.3
		return Vector2.ZERO
	if not _sees_player and dist > 160.0:
		if global_position.distance_to(_last_known) < 14.0:
			_set_state(State.SEARCH)
			return Vector2.ZERO
	if clear and dist < 150.0:
		return to.normalized() * data.run_speed
	return _go_to(_last_known, data.run_speed)

# ======================================================================= damage
func knock_down(info: DamageInfo) -> void:
	_food = null
	_windup_t = -1.0
	_lunge_t = -1.0
	sleeping = false
	_set_state(State.DOWNED)
	_down_t = 2.2
	_knock = info.dir * info.knockback
	facing = -info.dir
	collision_layer = Layers.DOWNED
	Audio.play_at("yelp", global_position)
	Events.enemy_downed.emit(self)

func _get_up() -> void:
	collision_layer = Layers.ENEMY
	_getting_up = true
	_set_state(State.COMBAT)
	_getting_up = false
	var p := _player()
	if p:
		_last_known = p.global_position

func _gore_kill(info: DamageInfo, src_pos: Vector2) -> String:
	var dir := info.dir.normalized() if info.dir.length() > 0.01 else Vector2.RIGHT
	var fin := str(info.get_meta("finisher", ""))
	Gore.splatter(global_position, dir, 1.2)
	Audio.play_at("yelp", global_position, -2.0, 0.2)
	if Gore.level() < 2:
		return ""
	if fin == "decap" or (info.weapon_id == &"machete" and randf() < 0.35):
		Gore.decapitate(global_position + dir * 5.0, dir, "guard", true)
		return "head"
	if (info.type == DamageInfo.Type.EXPLOSIVE) or (info.weapon_id in [&"shotgun", &"hotshot"] and global_position.distance_to(src_pos) < 70.0 and randf() < 0.5):
		Gore.gib(global_position, dir.rotated(randf_range(-0.8, 0.8)) * 160.0, "tail")
		for i in 3:
			Gore.gib(global_position, dir.rotated(randf_range(-1.2, 1.2)) * randf_range(80, 180), "chunk")
		Gore.gib(global_position, dir.rotated(randf_range(-0.5, 0.5)) * 150.0, "dog_head")
		return "head"
	return ""

func _spawn_corpse(info: DamageInfo, missing: String) -> void:
	var corpse := Corpse.new()
	corpse.setup_dog(colors, info.dir, missing)
	corpse.global_position = global_position
	get_parent().add_child(corpse)

# ======================================================================= drawing
static func _ell(ci: CanvasItem, rot: float, c: Vector2, rx: float, ry: float, col: Color, a := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var t := i * TAU / 14.0
		pts.append((c + Vector2(cos(t) * rx, sin(t) * ry).rotated(a)).rotated(rot))
	ci.draw_colored_polygon(pts, col)

static func _leg(ci: CanvasItem, rot: float, a: Vector2, b: Vector2, col: Color, ink: Color) -> void:
	ci.draw_line(a.rotated(rot), b.rotated(rot), ink, 2.6)
	ci.draw_line(a.rotated(rot), b.rotated(rot), col, 1.5)

func _draw() -> void:
	var C: Dictionary = colors if not colors.is_empty() else DOG_COLORS["shepherd"]
	var ink := Color("0b0710")
	var rot := facing.angle()
	var base: Color = C.base
	var shade: Color = C.shade
	var light: Color = C.light
	var tan: Color = C.tan
	var saddle: Color = C.get("saddle", base)
	var mask: Color = C.get("mask", base)
	# contact shadow
	draw_set_transform(Vector2(1.0, 1.6), 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 6.5 if not sleeping else 5.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * DRAW_SCALE)
	if state == State.DOWNED:
		draw_dead(self, C, 1.0, "", _t)
		_draw_icons()
		return
	if sleeping and (state == State.IDLE or _held):
		_draw_sleeping(C, rot, ink)
		_draw_icons()
		return
	var moving := _speed_now > 6.0
	var running := _speed_now > 110.0 or _lunge_t >= 0.0
	var crouch := _windup_t >= 0.0
	var alert := is_aware() or state == State.SUSPICIOUS
	var stretch := 1.25 if _lunge_t >= 0.0 else (0.86 if crouch else 1.0)
	var sniffing := _sniff_t > 0.0 and not is_aware()
	var bob := sin(_gait * 2.0) * (0.7 if running else 0.3) if moving else sin(_t * (3.0 + _pant * 6.0)) * 0.15 * (0.5 + _pant)
	var painted := _painted_body()
	if painted:
		# the painting already has legs and tail: sway it with the stride
		# instead of drawing stick legs underneath
		var L := 29.0 * stretch * (1.0 + (sin(_gait * 2.0) * (0.04 if running else 0.02) if moving else 0.0))
		var H := 29.0 * stretch * float(painted.get_height()) / float(painted.get_width())
		var sway := sin(_gait) * (0.07 if running else 0.04) if moving else 0.0
		var by := bob * 0.3
		draw_set_transform(Vector2(0, by).rotated(rot) * DRAW_SCALE, rot + _head_rel * 0.25 + sway, Vector2.ONE * DRAW_SCALE)
		draw_texture_rect(painted, Rect2(Vector2(-L * 0.5 + 1.5, -H * 0.5), Vector2(L, H)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * DRAW_SCALE)
		var head_c := Vector2(L * 0.5 - 4.5, by)
		if _eye_glow > 0.01:
			var g := (0.7 + 0.3 * sin(_t * 9.0)) * _eye_glow * Tuning.get_t().dog_eye_glow
			for side in [-1.0, 1.0]:
				var epr := (head_c + Vector2(0.5, side * 1.3)).rotated(rot)
				draw_circle(epr, 2.4 + _spot_flash * 3.0, Color(1.0, 0.1, 0.05, 0.16 * g + 0.25 * _spot_flash))
				draw_circle(epr, 0.9, Color(1.0, 0.35, 0.2, 0.8 * _eye_glow))
		if _bark_anim > 0.0:
			var kk := 1.0 - _bark_anim / 0.35
			for i in 2:
				draw_arc((head_c + Vector2(3, 0)).rotated(rot), 6.0 + kk * 8.0 + i * 4.0, rot - 0.6, rot + 0.6, 6, Color(1, 0.9, 0.5, 0.7 * (1.0 - kk)), 1.0)
		_draw_icons()
		return
	# legs: walking = trot (diagonal pairs), running = gallop (front pair,
	# then back pair)
	var leg_col := base.darkened(0.08)
	var fore_sw := 0.0
	var hind_sw := 0.0
	var amp := 4.8 if running else 3.0
	for side in [-1.0, 1.0]:
		if running:
			fore_sw = sin(_gait) * amp
			hind_sw = sin(_gait + PI) * amp
		else:
			fore_sw = sin(_gait) * amp * side
			hind_sw = -fore_sw
		if not moving:
			fore_sw = 0.0
			hind_sw = 0.0
		var fx := 5.2 * stretch
		var hx := -5.0 * stretch
		_leg(self, rot, Vector2(fx, side * 2.3), Vector2(fx + 1.0 + fore_sw, side * 5.0), leg_col, ink)
		_leg(self, rot, Vector2(hx, side * 2.6), Vector2(hx - 1.2 - hind_sw, side * 5.2), leg_col, ink)
		draw_circle(Vector2(fx + 1.0 + fore_sw, side * 5.0).rotated(rot), 1.2, ink)
		draw_circle(Vector2(hx - 1.2 - hind_sw, side * 5.2).rotated(rot), 1.2, ink)
		draw_circle(Vector2(fx + 1.0 + fore_sw, side * 5.0).rotated(rot), 0.6, tan.darkened(0.15))
	# tail: long, bushy, hangs low in a gentle curve; wags when calm, stiff
	# and raised when alert; black tip
	var wag := sin(_t * (12.0 if not alert and not sniffing else 2.5)) * (0.55 if not alert else 0.1)
	var tail_base := Vector2(-8.2 * stretch, 0)
	var t1 := tail_base + Vector2(-3.0, 0).rotated(wag * 0.6 + (0.0 if alert else 0.25))
	var t2 := t1 + Vector2(-3.4, 0).rotated(wag + (0.1 if alert else 0.45))
	draw_polyline(PackedVector2Array([tail_base.rotated(rot), t1.rotated(rot), t2.rotated(rot)]), ink, 3.6)
	draw_polyline(PackedVector2Array([tail_base.rotated(rot), t1.rotated(rot), t2.rotated(rot)]), base, 2.4)
	draw_line(t1.lerp(t2, 0.55).rotated(rot), t2.rotated(rot), saddle, 2.2)
	# body: deep chest tapering to the hips (shepherds slope down to the rear)
	var bx := 8.6 * stretch
	var by := bob * 0.3
	_ell(self, rot, Vector2(0, by), bx + 0.9, 4.4, ink)
	_ell(self, rot, Vector2(-2.0, by + 0.4), bx * 0.62, 3.2, shade)
	_ell(self, rot, Vector2(2.2, by + 0.3), bx * 0.6, 3.8, shade)
	_ell(self, rot, Vector2(0.4, by - 0.3), bx - 0.9, 2.9, base)
	# black saddle over most of the back (shoulders to tail), tan showing
	# only along the flanks, with a hint of sheen
	_ell(self, rot, Vector2(-0.9, by - 0.2), bx * 0.82, 2.55, saddle)
	_ell(self, rot, Vector2(-0.4, by - 0.9), bx * 0.4, 0.8, C.get("saddle_hi", light))
	# hackles: raised fur along the spine when it means business
	if alert:
		for i in 4:
			var hx2 := 2.5 - i * 1.6
			draw_line(Vector2(hx2, by - 2.2).rotated(rot), Vector2(hx2 - 0.6, by - 3.2 - (i % 2) * 0.5).rotated(rot), saddle, 0.8)
	# cream chest ruff
	_ell(self, rot, Vector2(bx - 1.9, 0), 1.9, 2.4, tan)
	# neck + head (the head turns on its own, see _update_head)
	var neck := Vector2(bx - 0.8, 0)
	var hd := func(v: Vector2) -> Vector2: return neck + v.rotated(_head_rel)
	var head_low := 0.6 if (alert and not sniffing) else 0.0   # head down, stalking
	var hx0 := 2.6 + (1.4 if sniffing else 0.0) + (1.0 if _lunge_t >= 0.0 else 0.0) - head_low
	var hy0 := sin(_t * 9.0) * 1.2 if sniffing else 0.0
	if _bark_anim > 0.0:
		hx0 += sin(_bark_anim * 40.0) * 0.8
	var head: Vector2 = hd.call(Vector2(hx0, hy0))
	_ell(self, rot, head, 4.0, 3.5, ink)
	_ell(self, rot, head, 3.2, 2.8, base)
	_ell(self, rot, head + Vector2(-1.2, 0).rotated(_head_rel), 1.8, 2.0, saddle)   # dark crown
	# long wedge muzzle with the black mask
	var mz: Vector2 = hd.call(Vector2(hx0 + 3.8, hy0))
	_ell(self, rot, mz, 3.0, 1.8, ink)
	_ell(self, rot, mz, 2.4, 1.3, mask)
	draw_circle((mz + Vector2(2.3, 0).rotated(_head_rel)).rotated(rot), 0.9, ink)
	# mouth: bark / crouch / lunge open wide; panting shows the tongue
	if _bark_anim > 0.0 or crouch or _lunge_t >= 0.0:
		_ell(self, rot, mz + Vector2(0.6, 0).rotated(_head_rel), 1.5, 0.9, Color(0.75, 0.12, 0.18))
		draw_rect(Rect2((mz + Vector2(1.2, -0.9).rotated(_head_rel)).rotated(rot), Vector2(0.7, 0.7)), Color.WHITE)
		draw_rect(Rect2((mz + Vector2(1.2, 0.5).rotated(_head_rel)).rotated(rot), Vector2(0.7, 0.7)), Color.WHITE)
	elif _pant > 0.25:
		var tongue := mz + Vector2(0.8, 1.2 + sin(_t * 12.0) * 0.3).rotated(_head_rel)
		_ell(self, rot, tongue, 1.0, 0.6, Color(0.9, 0.35, 0.45))
	# ears: big, upright, pointed; flicked back when calm, pricked forward
	# when alert, a twitch now and then
	var ear_up := 1.0 if alert else 0.55
	var tw := _ear_twitch * 4.0
	for side in [-1.0, 1.0]:
		var e0: Vector2 = hd.call(Vector2(hx0 - 1.0, hy0 + side * 1.6))
		var e1: Vector2 = hd.call(Vector2(hx0 - 1.6 - 2.2 * (1.0 - ear_up * 0.5), hy0 + side * (3.6 + ear_up * 1.4 + (tw if side > 0 else 0.0) * 0.3)))
		var e2: Vector2 = hd.call(Vector2(hx0 + 0.6, hy0 + side * 2.7))
		draw_colored_polygon(PackedVector2Array([e0.rotated(rot), e1.rotated(rot), e2.rotated(rot)]), ink)
		var inner := PackedVector2Array([(e0.lerp(e2, 0.3)).rotated(rot), (e0.lerp(e1, 0.75)).rotated(rot), (e2.lerp(e1, 0.3)).rotated(rot)])
		draw_colored_polygon(inner, saddle.lerp(base, 0.35))
	# eyes: amber when calm; burning red once it has spotted you
	for side in [-1.0, 1.0]:
		var ep: Vector2 = hd.call(Vector2(hx0 + 1.4, hy0 + side * 1.35))
		var calm_col := Color(0.95, 0.75, 0.3)
		var red := Color(1.0, 0.12, 0.08)
		var col := calm_col.lerp(red, _eye_glow)
		if _eye_glow > 0.01:
			# layered halo: soft outer bloom, hot inner ring; flares on the
			# moment it spots you. Small on purpose: a glint, not a lamp.
			var g := (0.7 + 0.3 * sin(_t * 9.0)) * _eye_glow * Tuning.get_t().dog_eye_glow
			var epr := ep.rotated(rot)
			draw_circle(epr, 3.0 + _spot_flash * 3.0, Color(1.0, 0.1, 0.05, 0.16 * g + 0.25 * _spot_flash))
			draw_circle(epr, 1.8 + _spot_flash * 1.2, Color(1.0, 0.2, 0.1, 0.45 * g + 0.3 * _spot_flash))
		draw_rect(Rect2(ep.rotated(rot) - Vector2(0.65, 0.65), Vector2(1.3, 1.3)), col)
		if _eye_glow > 0.5:
			draw_rect(Rect2(ep.rotated(rot) - Vector2(0.3, 0.3), Vector2(0.6, 0.6)), Color(1.0, 0.85, 0.7))
	# collar
	var col_p: Vector2 = hd.call(Vector2(hx0 - 2.8, hy0))
	draw_line((col_p + Vector2(0, -2.8).rotated(_head_rel)).rotated(rot), (col_p + Vector2(0, 2.8).rotated(_head_rel)).rotated(rot), C.collar, 1.2)
	# sniff puffs
	if sniffing and fmod(_t, 0.5) < 0.15:
		var np := (mz + Vector2(3.5, randf_range(-1.5, 1.5)).rotated(_head_rel)).rotated(rot)
		draw_circle(np, 1.0, Color(0.85, 0.85, 0.9, 0.35))
	# bark sound arcs
	if _bark_anim > 0.0:
		var k := 1.0 - _bark_anim / 0.35
		var ha := rot + _head_rel
		for i in 2:
			var rr := 6.0 + k * 8.0 + i * 4.0
			draw_arc(mz.rotated(rot), rr, ha - 0.6, ha + 0.6, 6, Color(1, 0.9, 0.5, 0.7 * (1.0 - k)), 1.0)
	if _growl_t > 0.0 and fmod(_t, 0.2) < 0.1:
		var ha2 := rot + _head_rel
		draw_arc(mz.rotated(rot), 5.0, ha2 - 0.4, ha2 + 0.4, 5, Color(1, 0.4, 0.3, 0.6), 1.0)
	_draw_icons()

## The breed's painting from above (tools/art "topdown"), if there is one.
static var _bodies: Dictionary = {}
func _painted_body() -> Texture2D:
	var id := "dog_" + str(data.palette if data else "shepherd")
	if not _bodies.has(id):
		var pixel_path := "res://assets/art/pixellab_cast_v3_approved/%s.png" % id
		var pth := pixel_path if ResourceLoader.exists(pixel_path) else "res://assets/art/cast/%s.png" % id
		_bodies[id] = load(pth) if ResourceLoader.exists(pth) else null
	return _bodies[id]

func _draw_sleeping(C: Dictionary, rot: float, ink: Color) -> void:
	# flat out on its side, seen from above: long body, all four legs
	# stretched out to one side, head down with the snout forward, one ear
	# flopped over, tail trailing - it reads as "dog, asleep" at a glance
	var br := sin(_t * 1.8)
	var ribs := 1.0 + br * 0.07
	var key := "dog_%s_down" % str(data.palette if data else "shepherd")
	if not _bodies.has(key):
		var pth := "res://assets/art/cast/%s.png" % key
		_bodies[key] = load(pth) if ResourceLoader.exists(pth) else null
	var tex: Texture2D = _bodies[key]
	if tex:
		# the breed's painting lying on its side, flanks rising and falling
		var L := 30.0
		var H := L * float(tex.get_height()) / float(tex.get_width())
		draw_set_transform(Vector2.ZERO, rot, Vector2(1.0, ribs) * DRAW_SCALE)
		draw_texture_rect(tex, Rect2(Vector2(-L * 0.5, -H * 0.5), Vector2(L, H)), false)
		_draw_zzz()
		return
	var base: Color = C.base
	var shade: Color = C.shade
	var light: Color = C.light
	var tan: Color = C.tan
	var saddle: Color = C.get("saddle", base)
	var off := Vector2(-2.0, -1.5)
	# tail trailing back, a little curl
	var tail := PackedVector2Array()
	for i in 8:
		var k := i / 7.0
		tail.append((off + Vector2(-8.0 - k * 6.0, 0.4 + k * k * 4.0)).rotated(rot))
	draw_polyline(tail, ink, 3.4)
	draw_polyline(tail, base, 2.2)
	draw_polyline(tail.slice(4), tan, 1.2)
	# legs: stretched out to the belly side, paws relaxed (a twitch now
	# and then - dreaming)
	var dream := sin(_t * 11.0) * 0.6 if fmod(_t, 5.0) < 0.8 else 0.0
	var legs := [
		[Vector2(4.4, 2.4), Vector2(6.8 + dream, 7.4)], [Vector2(2.8, 2.8), Vector2(4.2, 8.0)],
		[Vector2(-4.8, 2.4), Vector2(-3.6 - dream, 7.8)], [Vector2(-6.6, 2.0), Vector2(-7.6, 7.2)]]
	for lg in legs:
		var la: Vector2 = off + lg[0]
		var lb: Vector2 = off + lg[1]
		draw_line(la.rotated(rot), lb.rotated(rot), ink, 3.0)
		draw_line(la.rotated(rot), lb.rotated(rot), tan, 1.8)
		_ell(self, rot, lb + (lb - la).normalized() * 0.6, 1.3, 1.0, ink)
		_ell(self, rot, lb + (lb - la).normalized() * 0.6, 0.9, 0.6, tan)
	# body: outline, then colour; ribs rise and fall
	_ell(self, rot, off + Vector2(-0.6, 0.0), 9.2, 5.0 * ribs, ink)
	_ell(self, rot, off + Vector2(4.2, 0.2), 5.0, 5.0 * ribs, ink)
	_ell(self, rot, off + Vector2(-0.6, 0.0), 8.4, 4.2 * ribs, base)
	_ell(self, rot, off + Vector2(4.2, 0.2), 4.3, 4.2 * ribs, base)
	_ell(self, rot, off + Vector2(0.0, 2.3), 6.8, 1.6, light)            # belly
	_ell(self, rot, off + Vector2(-1.2, -1.6), 6.6 * ribs, 2.4, saddle)  # back / saddle
	_ell(self, rot, off + Vector2(-1.8, -2.6), 4.2, 0.6, C.get("saddle_hi", light))
	_ell(self, rot, off + Vector2(-6.4, 0.4), 2.8, 3.2, shade)           # haunch
	# head, lying flat: skull, snout, nose, one ear flopped over the skull
	var hd := off + Vector2(10.2, -0.2)
	_ell(self, rot, hd, 3.6, 3.2, ink)
	_ell(self, rot, hd, 2.9, 2.5, base)
	_ell(self, rot, hd + Vector2(3.6, 0.8), 3.1, 1.8, ink, 0.2)
	_ell(self, rot, hd + Vector2(3.5, 0.7), 2.5, 1.2, tan, 0.2)
	_ell(self, rot, hd + Vector2(3.8, 0.3), 1.8, 0.6, C.get("mask", shade), 0.2)
	_ell(self, rot, hd + Vector2(6.1, 1.4), 0.95, 0.85, ink)             # nose
	var ear := PackedVector2Array([(hd + Vector2(-1.2, -1.6)).rotated(rot), (hd + Vector2(-2.6, -4.2)).rotated(rot),
		(hd + Vector2(0.6, -3.6)).rotated(rot), (hd + Vector2(1.0, -1.8)).rotated(rot)])
	draw_colored_polygon(ear, ink)
	var ear2 := PackedVector2Array([(hd + Vector2(-0.8, -1.8)).rotated(rot), (hd + Vector2(-1.9, -3.6)).rotated(rot), (hd + Vector2(0.3, -3.2)).rotated(rot)])
	draw_colored_polygon(ear2, shade)
	var eye := PackedVector2Array([(hd + Vector2(1.0, -0.6)).rotated(rot), (hd + Vector2(1.6, -0.25)).rotated(rot), (hd + Vector2(2.2, -0.6)).rotated(rot)])
	draw_polyline(eye, ink, 0.7)
	draw_line((hd + Vector2(-2.9, -1.4)).rotated(rot), (hd + Vector2(-2.6, 1.8)).rotated(rot), C.get("collar", Color(0.7, 0.1, 0.1)), 1.2)
	_draw_zzz()

func _draw_zzz() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var zt := fmod(_t * 0.6, 1.0)
	for i in 2:
		var k := fmod(zt + i * 0.5, 1.0)
		var zp := Vector2(3.0 + k * 4.0, -6.0 - k * 7.0)
		draw_string(UIStyle.font_bold(), zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 6 + int(k * 3.0), Color(0.8, 0.9, 1.0, 0.8 * (1.0 - k)))

func _draw_icons() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _alert_icon > 0.0:
		var c := UIStyle.HOT if _alert_char == "!" else UIStyle.GOLD
		draw_string(UIStyle.font_bold(), Vector2(-3, -12), _alert_char, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
	if debug_draw:
		draw_string(UIStyle.font_mono(), Vector2(-20, 18), state_name() + (" Zz" if sleeping else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.YELLOW)

## Dog lying on its side: used for downed dogs (twitching) and corpses.
static func draw_dead(ci: CanvasItem, C: Dictionary, twitch: float, missing := "", t := -1.0) -> void:
	if C.is_empty():
		C = DOG_COLORS["shepherd"]
	var ink := Color("0b0710")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * DRAW_SCALE)
	var tt := t if t >= 0.0 else Time.get_ticks_msec() * 0.001
	var tw := sin(tt * 30.0) * 0.8 * clampf(twitch, 0.0, 1.0)
	# the breed's painting, fallen: rolled onto its side (flatter, a little
	# twisted), darker, with a pool spreading from under it
	var breed = DOG_COLORS.find_key(C)
	var tex: Texture2D = null
	if breed != null:
		var key := "dog_%s_down" % str(breed)
		var pixel_path := "res://assets/art/pixellab_cast_v3_approved/%s.png" % key
		var pth := pixel_path if ResourceLoader.exists(pixel_path) else "res://assets/art/cast/%s.png" % key
		if not _bodies.has(key):
			_bodies[key] = load(pth) if ResourceLoader.exists(pth) else null
		tex = _bodies[key]
	if tex and missing == "":
		# the painting of the dog down on its side
		var L := 30.0
		var H := L * float(tex.get_height()) / float(tex.get_width())
		ci.draw_set_transform(Vector2(1.5, 2.0) * DRAW_SCALE, 0.0, Vector2(1.0, 0.7) * DRAW_SCALE)
		ci.draw_circle(Vector2(1, 3), 9.0, Color(0.35, 0.02, 0.05, 0.55))
		ci.draw_set_transform(Vector2.ZERO, tw * 0.02, Vector2.ONE * DRAW_SCALE)
		ci.draw_texture_rect(tex, Rect2(Vector2(-L * 0.5, -H * 0.5), Vector2(L, H)), false, Color(0.85, 0.8, 0.8))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# legs sticking out to one side
	for i in 4:
		var xs: Array[float] = [-5.0, -3.0, 3.5, 5.5]
		var x: float = xs[i]
		var a := Vector2(x, 2.0)
		var b := Vector2(x + 1.5 + (tw if i % 2 == 0 else -tw), 7.0)
		ci.draw_line(a, b, ink, 2.6)
		ci.draw_line(a, b, C.base, 1.5)
	ci.draw_line(Vector2(-7.5, 0), Vector2(-12, 1.5), ink, 2.4)
	ci.draw_line(Vector2(-7.5, 0), Vector2(-12, 1.5), C.base, 1.3)
	_ell(ci, 0.0, Vector2.ZERO, 8.8, 4.3, ink)
	_ell(ci, 0.0, Vector2(0, 0.6), 8.0, 3.5, C.shade)
	_ell(ci, 0.0, Vector2(0, -0.4), 7.2, 2.6, C.base)
	if C.has("saddle"):
		_ell(ci, 0.0, Vector2(-0.8, -1.2), 4.8, 1.6, C.saddle)
	_ell(ci, 0.0, Vector2(0.5, 1.2), 3.5, 1.4, C.tan)
	if missing == "head":
		_ell(ci, 0.0, Vector2(8.5, 0), 2.2, 2.6, Color("8a0a16"))
		_ell(ci, 0.0, Vector2(9.0, 0), 1.0, 1.1, Color("efe6d8"))
		return
	var head := Vector2(10.0, -1.0)
	_ell(ci, 0.0, head, 3.8, 3.3, ink)
	_ell(ci, 0.0, head, 3.1, 2.6, C.base)
	_ell(ci, 0.0, head + Vector2(3.3, 0.5), 2.4, 1.5, ink)
	_ell(ci, 0.0, head + Vector2(3.3, 0.5), 1.8, 1.0, C.tan)
	ci.draw_line(head + Vector2(4.0, 1.4), head + Vector2(4.6, 3.0), Color(0.85, 0.3, 0.4), 1.0)  # tongue
	ci.draw_line(head + Vector2(0.4, -1.4), head + Vector2(1.6, -0.4), ink, 0.8)
	ci.draw_line(head + Vector2(1.6, -1.4), head + Vector2(0.4, -0.4), ink, 0.8)
