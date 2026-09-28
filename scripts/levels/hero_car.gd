class_name HeroCar
extends Node2D
## Cass's car: the cherry-red Eldorado with the gold star on the hood, parked
## on the exit spot. It stands out from every other car on the lot - chrome
## that catches the light, live headlights and tail lights, a slow shine.
##
## At the start of a job (first load only) it drives in along the clearest
## lane, brakes, settles on its springs, the door opens and she steps out.
## At the end she gets in, the engine roars and it peels away, laying down
## rubber and smoke.

signal arrived
signal departed

var _tex: Texture2D
var _t := 0.0
var _heads: Array[PointLight2D] = []
var _tails: Array[PointLight2D] = []
var _dir := Vector2.RIGHT      ## where the nose points
var _lights := 0.0             ## 0 off, 1 on
var _brake := 0.0
var _door := 0.0               ## 0 shut, 1 open
var _dome: PointLight2D        ## the interior light while the door's open
var _body: StaticBody2D
var _skids: SkidMarks
var _bounce := 0.0
var _driving := false

const LANE := 300.0            ## how far out it starts / leaves to

func _ready() -> void:
	z_index = 4
	_tex = ArtLib.sprite("car_hero")
	for i in 2:
		var h := PointLight2D.new()
		h.texture = SpriteLib.light_texture(256)
		h.texture_scale = 0.7
		h.color = Color(1.0, 0.92, 0.75)
		h.energy = 0.0
		h.shadow_enabled = true
		add_child(h)
		_heads.append(h)
		var tl := PointLight2D.new()
		tl.texture = SpriteLib.light_texture(128)
		tl.texture_scale = 0.35
		tl.color = Color(1.0, 0.1, 0.12)
		tl.energy = 0.0
		add_child(tl)
		_tails.append(tl)
	_dome = PointLight2D.new()
	_dome.texture = SpriteLib.light_texture(128)
	_dome.texture_scale = 0.3
	_dome.color = Color(1.0, 0.8, 0.5)
	_dome.energy = 0.0
	add_child(_dome)
	_body = StaticBody2D.new()
	_body.collision_layer = Layers.PROP
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(66, 26)
	cs.shape = r
	_body.add_child(cs)
	add_child(_body)
	var road := ApproachRoad.new()
	road.car = self
	road.top_level = true
	road.z_index = -30
	road.z_as_relative = false
	add_child(road)
	_skids = SkidMarks.new()
	_skids.z_index = -3
	_skids.z_as_relative = false
	_skids.top_level = true
	add_child(_skids)
	_face(_dir)

var _heading := 0.0            ## direction of travel (the nose may be off it mid-slide)
var _drift := 0.0              ## slip angle through a turn
var route_in: Array = []       ## world points: off the map, through the gate, into the space
var route_out: Array = []      ## world points: out of the space, through a gate, gone
var gates: Array = []          ## BoomGates to lift on the way through

func _face(d: Vector2) -> void:
	_dir = d.normalized()
	rotation = _dir.angle()

## A smooth drive along waypoints (a curve through them), the nose on the
## tangent. `ease_mode` 0 = slow to a stop (arriving), 1 = floor it.
func _drive(pts: Array, dur: float, ease_mode: int, on_step := Callable()) -> Tween:
	var curve := Curve2D.new()
	for k in pts.size():
		var p: Vector2 = pts[k]
		var prev: Vector2 = pts[maxi(k - 1, 0)]
		var nxt: Vector2 = pts[mini(k + 1, pts.size() - 1)]
		var tan := (nxt - prev) * 0.25
		curve.add_point(p, -tan, tan)
	var total := curve.get_baked_length()
	_heading = rotation
	_drift = 0.0
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var e := 1.0 - pow(1.0 - k, 3.0) if ease_mode == 0 else k * k * (0.4 + 0.6 * k)
		var d := e * total
		var here := curve.sample_baked(d)
		var ahead := curve.sample_baked(minf(d + 6.0, total))
		var before := global_position
		global_position = here
		var head := _heading
		if ahead.distance_to(here) > 0.5:
			head = (ahead - here).angle()
		elif d > 6.0:
			head = (here - curve.sample_baked(d - 6.0)).angle()
		var step := before.distance_to(here)
		# the powerslide: the tail steps out through the turn, the body leads
		# the line by an angle that grows with how hard it's turning
		var turn := angle_difference(_heading, head) / maxf(step, 0.5)
		_heading = head
		_drift = lerpf(_drift, clampf(turn * 14.0, -0.75, 0.75), 0.18)
		_dir = Vector2.from_angle(head)
		rotation = head + _drift
		# rubber where the tyres scrub sideways
		if step > 0.3 and absf(_drift) > 0.12:
			_skids.add_pair(global_position - Vector2.from_angle(rotation) * 18.0, Vector2.from_angle(rotation), 0.0, step)
			if randf() < 0.25:
				Effects.smoke(global_position - Vector2.from_angle(rotation) * 24.0)
		else:
			_skids.lift()
		for g in gates:
			if is_instance_valid(g) and g.global_position.distance_to(here) < 90.0:
				g.lift()
		if on_step.is_valid():
			on_step.call(k, before),
		0.0, 1.0, dur)
	return tw

func _swing_door(open: bool, t := 0.28) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "_door", 1.0 if open else 0.0, t).set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if not open:
		tw.tween_callback(func():
			Audio.play_at("car_door", global_position, -4.0, 0.08)
			_bounce = 0.6)
	return tw

func _seat() -> Vector2:
	return global_position + _dir.orthogonal() * 3.0 - _dir * 3.0

func _door_spot() -> Vector2:
	return global_position + _dir.orthogonal() * 23.0 - _dir * 1.0

## The arrival: in through the gate, round into the space, brakes, rocks
## on the springs; the dome light comes on, the door swings, a boot, then
## her - she slides out of the seat and stands up into the night, looks
## the place over, and shoves the door shut behind her.
func arrive(player: Node2D) -> void:
	if route_in.size() < 2:
		route_in = [global_position - _dir * LANE, global_position]
	var home: Vector2 = route_in[-1]
	global_position = route_in[0]
	_lights = 1.0
	_driving = true
	_body.collision_layer = 0
	player.visible = false
	player.set("input_enabled", false)
	player.set("respawn_grace", 6.0)
	var vis: Node2D = player.get("visual")
	Audio.play_at("car_arrive", home, -2.0)
	var tw := _drive(route_in, 2.8, 0, func(k: float, _b: Vector2):
		# she's at the wheel: the camera rides with the car
		player.global_position = global_position
		if k > 0.62:
			_brake = 1.0)
	tw.tween_callback(func():
		_driving = false
		_bounce = 1.0
		_drift = 0.0
		_face(_dir)
		_body.collision_layer = Layers.PROP
		Audio.play_at("car_door", global_position, -14.0, 0.3))   # handbrake clunk
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		_brake = 0.0
		Audio.play_at("car_door", global_position, -6.0)
		_swing_door(true))
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		# she's in the seat, low, turned toward the door
		player.global_position = _seat()
		player.visible = true
		if vis:
			vis.scale = Vector2.ONE * 0.8
			vis.modulate.a = 0.75
			vis.call("set_aim", _dir.orthogonal().angle()))
	# slides out through the doorway and stands up
	tw.tween_method(func(k: float):
		player.global_position = _seat().lerp(_door_spot(), k * k * (3.0 - 2.0 * k))
		if vis:
			vis.scale = Vector2.ONE * lerpf(0.8, 1.0, k)
			vis.modulate.a = lerpf(0.75, 1.0, k), 0.0, 1.0, 0.45)
	tw.tween_callback(func():
		Effects.dust(player.global_position, _dir.orthogonal(), 0.3))
	# a look around: over the lot, then back at the job
	tw.tween_method(func(k: float):
		if vis:
			vis.call("set_aim", _dir.orthogonal().angle() + sin(k * PI * 2.0) * 0.6), 0.0, 1.0, 0.6)
	tw.tween_callback(func():
		_swing_door(false)
		player.set("velocity", _dir.orthogonal() * 40.0))
	tw.tween_interval(0.25)
	tw.tween_callback(func():
		player.set("input_enabled", true)
		arrived.emit())
	var ltw := create_tween()
	ltw.tween_interval(6.0)
	ltw.tween_property(self, "_lights", 0.25, 1.2)

## The getaway: she walks up to the driver's door, pulls it open, drops in,
## the door slams, the dome light dies, the V8 catches and it peels out
## along the exit lane, laying rubber and smoke through the turns.
func depart(player: Node2D) -> void:
	player.set("input_enabled", false)
	var vis: Node2D = player.get("visual")
	var from := player.global_position
	var pts: Array = route_out if route_out.size() >= 2 else [global_position, global_position + _dir * LANE]
	var tw := create_tween()
	# a few quick steps to the door
	tw.tween_method(func(k: float):
		player.global_position = from.lerp(_door_spot(), k)
		if vis:
			vis.call("update_move", (_door_spot() - from).normalized() * 120.0, 0.016), 0.0, 1.0, clampf(from.distance_to(_door_spot()) / 140.0, 0.1, 0.5))
	tw.tween_callback(func():
		Audio.play_at("car_door", global_position, -6.0)
		_swing_door(true, 0.22))
	tw.tween_interval(0.22)
	# drops into the seat
	tw.tween_method(func(k: float):
		player.global_position = _door_spot().lerp(_seat(), k * k)
		if vis:
			vis.scale = Vector2.ONE * lerpf(1.0, 0.8, k)
			vis.modulate.a = lerpf(1.0, 0.0, clampf(k * 1.4 - 0.4, 0.0, 1.0)), 0.0, 1.0, 0.35)
	tw.tween_callback(func():
		player.visible = false
		if vis:
			vis.scale = Vector2.ONE
			vis.modulate.a = 1.0
		_swing_door(false, 0.18))
	tw.tween_interval(0.45)
	tw.tween_callback(func():
		_lights = 1.0
		_brake = 1.0
		Audio.play_at("car_arrive", global_position, -16.0, 0.4))   # the engine catching
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		_brake = 0.0
		_driving = true
		_body.collision_layer = 0
		Audio.play_at("car_peel", global_position, 0.0)
		Events.camera_shake.emit(3.0)
		var t2 := _drive(pts, 1.9, 1, func(k: float, before: Vector2):
			if k < 0.7:
				player.global_position = global_position   # the camera follows her out
			if k < 0.3:
				_skids.add_pair(global_position - _dir * 20.0, _dir, 0.0, before.distance_to(global_position))
			if k < 0.55 and randf() < 0.45:
				Effects.smoke(global_position - _dir * 26.0 + _dir.orthogonal() * randf_range(-10, 10)))
		t2.tween_callback(func(): departed.emit()))

func _process(delta: float) -> void:
	_t += delta
	_bounce = move_toward(_bounce, 0.0, delta * 2.5)
	var hl := _lights
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_heads[i].position = Vector2(46, side * 8)
		_heads[i].energy = hl * 1.3
		_tails[i].position = Vector2(-36, side * 9)
		_tails[i].energy = (0.35 * hl + 0.9 * _brake)
	_dome.energy = 0.8 * _door
	queue_redraw()

func _draw() -> void:
	var sq := 1.0 + sin(_t * 18.0) * 0.02 * _bounce
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sq, 2.0 - sq))
	# a soft shadow under the body
	draw_rect(Rect2(-34, -13, 70, 28), Color(0, 0, 0.02, 0.35))
	if _tex:
		var sz := Vector2(_tex.get_width(), _tex.get_height()) * 0.5
		draw_texture_rect(_tex, Rect2(-sz * 0.5, sz), false)
	else:
		draw_rect(Rect2(-34, -13, 68, 26), Color(0.7, 0.05, 0.1))
	# the chrome shine sliding along the body now and then
	var sh := fmod(_t * 0.35, 3.0)
	if sh < 1.0:
		var x := lerpf(-34.0, 34.0, sh)
		draw_line(Vector2(x, -12), Vector2(x - 8, 12), Color(1, 1, 1, 0.18 * sin(sh * PI)), 3.0)
	# the driver's door swings out on the left
	if _door > 0.0:
		draw_set_transform(Vector2(-2, -12), -_door * 0.9, Vector2.ONE)
		draw_rect(Rect2(0, -2, 16, 3), Color(0.62, 0.04, 0.08))
		draw_line(Vector2(0, -2), Vector2(16, -2), Color(0.95, 0.9, 0.85, 0.7), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# tail lights / headlight lenses
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(-36, side * 9 - 2, 3, 4), Color(1.0, 0.1, 0.12, 0.4 + 0.6 * maxf(_brake, _lights * 0.4)))
		draw_rect(Rect2(34, side * 8 - 2, 2, 4), Color(1.0, 0.95, 0.8, 0.3 + 0.7 * _lights))


## Rubber on the tarmac: pairs of dark strokes behind the rear wheels that
## stay for the rest of the job.
class SkidMarks extends Node2D:
	var _segs: Array = []   ## [a, b, alpha]
	var _last: Array = [Vector2.INF, Vector2.INF]

	func lift() -> void:
		_last = [Vector2.INF, Vector2.INF]

	func add_pair(rear: Vector2, dir: Vector2, length := 0.0, step := 0.0) -> void:
		var n := dir.orthogonal()
		for i in 2:
			var p := rear + n * (9.0 if i == 0 else -9.0)
			if length > 0.0:
				_segs.append([p - dir * length, p, 0.5])
			elif _last[i] != Vector2.INF and step > 0.0:
				_segs.append([_last[i], p, 0.55])
			_last[i] = p
		if _segs.size() > 400:
			_segs = _segs.slice(_segs.size() - 400)
		queue_redraw()

	func _draw() -> void:
		for s in _segs:
			draw_line(s[0], s[1], Color(0.03, 0.02, 0.03, s[2]), 3.0)


## A striped boom barrier across a gap in the lot's wall: the car's way in
## and out. The arm lifts (tilting up toward the camera, so it shortens)
## when the car comes through and drops after; on foot it's a wall, and
## she says so if she tries it.
class BoomGate extends Node2D:
	const LINES := ["Not yet. I'm not done here.", "Not on foot. The car's right there.", "Walk out now and it was all for nothing."]
	var span := 32.0          ## the gap it closes (px)
	var axis := Vector2.DOWN  ## which way the arm runs across the gap
	var _arm := 0.0           ## 0 down, 1 up
	var _up_t := 0.0
	var _bark_cd := 0.0
	var _body: StaticBody2D
	var level: Node

	func _ready() -> void:
		z_index = 5
		_body = StaticBody2D.new()
		_body.collision_layer = Layers.WORLD
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(span, 10) if axis.x != 0.0 else Vector2(10, span)
		cs.shape = r
		cs.position = axis * span * 0.5
		_body.add_child(cs)
		add_child(_body)

	func lift() -> void:
		if _up_t <= 0.0 and _arm < 0.5:
			Audio.play_at("buzz", global_position, -18.0)
		_up_t = 1.4

	func _process(delta: float) -> void:
		_up_t -= delta
		_arm = move_toward(_arm, 1.0 if _up_t > 0.0 else 0.0, delta * 2.5)
		_bark_cd -= delta
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p and p.visible and _bark_cd <= 0.0:
			var rel := p.global_position - global_position
			var along := rel.dot(axis)
			var across := absf(rel.dot(axis.orthogonal()))
			if along > -6.0 and along < span + 6.0 and across < 20.0:
				_bark_cd = 7.0
				var done: bool = level != null and level.get("phase") == Level.Phase.ESCAPE
				var line: String = LINES[1] if done else LINES[0 if randf() < 0.5 else 2]
				var bl := BarkLayer.find(get_tree())
				if bl:
					bl.say(p, tr(line), 2.4, Color(1, 0.9, 0.8))
		queue_redraw()

	func _draw() -> void:
		# posts at both ends, the striped arm between; lifted, it foreshortens
		# toward the hinge post and throws a shadow
		for e in [Vector2.ZERO, axis * span]:
			draw_rect(Rect2(e - Vector2(4, 4), Vector2(8, 8)), Color(0.15, 0.15, 0.18))
		draw_circle(Vector2.ZERO, 2.2, Color(1.0, 0.25, 0.2) if _arm < 0.5 else Color(0.3, 1.0, 0.4))
		var L := span * (1.0 - 0.82 * _arm)
		if _arm > 0.05:
			draw_line(Vector2(4, 4), Vector2(4, 4) + axis * L * 1.1, Color(0, 0, 0, 0.3 * _arm), 3.0)
		var lift_off := -axis.orthogonal() * 6.0 * _arm
		for k in 8:
			var a := axis * (L * k / 8.0) + lift_off * (k / 8.0)
			var b := axis * (L * (k + 1) / 8.0) + lift_off * ((k + 1) / 8.0)
			draw_line(a, b, Color(0.95, 0.9, 0.85) if k % 2 == 0 else Color(0.85, 0.1, 0.12), 3.0)
		draw_circle(axis * L + lift_off, 1.6, Color(1.0, 0.3, 0.2, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)))


## The road in and out: asphalt with kerbs, a dashed centre line and a
## couple of street lamps, laid along the car's routes under the level's
## own floor - so beyond the gates the lot has somewhere to come from.
class ApproachRoad extends Node2D:
	var car: Node

	func _draw() -> void:
		for route in [car.route_in, car.route_out]:
			if route.size() < 2:
				continue
			var pts := PackedVector2Array(route)
			draw_polyline(pts, Color(0.28, 0.26, 0.3), 58.0, true)          # kerb
			draw_polyline(pts, Color(0.09, 0.085, 0.11), 50.0, true)        # tarmac
			# dashed centre line
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var L := a.distance_to(b)
				var d := (b - a) / maxf(L, 0.01)
				var t := 0.0
				while t < L:
					draw_line(a + d * t, a + d * minf(t + 10.0, L), Color(0.85, 0.7, 0.25, 0.7), 2.0)
					t += 22.0
			# a street lamp by the road's far end, pooling light
			var far: Vector2 = pts[0] if route == car.route_in else pts[pts.size() - 1]
			var side := (pts[1] - pts[0]).normalized().orthogonal() if route == car.route_in else (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized().orthogonal()
			var lamp := far.lerp(pts[1] if route == car.route_in else pts[pts.size() - 2], 0.35) + side * 36.0
			draw_circle(lamp, 26.0, Color(1.0, 0.75, 0.4, 0.08))
			draw_circle(lamp, 3.0, Color(0.2, 0.2, 0.22))
			draw_circle(lamp, 1.6, Color(1.0, 0.85, 0.55))
