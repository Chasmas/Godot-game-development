class_name SecurityCamera
extends StaticBody2D
## Wall-mounted security camera. Sweeps side to side (pausing at each end)
## with a visible vision cone, clipped by walls so what you see is exactly
## what it sees. Deliberately short range (seven tiles) and a spot meter,
## so it's a puzzle, not a trap:
##  - in the cone, the meter fills (faster up close) and the camera stops
##    sweeping to follow you; the cone goes amber, then red;
##  - full: alarm - a siren and the three nearest guards come hunting where
##    you were; the camera then cools down;
##  - shoot it or hit it: it breaks (sparks, dangling), and one or two guards
##    who heard it come to see what happened.

const RANGE := 112.0
const HALF_FOV := deg_to_rad(24.0)
const SWEEP := deg_to_rad(55.0)
const SWEEP_TIME := 6.5
const SPOT_TIME := 0.9           ## seconds of clear view at range to raise the alarm
const COOLDOWN := 9.0
const RAYS := 13

var base_angle := PI * 0.5
var _t := 0.0
var _aim := 0.0                  ## current look angle
var _meter := 0.0
var _cool := 0.0
var _broken := false
var _led := 0.0
var _poly := PackedVector2Array()
var _beep_t := 0.0

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("security_cameras")
	collision_layer = Layers.PROP
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 4.0
	cs.shape = c
	add_child(cs)
	z_index = 6
	_t = randf() * SWEEP_TIME
	_aim = base_angle

func take_damage(info: DamageInfo) -> String:
	if _broken:
		return "pass"
	_broken = true
	collision_layer = 0
	Audio.play_at("camera_break", global_position, 0.0, 0.1)
	Effects.sparks(global_position, -info.dir if info.dir != Vector2.ZERO else Vector2.DOWN)
	Score.add_bonus("CAMERA DOWN", 150, global_position)
	# the crash is heard: one or two nearby guards come to look
	var near: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and not e.is_aware() and e.global_position.distance_to(global_position) < 420.0 and not e is Dog:
			near.append(e)
	near.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	for i in mini(2, near.size()):
		var e: Enemy = near[i]
		e.alert_level = maxi(e.alert_level, 1)
		e._last_known = global_position
		e._begin_investigate(global_position + Vector2.from_angle(base_angle) * 20.0, 12.0)
		e._show_icon("?")
	return "hit"

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
	if _broken:
		return
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	var p := _player()
	var sees := false
	if p and p.alive and _cool <= 0.0:
		var to := p.global_position - global_position
		var d := to.length()
		if d < RANGE and absf(angle_difference(_aim, to.angle())) < HALF_FOV:
			var q := PhysicsRayQueryParameters2D.create(global_position + Vector2.from_angle(_aim) * 5.0, p.global_position, Layers.SIGHT_MASK)
			sees = get_world_2d().direct_space_state.intersect_ray(q).is_empty()
		if sees:
			# closer = faster; it stops sweeping and follows you
			_meter += delta / SPOT_TIME * lerpf(1.8, 0.8, d / RANGE)
			_aim = lerp_angle(_aim, to.angle(), minf(1.0, delta * 4.0))
			_aim = clampf(angle_difference(base_angle, _aim), -SWEEP, SWEEP) + base_angle
			_beep_t -= delta
			if _beep_t <= 0.0:
				_beep_t = lerpf(0.35, 0.08, _meter)
				Audio.play_at("blip", global_position, -10.0, 0.0)
			if _meter >= 1.0:
				_raise_alarm(p)
	if not sees:
		_meter = maxf(0.0, _meter - delta * 0.6)
		if _meter <= 0.0:
			# sweep: ease between the ends with a short hold at each
			var ph := fmod(_t, SWEEP_TIME) / SWEEP_TIME
			var k := clampf(sin(ph * TAU) * 1.25, -1.0, 1.0)
			_aim = lerp_angle(_aim, base_angle + SWEEP * k, minf(1.0, delta * 3.0))
	_led += delta

func _raise_alarm(p: Player) -> void:
	_meter = 0.0
	_cool = COOLDOWN
	Audio.play_at("alarm", global_position, 0.0)
	Events.hint.emit("CAMERA ALARM", 1.6)
	PostFX.flash(Color(1, 0, 0.1), 0.12)
	var cand: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and not e.is_aware() and e.state != Enemy.State.DOWNED:
			cand.append(e)
	cand.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	for i in mini(3, cand.size()):
		(cand[i] as Enemy)._on_alarm(p.global_position)

func _process(_delta: float) -> void:
	if not _broken:
		_rebuild_cone()
	queue_redraw()

## Fan of rays so the cone stops at walls.
func _rebuild_cone() -> void:
	_poly = PackedVector2Array([Vector2.ZERO])
	var space := get_world_2d().direct_space_state
	for i in RAYS:
		var a := _aim - HALF_FOV + 2.0 * HALF_FOV * i / float(RAYS - 1)
		var to := global_position + Vector2.from_angle(a) * RANGE
		var q := PhysicsRayQueryParameters2D.create(global_position + Vector2.from_angle(a) * 5.0, to, Layers.SIGHT_MASK)
		var hit := space.intersect_ray(q)
		var pt: Vector2 = hit.position if not hit.is_empty() else to
		_poly.append(pt - global_position)

func _draw() -> void:
	var ink := Color("0b0710")
	var mount := -Vector2.from_angle(base_angle) * 5.0
	if _broken:
		# hanging off its bracket, lens smashed, the odd spark
		draw_line(mount, mount + Vector2(1, 6), ink, 2.0)
		draw_rect(Rect2(mount + Vector2(-3, 5), Vector2(6, 8)), Color(0.25, 0.25, 0.3))
		draw_rect(Rect2(mount + Vector2(-3, 5), Vector2(6, 8)), ink, false, 1.0)
		if fmod(_led, 1.7) < 0.08:
			draw_circle(mount + Vector2(0, 13), 1.5, Color(1, 0.9, 0.5))
		return
	# cone: colour by state, brighter edge, scanline shimmer
	var col := Color(0.35, 0.85, 1.0)
	if _cool > 0.0:
		col = Color(1.0, 0.1, 0.15)
	elif _meter > 0.0:
		col = Color(1.0, 0.8, 0.2).lerp(Color(1.0, 0.15, 0.1), _meter)
	if _poly.size() > 2:
		var cols := PackedColorArray()
		for i in _poly.size():
			cols.append(Color(col, 0.28 if i == 0 else 0.08))
		draw_polygon(_poly, cols)
		var edge := _poly.slice(1)
		draw_polyline(edge, Color(col, 0.55), 1.0)
		draw_line(Vector2.ZERO, _poly[1], Color(col, 0.25), 1.0)
		draw_line(Vector2.ZERO, _poly[_poly.size() - 1], Color(col, 0.25), 1.0)
		var sweep_k := fmod(_led * 0.9, 1.0)
		draw_arc(Vector2.ZERO, RANGE * sweep_k, _aim - HALF_FOV, _aim + HALF_FOV, 10, Color(col, 0.12 * (1.0 - sweep_k)), 1.0)
	# bracket on the wall and the camera body turned to the aim
	draw_line(mount, Vector2.ZERO, ink, 3.0)
	draw_line(mount, Vector2.ZERO, Color(0.45, 0.45, 0.5), 1.0)
	draw_set_transform(Vector2.ZERO, _aim, Vector2.ONE)
	draw_rect(Rect2(-4, -3, 9, 6), ink)
	draw_rect(Rect2(-3.5, -2.5, 8, 5), Color(0.82, 0.82, 0.86))
	draw_rect(Rect2(-3.5, -2.5, 8, 1.5), Color(0.95, 0.95, 1.0))
	draw_rect(Rect2(4.5, -2, 2, 4), ink)
	draw_circle(Vector2(5.5, 0), 1.4, Color(0.2, 0.3, 0.5))
	draw_circle(Vector2(5.8, -0.5), 0.5, Color(0.8, 0.9, 1.0))
	var led_on := fmod(_led, 1.0) < 0.5 or _meter > 0.0 or _cool > 0.0
	draw_circle(Vector2(-2, -1.5), 1.0, Color(1, 0.1, 0.15) if led_on else Color(0.3, 0.05, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# spot meter: a thin arc over the camera
	if _meter > 0.0:
		draw_arc(Vector2(0, -10), 5.0, -PI * 0.5, -PI * 0.5 + TAU * _meter, 16, Color(1, 0.25, 0.15), 2.0)
