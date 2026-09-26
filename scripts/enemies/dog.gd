class_name Dog
extends Enemy
## Guard dog. Sleeps, sniffs around, patrols with its handlers. Smells you
## if you move fast nearby (sneak past, or kill it while it sleeps), barks to
## alert every human in earshot, then sprints and lunges. The lunge has a
## crouch tell: hit it during the crouch to counter. Drawn procedurally in a
## cel-shaded style: gait, tail wag, ears, sniffing, barking, curled sleep.

const DOG_COLORS := {
	"doberman":   {"base": Color("2c211b"), "shade": Color("15100d"), "light": Color("54423a"), "tan": Color("a8602c"), "collar": Color("c81e28")},
	"rottweiler": {"base": Color("1c1612"), "shade": Color("0e0a08"), "light": Color("33271f"), "tan": Color("8a4a22"), "collar": Color("d4a020")},
}
const BITE_REACH := 15.0
const DRAW_SCALE := 0.62     ## art is authored ~1.6x; a dog should be about a person's length
const LUNGE_SPEED := 300.0
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

func setup(p_data: EnemyData, p_level: Node, p_facing: Vector2) -> void:
	super(p_data, p_level, p_facing)
	visual.visible = false
	hit_radius = 5.5
	colors = DOG_COLORS.get(data.palette, DOG_COLORS["doberman"])
	_t = randf() * 10.0
	_wander_goal = global_position

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
	if p == null or not p.alive or state == State.DOWNED or _held:
		return
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
	if not is_alive() or state == State.DOWNED or source == self or _held:
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

func _bark() -> void:
	_bark_anim = 0.35
	_bark_t = randf_range(1.0, 1.8)
	Audio.play_at("bark", global_position, -1.0, 0.12)
	Events.noise.emit(global_position, data.alert_others_radius, &"voice", self)

# ======================================================================= loop
func _physics_process(delta: float) -> void:
	if not is_alive():
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
	else:
		velocity = desired + _separation() + _knock
	move_and_slide()
	_speed_now = velocity.length()
	if desired.length() > 5.0 and state != State.DOWNED:
		facing = facing.slerp(desired.normalized(), minf(1.0, delta * 9.0))
	_gait += delta * _speed_now * 0.16
	if _speed_now > 6.0 and Engine.get_physics_frames() % 20 == 0 and _speed_now > 120.0:
		Audio.play_at("step%d" % (randi() % 3), global_position, -22.0, 0.3)
	queue_redraw()

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
			_recover_t = 0.45
			_melee_cd = 0.7
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
	var clear := _clear_line(global_position, p.global_position)
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
	_set_state(State.COMBAT)
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
	var C: Dictionary = colors if not colors.is_empty() else DOG_COLORS["doberman"]
	var ink := Color("0b0710")
	var rot := facing.angle()
	var base: Color = C.base
	var shade: Color = C.shade
	var light: Color = C.light
	var tan: Color = C.tan
	# contact shadow
	draw_set_transform(Vector2(1.0, 1.6), 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 6.0 if not sleeping else 5.0, Color(0, 0, 0, 0.3))
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
	var stretch := 1.25 if _lunge_t >= 0.0 else (0.85 if crouch else 1.0)
	var sniffing := _sniff_t > 0.0 and not is_aware()
	var bob := sin(_gait * 2.0) * (0.6 if running else 0.3) if moving else 0.0
	# legs (4): diagonal pairs swing together
	var sw := sin(_gait) * (4.5 if running else 3.0) if moving else 0.0
	var leg_col := base.darkened(0.1)
	for side in [-1.0, 1.0]:
		var ph: float = sw * side
		_leg(self, rot, Vector2(4.8 * stretch, side * 2.4), Vector2(5.8 * stretch + ph, side * 5.2), leg_col, ink)
		_leg(self, rot, Vector2(-4.6 * stretch, side * 2.4), Vector2(-5.6 * stretch - ph, side * 5.2), leg_col, ink)
		# paws
		draw_circle(Vector2(5.8 * stretch + ph, side * 5.2).rotated(rot), 1.1, ink)
		draw_circle(Vector2(-5.6 * stretch - ph, side * 5.2).rotated(rot), 1.1, ink)
	# tail: wags when calm, stiff when alert
	var wag := sin(_t * (14.0 if not is_aware() and not sniffing else 3.0)) * (0.7 if not is_aware() else 0.12)
	var tail_base := Vector2(-7.5 * stretch, 0)
	var tail_tip := tail_base + Vector2(-4.5, 0).rotated(wag)
	draw_line(tail_base.rotated(rot), tail_tip.rotated(rot), ink, 2.4)
	draw_line(tail_base.rotated(rot), tail_tip.rotated(rot), base, 1.3)
	# body: ink, shade, base, highlight (3-tone cel ramp)
	var bx := 8.0 * stretch
	_ell(self, rot, Vector2(0, bob * 0.3), bx + 0.9, 4.1, ink)
	_ell(self, rot, Vector2(0, bob * 0.3 + 0.5), bx, 3.3, shade)
	_ell(self, rot, Vector2(0.3, bob * 0.3 - 0.4), bx - 0.8, 2.5, base)
	_ell(self, rot, Vector2(1.2, bob * 0.3 - 1.2), bx * 0.55, 1.0, light)
	# tan chest patch
	_ell(self, rot, Vector2(bx - 1.8, 0), 1.6, 2.0, tan)
	# head
	var hx := bx + (1.8 if not sniffing else 3.2) + (1.0 if _lunge_t >= 0.0 else 0.0)
	var hy := 0.0
	if sniffing:
		hy = sin(_t * 9.0) * 1.3
	if _bark_anim > 0.0:
		hx += sin(_bark_anim * 40.0) * 0.8
	var head := Vector2(hx, hy)
	_ell(self, rot, head, 3.9, 3.5, ink)
	_ell(self, rot, head, 3.1, 2.8, base)
	_ell(self, rot, head + Vector2(-0.6, -0.8), 1.6, 1.2, light)
	# muzzle + nose
	var mz := head + Vector2(3.4, 0)
	_ell(self, rot, mz, 2.6, 1.7, ink)
	_ell(self, rot, mz, 2.0, 1.2, tan)
	draw_circle((mz + Vector2(2.0, 0)).rotated(rot), 0.8, ink)
	# open mouth when barking / crouched
	if _bark_anim > 0.0 or crouch or _lunge_t >= 0.0:
		_ell(self, rot, mz + Vector2(0.6, 0), 1.4, 0.8, Color(0.75, 0.12, 0.18))
		draw_rect(Rect2((mz + Vector2(1.2, -0.9)).rotated(rot), Vector2(0.7, 0.7)), Color.WHITE)
		draw_rect(Rect2((mz + Vector2(1.2, 0.5)).rotated(rot), Vector2(0.7, 0.7)), Color.WHITE)
	# ears: pointed (dobermann) up when alert, back when calm
	var ear_up := 1.0 if is_aware() or state == State.SUSPICIOUS else 0.5
	for side in [-1.0, 1.0]:
		var e0 := head + Vector2(-1.2, side * 1.8)
		var e1 := head + Vector2(-1.2 - 2.6 * (1.0 - ear_up * 0.4), side * (2.8 + ear_up * 1.2))
		var e2 := head + Vector2(0.4, side * 2.6)
		var tri := PackedVector2Array([e0.rotated(rot), e1.rotated(rot), e2.rotated(rot)])
		draw_colored_polygon(tri, ink)
		var tri2 := PackedVector2Array([(e0 + Vector2(0.3, 0)).rotated(rot), ((e0 + e1) * 0.5 + (e1 - e0) * 0.3).rotated(rot), ((e0 + e2) * 0.5).rotated(rot)])
		draw_colored_polygon(tri2, shade)
	# eyes (glint)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2((head + Vector2(1.3, side * 1.3)).rotated(rot) - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1, 0.85, 0.3) if is_aware() else Color(0.9, 0.9, 0.8))
	# collar
	var col_p := head + Vector2(-2.6, 0)
	draw_line((col_p + Vector2(0, -2.8)).rotated(rot), (col_p + Vector2(0, 2.8)).rotated(rot), C.collar, 1.2)
	# sniff puffs
	if sniffing and fmod(_t, 0.5) < 0.15:
		var np := (mz + Vector2(3.5, randf_range(-1.5, 1.5))).rotated(rot)
		draw_circle(np, 1.0, Color(0.85, 0.85, 0.9, 0.35))
	# bark sound arcs
	if _bark_anim > 0.0:
		var k := 1.0 - _bark_anim / 0.35
		for i in 2:
			var rr := 6.0 + k * 8.0 + i * 4.0
			draw_arc((mz).rotated(rot), rr, rot - 0.6, rot + 0.6, 6, Color(1, 0.9, 0.5, 0.7 * (1.0 - k)), 1.0)
	if _growl_t > 0.0 and fmod(_t, 0.2) < 0.1:
		draw_arc(mz.rotated(rot), 5.0, rot - 0.4, rot + 0.4, 5, Color(1, 0.4, 0.3, 0.6), 1.0)
	_draw_icons()

func _draw_sleeping(C: Dictionary, rot: float, ink: Color) -> void:
	var breathe := 1.0 + sin(_t * 1.8) * 0.05
	var base: Color = C.base
	# curled: round body, tail wrapped, head on paws
	_ell(self, rot, Vector2.ZERO, 7.4 * breathe, 6.4 * breathe, ink)
	_ell(self, rot, Vector2(0, 0.5), 6.6 * breathe, 5.6 * breathe, C.shade)
	_ell(self, rot, Vector2(-0.4, -0.4), 5.6 * breathe, 4.4 * breathe, base)
	_ell(self, rot, Vector2(-1.2, -1.6), 3.0, 1.4, C.light)
	# tail wrapped around the front
	draw_arc(Vector2.ZERO, 6.8, rot + 0.6, rot + 2.4, 8, ink, 2.4)
	draw_arc(Vector2.ZERO, 6.8, rot + 0.6, rot + 2.4, 8, base, 1.3)
	# head resting at the front-right, paws under the chin
	var head := Vector2(4.6, 2.8)
	_ell(self, rot, head + Vector2(2.2, 1.4), 1.6, 1.0, ink)
	_ell(self, rot, head, 3.4, 3.0, ink)
	_ell(self, rot, head, 2.7, 2.3, base)
	_ell(self, rot, head + Vector2(2.6, 0.4), 1.9, 1.3, ink)
	_ell(self, rot, head + Vector2(2.6, 0.4), 1.4, 0.8, C.tan)
	draw_line((head + Vector2(1.0, -1.2)).rotated(rot), (head + Vector2(1.8, -1.0)).rotated(rot), ink, 0.8)   # closed eye
	draw_line((head + Vector2(-1.2, -1.6)).rotated(rot), (head + Vector2(-2.8, -3.0)).rotated(rot), ink, 1.6)  # floppy ear
	# Zzz
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
		C = DOG_COLORS["doberman"]
	var ink := Color("0b0710")
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * DRAW_SCALE)
	var tt := t if t >= 0.0 else Time.get_ticks_msec() * 0.001
	var tw := sin(tt * 30.0) * 0.8 * clampf(twitch, 0.0, 1.0)
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
