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
const SEAT_LOCAL := Vector2(-1, -6)   ## the driver's seat (front left) in the car's frame
var _seated := false          ## draw her at the wheel (it's a convertible)
var _driver_tex: Texture2D
const BODY_HALF_W := 16.0      ## the car's side, from its centre line (world px)
const DOOR_FRONT := 10.0       ## the driver's door: hinge edge by the windscreen...
const DOOR_BACK := -9.0        ## ...to its back edge

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
var _skid_cd := 0.0
var night := true              ## headlights only after dark
var _idle: AudioStreamPlayer2D   ## the V8 ticking over while it's parked with the lights on
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
		_skid_cd -= get_process_delta_time()
		if absf(_drift) > 0.3 and _skid_cd <= 0.0:
			_skid_cd = 0.45
			Audio.play_at("tire_skid", global_position, -4.0, 0.1)
		if step > 0.3 and absf(_drift) > 0.12:
			_skids.add_pair(global_position - Vector2.from_angle(rotation) * 18.0, Vector2.from_angle(rotation), 0.0, step)
			if randf() < 0.25:
				Effects.smoke(global_position - Vector2.from_angle(rotation) * 24.0)
		else:
			_skids.lift()
		for g in gates:
			if is_instance_valid(g) and not g.broken and g.hit_by(here, Vector2.from_angle(rotation)):
				g.smash(Vector2.from_angle(rotation), step / maxf(get_process_delta_time(), 0.001))
		if on_step.is_valid():
			on_step.call(k, before),
		0.0, 1.0, dur)
	return tw

func _swing_door(open: bool, t := 0.42) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "_door", 1.0 if open else 0.0, t).set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if not open:
		tw.tween_callback(func():
			Audio.play_at("car_door", global_position, -4.0, 0.08)
			_bounce = 0.6)
	return tw

func _seat() -> Vector2:
	return global_position + _dir * SEAT_LOCAL.x - _dir.orthogonal() * SEAT_LOCAL.y

## Her, at the wheel: the torso art of whoever's driving, hands forward.
func _take_wheel(player: Node2D, on: bool) -> void:
	_seated = on
	if on:
		var vis: Node = player.get("visual")
		var pal := str(vis.get("palette")) if vis and vis.get("palette") != null else "cass"
		_driver_tex = SpriteLib.torso("aim_two", pal)
	queue_redraw()

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
	_lights = 1.0 if night else 0.0
	_driving = true
	_body.collision_layer = 0
	player.visible = false
	_take_wheel(player, true)
	player.set("input_enabled", false)
	player.set("respawn_grace", 6.0)
	var vis: Node2D = player.get("visual")
	Audio.play_at("car_arrive", home, -2.0)
	var tw := _drive(route_in, 2.8, 0, func(k: float, _b: Vector2):
		# she's at the wheel: the camera rides with the car
		player.global_position = global_position
		if k > 0.62 and _brake < 1.0:
			_brake = 1.0
			Audio.play_at("car_brake", global_position, -6.0))
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
		# key out: lights die, the engine ticks down
		create_tween().tween_property(self, "_lights", 0.0, 0.25)
		Audio.play_at("car_door", global_position, -6.0)
		_swing_door(true))
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		# she's in the seat, low, turned toward the door
		_take_wheel(player, false)
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
		_take_wheel(player, true)
		if vis:
			vis.scale = Vector2.ONE
			vis.modulate.a = 1.0
		_swing_door(false, 0.18))
	tw.tween_interval(0.45)
	tw.tween_callback(func():
		_lights = 1.0 if night else 0.0
		_brake = 1.0
		Audio.play_at("car_arrive", global_position, -16.0, 0.4)   # the engine catching
		_engine(true))
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		_brake = 0.0
		_driving = true
		_body.collision_layer = 0
		Audio.play_at("car_peel", global_position, 0.0)
		Audio.play_at("tire_skid", global_position, -2.0)
		_engine(false)
		Events.camera_shake.emit(3.0)
		var t2 := _drive(pts, 1.9, 1, func(k: float, before: Vector2):
			if k < 0.7:
				player.global_position = global_position   # the camera follows her out
			if k < 0.3:
				_skids.add_pair(global_position - _dir * 20.0, _dir, 0.0, before.distance_to(global_position))
			if k < 0.55 and randf() < 0.45:
				Effects.smoke(global_position - _dir * 26.0 + _dir.orthogonal() * randf_range(-10, 10)))
		t2.tween_callback(func(): departed.emit()))

## The engine idling: a quiet positional loop while she's parked with the
## lights on (and again after she gets in, before it goes).
func _engine(on: bool) -> void:
	if on and _idle == null:
		var src := Audio.get_stream("car_idle") as AudioStreamWAV
		if src:
			var st := src.duplicate() as AudioStreamWAV
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_end = st.data.size() / 2
			_idle = AudioStreamPlayer2D.new()
			_idle.stream = st
			_idle.bus = "SFX"
			_idle.volume_db = -14.0
			_idle.max_distance = 500.0
			add_child(_idle)
			_idle.play()
	elif not on and _idle:
		var p := _idle
		_idle = null
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, 1.0)
		tw.tween_callback(p.queue_free)

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
	# her at the wheel (open top): torso art at the driver's seat
	if _seated and _driver_tex:
		draw_set_transform(SEAT_LOCAL * Vector2(sq, 2.0 - sq), 0.0, Vector2(0.45, 0.45))
		draw_texture(_driver_tex, -_driver_tex.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the driver's door (left side, -y): hinged at its FRONT edge by the
	# windscreen, the back edge swings out - like a real car door
	if _door > 0.0:
		var hinge := Vector2(DOOR_FRONT, -BODY_HALF_W)
		var dl := DOOR_FRONT - DOOR_BACK
		# the opening in the body: the dark sill, the seat and the dome's glow inside
		draw_rect(Rect2(DOOR_BACK, -BODY_HALF_W, dl, 3.5), Color(0.05, 0.02, 0.04))
		draw_rect(Rect2(DOOR_BACK + 3, -BODY_HALF_W + 1, dl - 7, 2.5), Color(0.55, 0.12, 0.14))
		draw_rect(Rect2(DOOR_BACK + 3, -BODY_HALF_W + 1, dl - 7, 2.5), Color(1.0, 0.85, 0.55, 0.25 * _door))
		# the door, rotated out about the hinge (0 shut .. ~65 degrees)
		draw_set_transform(hinge, _door * deg_to_rad(65.0), Vector2.ONE)
		var ink := Color(0.05, 0.02, 0.04)
		draw_rect(Rect2(-dl - 0.5, -2.5, dl + 1.0, 4.0), ink)
		draw_rect(Rect2(-dl, -2.0, dl, 3.0), Color(0.72, 0.05, 0.1))                 # the paint, outside
		draw_rect(Rect2(-dl, 0.2, dl, 0.8), Color(0.3, 0.05, 0.08))                   # the trim panel, inside
		draw_line(Vector2(-dl, -1.8), Vector2(0, -1.8), Color(0.95, 0.92, 0.88, 0.8), 0.8)   # chrome strip
		draw_rect(Rect2(-dl * 0.55, -1.2, dl * 0.45, 1.2), Color(0.55, 0.75, 0.9, 0.7))     # the window glass
		draw_rect(Rect2(-dl + 2.0, -2.6, 2.5, 0.8), Color(0.9, 0.88, 0.8))              # the handle
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# tail lights / headlight lenses
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(-36, side * 9 - 2, 3, 4), Color(1.0, 0.1, 0.12, 0.4 + 0.6 * maxf(_brake, _lights * 0.4)))
		draw_rect(Rect2(34, side * 8 - 2, 2, 4), Color(1.0, 0.95, 0.8, 0.3 + 0.7 * _lights))


## Rubber on the tarmac: pairs of dark strokes behind the rear wheels that
## stay for the rest of the job.


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
		if _segs.size() > 600:
			_segs = _segs.slice(_segs.size() - 600)
		queue_redraw()

	func _draw() -> void:
		for s in _segs:
			draw_line(s[0], s[1], Color(0.03, 0.02, 0.03, s[2]), 3.0)


## A striped boom barrier across a gap in the lot's wall: the car's way in
## and out. The car goes straight through it - the arm snaps into striped
## pieces that cartwheel away and stay where they land. On foot the gap is
## still closed, and she says so if she tries it.
class BoomGate extends Node2D:
	const LINES := ["Not yet. I'm not done here.", "Not on foot. The car's right there.", "Walk out now and it was all for nothing."]
	var span := 32.0          ## the gap it closes (px)
	var axis := Vector2.DOWN  ## which way the arm runs across the gap
	var broken := false
	var level: Node
	var _bits: Array = []     ## flying pieces of the arm: {p, v, r, w, len, stripe, h, vh}
	var _bark_cd := 0.0
	var _push_t := 0.0        ## how long she's been shoving the arm
	var _body: StaticBody2D

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

	## Is the car's nose on the arm right now?
	func hit_by(pos: Vector2, _heading: Vector2) -> bool:
		var rel := pos - global_position
		var along := rel.dot(axis)
		var across := absf(rel.dot(axis.orthogonal()))
		return along > -8.0 and along < span + 8.0 and across < 34.0

	func smash(dir: Vector2, speed: float) -> void:
		if broken:
			return
		broken = true
		var v := clampf(speed, 120.0, 420.0)
		Audio.play_at("door_break", global_position, -2.0, 0.1)
		Audio.play_at("hit_blunt", global_position, -6.0, 0.1)
		Events.camera_shake.emit(3.5)
		var n := 7
		for k in n:
			var mid := axis * span * (k + 0.5) / n
			_bits.append({"p": mid, "v": dir * v * randf_range(0.5, 1.1) + axis.orthogonal() * randf_range(-80, 80),
				"r": 0.0, "w": randf_range(-14.0, 14.0), "len": span / n * randf_range(0.7, 1.0), "stripe": k % 2 == 0,
				"h": 0.0, "vh": randf_range(40.0, 110.0)})
			Effects.splinters(global_position + mid, dir, true, 0.6)

	func _process(delta: float) -> void:
		for b in _bits:
			if float(b.h) <= 0.0 and float(b.vh) == 0.0:
				continue
			b.p = (b.p as Vector2) + (b.v as Vector2) * delta
			b.v = (b.v as Vector2).move_toward(Vector2.ZERO, 260.0 * delta)
			b.r = float(b.r) + float(b.w) * delta
			b.vh = float(b.vh) - 320.0 * delta
			b.h = float(b.h) + float(b.vh) * delta
			if float(b.h) <= 0.0:
				b.h = 0.0
				if float(b.vh) < -40.0:
					b.vh = -float(b.vh) * 0.3   # a bounce
					b.w = float(b.w) * 0.5
				else:
					b.vh = 0.0
					b.v = Vector2.ZERO
					b.w = 0.0
		_bark_cd -= delta
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p and p.visible and _bark_cd <= 0.0:
			var rel := p.global_position - global_position
			var along := rel.dot(axis)
			var across := absf(rel.dot(axis.orthogonal()))
			# only when she really tries to leave: pressed against the arm and
			# still pushing into it for a moment - never just walking past
			var vel: Vector2 = p.get("velocity") if p.get("velocity") != null else Vector2.ZERO
			var n := axis.orthogonal() * signf(rel.dot(axis.orthogonal()))
			var pushing := along > -2.0 and along < span + 2.0 and across < 11.0 and vel.dot(-n) > 25.0
			_push_t = _push_t + delta if pushing else maxf(0.0, _push_t - delta * 2.0)
			if _push_t > 0.45:
				_push_t = 0.0
				_bark_cd = 7.0
				var done: bool = level != null and level.get("phase") == Level.Phase.ESCAPE
				var line: String = LINES[1] if done else LINES[0 if randf() < 0.5 else 2]
				var bl := BarkLayer.find(get_tree())
				if bl:
					bl.say(p, tr(line), 2.4, Color(1, 0.9, 0.8))
		queue_redraw()

	func _draw() -> void:
		# posts at both ends; the striped arm between them until the car goes
		# through it, then its pieces where they landed
		for e in [Vector2.ZERO, axis * span]:
			draw_rect(Rect2(e - Vector2(4, 4), Vector2(8, 8)), Color(0.15, 0.15, 0.18))
		draw_circle(Vector2.ZERO, 2.2, Color(1.0, 0.25, 0.2) if not broken else Color(0.3, 0.3, 0.3))
		if not broken:
			for k in 8:
				var a := axis * (span * k / 8.0)
				var b := axis * (span * (k + 1) / 8.0)
				draw_line(a, b, Color(0.95, 0.9, 0.85) if k % 2 == 0 else Color(0.85, 0.1, 0.12), 3.0)
			draw_circle(axis * span, 1.6, Color(1.0, 0.3, 0.2, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)))
		else:
			draw_line(Vector2.ZERO, axis * 5.0, Color(0.95, 0.9, 0.85), 3.0)   # the stub left on the hinge
		for b in _bits:
			var h: float = b.h
			var c: Vector2 = b.p
			var d := Vector2.from_angle(float(b.r)).rotated(axis.angle()) * float(b.len) * 0.5
			if h > 0.5:
				draw_line(c - d + Vector2(3, 3), c + d + Vector2(3, 3), Color(0, 0, 0, 0.3), 3.0)
			var lift := Vector2(0, -h * 0.25)
			draw_line(c - d + lift, c + d + lift, Color(0.95, 0.9, 0.85) if b.stripe else Color(0.85, 0.1, 0.12), 3.0 + h * 0.02)


## The road in and out: asphalt with kerbs and a dashed centre line, laid
## along the car's routes under the level's own floor - so beyond the gates
## the lot has somewhere to come from.
class ApproachRoad extends Node2D:
	var car: Node

	func _draw() -> void:
		for route in [car.route_in, car.route_out]:
			if route.size() < 2:
				continue
			var pts := PackedVector2Array(route)
			draw_polyline(pts, Color(0.28, 0.26, 0.3), 58.0, true)          # kerb
			draw_polyline(pts, Color(0.09, 0.085, 0.11), 50.0, true)        # tarmac
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var L := a.distance_to(b)
				var d := (b - a) / maxf(L, 0.01)
				var t := 0.0
				while t < L:
					draw_line(a + d * t, a + d * minf(t + 10.0, L), Color(0.85, 0.7, 0.25, 0.7), 2.0)
					t += 22.0
