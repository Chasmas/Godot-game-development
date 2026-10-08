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
## the lens is mounted high and tilted out: right under it is a dead zone,
## so hugging the wall beneath the camera slips past it
const BLIND := 30.0

var power_zone := "default"
var powered := true
var base_angle := PI * 0.5
var _t := 0.0
var _aim := 0.0                  ## current look angle
var _meter := 0.0
var _cool := 0.0
var _broken := false
var _led := 0.0
var _poly := PackedVector2Array()
var _inner := PackedVector2Array()
var _beep_t := 0.0

## How far it swings each side: measured against the walls so the cone
## keeps the lens pointed into the room (see _fit_to_room).
var sweep := SWEEP

## Look round from where it's mounted: the widest run of directions with a
## clear view (rays out to most of its range) near where it was pointed. Aim
## at its middle and swing only as far as the edges allow.
func _fit_to_room() -> void:
	var space := get_world_2d().direct_space_state
	var steps := 72
	var clear: Array = []
	for i in steps:
		var a := TAU * i / steps
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2.from_angle(a) * RANGE * 0.7, Layers.WORLD)
		clear.append(space.intersect_ray(q).is_empty())
	# runs of clear directions (wrapping), pick the one nearest the placed aim
	var best_c := base_angle
	var best_w := 0.0
	var best_d := INF
	var i0 := 0
	while i0 < steps and clear[i0]:
		i0 += 1
	if i0 >= steps:
		return   # open all round: keep the default
	var i := i0
	var done := 0
	while done < steps:
		if clear[i % steps]:
			var start := i
			while clear[i % steps] and done < steps:
				i += 1
				done += 1
			var w := TAU * (i - start) / steps
			var c := TAU * (start + (i - start) * 0.5) / steps
			var d := absf(angle_difference(c, base_angle))
			# Two-tile corridors can expose only a few clear directions at
			# this distance. Rejecting arcs under 40 degrees left their camera
			# on its default wide sweep, mostly pointed into the walls.
			if w >= deg_to_rad(10.0) and (d < best_d or w > best_w * 1.8):
				best_c = c
				best_w = w
				best_d = d
		else:
			i += 1
			done += 1
	if best_w > 0.0:
		base_angle = best_c
		_aim = base_angle
		# Fit the lens direction, not the entire fan: walls already clip each
		# cone ray. Subtracting HALF_FOV froze cameras in narrow corridors.
		sweep = clampf(best_w * 0.5 - deg_to_rad(4.0), 0.0, SWEEP)

func _ready() -> void:
	Events.lights_changed.connect(_on_zone_power)
	_fit_to_room.call_deferred()
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
	_meter = 0.0
	_poly.clear()
	_inner.clear()
	queue_redraw()
	# Investigate the accessible floor in front of the broken wall mount.
	var reported := global_position + Vector2.from_angle(base_angle) * 20.0
	var near := _alarm_responders(reported)
	for i in mini(2, near.size()):
		var e := near[i]
		var goal := reported
		if e.level and e.level.has_method("nearest_open_point"):
			goal = e.level.nearest_open_point(reported, e.global_position)
		e.alert_level = maxi(e.alert_level, 1)
		e._last_known = goal
		e._begin_investigate(goal, 12.0)
		e._show_icon("?")
	return "hit"

func _on_zone_power(zone: StringName, on: bool) -> void:
	if str(zone) != power_zone:
		return
	powered = on
	_meter = 0.0
	_beep_t = 0.0
	_poly.clear()
	_inner.clear()
	queue_redraw()

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

## Shared geometry gate: the meter and visual review use the same lens ray.
func can_see_point(point: Vector2) -> bool:
	if _broken or not powered:
		return false
	var to := point - global_position
	var distance := to.length()
	if distance <= BLIND or distance >= RANGE or absf(angle_difference(_aim, to.angle())) >= HALF_FOV:
		return false
	var lens := global_position + to.normalized() * 5.0
	var ray := PhysicsRayQueryParameters2D.create(lens, point, Layers.SIGHT_MASK, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	if _broken or not powered:
		return
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	var p := _player()
	var sees := false
	if p and p.alive and _cool <= 0.0 and p.respawn_grace <= 0.0:
		var to := p.global_position - global_position
		var d := to.length()
		sees = can_see_point(p.global_position)
		if sees:
			# closer = faster; it stops sweeping and follows you
			_meter += delta / SPOT_TIME * lerpf(1.8, 0.8, d / RANGE)
			_aim = lerp_angle(_aim, to.angle(), minf(1.0, delta * 4.0))
			_aim = clampf(angle_difference(base_angle, _aim), -sweep, sweep) + base_angle
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
			_aim = lerp_angle(_aim, base_angle + sweep * k, minf(1.0, delta * 3.0))
	_led += delta

func _raise_alarm(p: Player) -> void:
	_meter = 0.0
	_cool = COOLDOWN
	Audio.play_at("alarm", global_position, 0.0)
	Events.hint.emit("CAMERA ALARM", 1.6)
	PostFX.flash(Color(1, 0, 0.1), 0.12)
	var cand := _alarm_responders(p.global_position)
	for i in mini(3, cand.size()):
		cand[i]._on_alarm(p.global_position)

## A local security response: reachable guards, not distant bosses or dogs.
func _alarm_responders(reported_pos: Vector2) -> Array[Enemy]:
	var candidates: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if not enemy or not enemy.is_alive() or enemy.is_aware() or enemy.state == Enemy.State.DOWNED or enemy._held:
			continue
		if enemy is Dog or (enemy.data and enemy.data.combat == EnemyData.Combat.BOSS):
			continue
		if enemy.global_position.distance_to(global_position) > 420.0:
			continue
		if enemy.level and enemy.level.has_method("get_nav_path"):
			if enemy.level.get_nav_path(enemy.global_position, reported_pos).is_empty():
				continue
		candidates.append(enemy)
	candidates.sort_custom(func(a, b): return a.global_position.distance_to(reported_pos) < b.global_position.distance_to(reported_pos))
	return candidates

func _process(_delta: float) -> void:
	if not _broken and powered:
		_rebuild_cone()
	queue_redraw()

## Fan of rays so the cone stops at walls.
func _rebuild_cone() -> void:
	_poly = PackedVector2Array()
	_inner = PackedVector2Array()
	if not powered or _broken:
		return
	var space := get_world_2d().direct_space_state
	for i in RAYS:
		var a := _aim - HALF_FOV + 2.0 * HALF_FOV * i / float(RAYS - 1)
		var to := global_position + Vector2.from_angle(a) * RANGE
		var q := PhysicsRayQueryParameters2D.create(global_position + Vector2.from_angle(a) * 5.0, to, Layers.SIGHT_MASK)
		var hit := space.intersect_ray(q)
		var pt: Vector2 = hit.position if not hit.is_empty() else to
		_poly.append(pt - global_position)
		var off := pt - global_position
		_inner.append(off.normalized() * minf(BLIND, off.length()))

## Clip the moving scan highlight against the same fan as the visible cone.
## An unbroken draw_arc painted over walls even though detection stopped.
func _scan_segments(radius: float) -> PackedVector2Array:
	var segments := PackedVector2Array()
	if _poly.size() != RAYS or radius < BLIND or radius > RANGE:
		return segments
	for i in RAYS - 1:
		if radius > minf(_poly[i].length(), _poly[i + 1].length()):
			continue
		for sample in [i, i + 1]:
			var angle: float = _aim - HALF_FOV + 2.0 * HALF_FOV * sample / float(RAYS - 1)
			segments.append(Vector2.from_angle(angle) * radius)
	return segments

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
		# a band from the dead zone out to the edge: the gap under the
		# lens reads as "safe if you hug the wall"
		# quads drawn one by one (no triangulation to fail where a wall
		# cuts the cone inside the dead zone)
		var ci := Color(col, 0.28)
		var co := Color(col, 0.08)
		for i in _poly.size() - 1:
			draw_primitive(PackedVector2Array([_inner[i], _inner[i + 1], _poly[i + 1], _poly[i]]), PackedColorArray([ci, ci, co, co]), PackedVector2Array())
		draw_polyline(_poly, Color(col, 0.55), 1.0)
		draw_line(_inner[0], _poly[0], Color(col, 0.25), 1.0)
		draw_line(_inner[_inner.size() - 1], _poly[_poly.size() - 1], Color(col, 0.25), 1.0)
		# dead-zone edge: a faint dotted arc
		for i in range(0, _inner.size(), 2):
			draw_circle(_inner[i], 0.6, Color(col, 0.45))
		var sweep_k := fmod(_led * 0.9, 1.0)
		var r := lerpf(BLIND, RANGE, sweep_k)
		var scan := _scan_segments(r)
		if not scan.is_empty():
			draw_multiline(scan, Color(col, 0.12 * (1.0 - sweep_k)), 1.0)
	# bracket on the wall and the camera body turned to the aim
	draw_line(mount, Vector2.ZERO, ink, 3.0)
	draw_line(mount, Vector2.ZERO, Color(0.45, 0.45, 0.5), 1.0)
	draw_set_transform(Vector2.ZERO, _aim, Vector2.ONE)
	var ctex := ArtLib.sprite("security_camera")
	if ctex:
		draw_texture_rect(ctex, Rect2(-5, -5, 12, 10), false)
		var led2 := powered and (fmod(_led, 1.0) < 0.5 or _meter > 0.0 or _cool > 0.0)
		draw_circle(Vector2(-2, -1.5), 1.0, Color(1, 0.1, 0.15) if led2 else Color(0.3, 0.05, 0.05))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _meter > 0.0:
			draw_arc(Vector2(0, -10), 5.0, -PI * 0.5, -PI * 0.5 + TAU * _meter, 16, Color(1, 0.25, 0.15), 2.0)
		return
	draw_rect(Rect2(-4, -3, 9, 6), ink)
	draw_rect(Rect2(-3.5, -2.5, 8, 5), Color(0.82, 0.82, 0.86))
	draw_rect(Rect2(-3.5, -2.5, 8, 1.5), Color(0.95, 0.95, 1.0))
	draw_rect(Rect2(4.5, -2, 2, 4), ink)
	draw_circle(Vector2(5.5, 0), 1.4, Color(0.2, 0.3, 0.5))
	draw_circle(Vector2(5.8, -0.5), 0.5, Color(0.8, 0.9, 1.0))
	var led_on := powered and (fmod(_led, 1.0) < 0.5 or _meter > 0.0 or _cool > 0.0)
	draw_circle(Vector2(-2, -1.5), 1.0, Color(1, 0.1, 0.15) if led_on else Color(0.3, 0.05, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# spot meter: a thin arc over the camera
	if _meter > 0.0:
		draw_arc(Vector2(0, -10), 5.0, -PI * 0.5, -PI * 0.5 + TAU * _meter, 16, Color(1, 0.25, 0.15), 2.0)
