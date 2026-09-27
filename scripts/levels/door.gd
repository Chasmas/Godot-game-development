class_name Door
extends Node2D
## Swinging door. Characters push it open just by walking into it; kicks
## and dashes slam it hard enough to knock people down on the far side.
## The leaf blocks bullets and sight; it can be shot apart.
##
## Motion is a damped hinge: an impulse sets angular speed, then linear
## friction plus quadratic drag bleed it off (a kicked door flies, then
## slows naturally instead of turning at a constant rate). The leaf stops
## against the hinge limit *and* against walls (ray along the leaf), bouncing
## with a little restitution and a visible rattle. Tuning values: Tuning.

const SLAM_SPEED := 6.5
const MAX_SWING := deg_to_rad(105.0)

var length := 32.0
var closed_angle := 0.0        # direction the leaf points when closed (from hinge)
var swing := 0.0
var omega := 0.0
var locked := false
var hp := 5
var broken := false
var hit_radius := 12.0
var metal := false             ## locked/security doors are steel: clang, sparks
var _slammer_is_player := false
var _knocked: Array = []
var _sound_cd := 0.0
var _rattle := 0.0
var _rattle_t := 0.0
var _handle := 0.0             ## handle droop when pushed/kicked, springs back
var leaf: StaticBody2D
var _shape: CollisionShape2D
var _near: Array = []

func setup(hinge: Vector2, p_length: float, p_closed_angle: float, p_locked := false) -> void:
	position = hinge
	length = p_length
	closed_angle = p_closed_angle
	locked = p_locked
	metal = p_locked

func _ready() -> void:
	add_to_group("door")
	add_to_group("damageable")
	leaf = DoorLeaf.new()
	leaf.door = self
	leaf.collision_layer = Layers.DOOR
	leaf.collision_mask = 0
	leaf.add_to_group("door")
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(length - 2.0, 3.0)
	_shape.shape = r
	_shape.position = Vector2(length * 0.5, 0)
	leaf.add_child(_shape)
	add_child(leaf)
	z_index = 3
	light_mask = 2
	_apply()

func hit_point(from: Vector2) -> Vector2:
	var a := leaf_dir()
	var rel := from - global_position
	var t := clampf(rel.dot(a), 0.0, length)
	return global_position + a * t

func leaf_dir() -> Vector2:
	return Vector2.from_angle(closed_angle + swing)

func _apply() -> void:
	leaf.rotation = closed_angle + swing
	queue_redraw()

func _physics_process(delta: float) -> void:
	if broken:
		return
	_sound_cd = maxf(0.0, _sound_cd - delta)
	if not locked:
		_push_from_bodies(delta)
	if _rattle > 0.0 or _handle > 0.0:
		_rattle = maxf(0.0, _rattle - delta * 2.4)
		_handle = maxf(0.0, _handle - delta * 3.0)
		_rattle_t += delta
		queue_redraw()
	if absf(omega) > 0.01:
		_integrate(delta)
		if absf(omega) > SLAM_SPEED:
			_sweep_hits()
		else:
			_knocked.clear()
		_apply()

func _integrate(delta: float) -> void:
	var t := Tuning.get_t()
	var prev := swing
	swing += omega * delta
	var stopped := false
	if absf(swing) > MAX_SWING:
		swing = clampf(swing, -MAX_SWING, MAX_SWING)
		stopped = true
	elif _leaf_blocked():
		# the leaf hit a wall before its hinge limit: stop there, don't clip.
		# Only if it was free a step ago, so a door that starts touching
		# something can never be pinned shut by this check.
		var now := swing
		swing = prev
		if _leaf_blocked():
			swing = now
		else:
			stopped = true
	if stopped:
		var impact := absf(omega)
		if impact > SLAM_SPEED * 0.6 and _sound_cd <= 0.0:
			Audio.play_at("metal_clang" if metal else "door_slam", global_position, -6.0 + minf(impact - SLAM_SPEED, 6.0))
			_sound_cd = 0.2
			if impact > SLAM_SPEED * 1.5:
				Effects.dust(global_position + leaf_dir() * length, -leaf_dir(), 0.6)
		_rattle = maxf(_rattle, clampf(impact / 18.0, 0.0, 1.0) * t.door_rattle)
		omega = -omega * t.door_restitution
		if absf(omega) < 0.4:
			omega = 0.0
	# linear friction + quadratic air drag + hinge (static) friction, so a
	# swinging door actually stops instead of creeping forever
	omega -= (t.door_friction * omega + t.door_drag * omega * absf(omega)) * delta
	omega = move_toward(omega, 0.0, t.door_hinge_friction * delta)

## Ray along the leaf (from just off the hinge to the tip) against walls.
func _leaf_blocked() -> bool:
	var space := get_world_2d().direct_space_state
	var a := leaf_dir()
	var q := PhysicsRayQueryParameters2D.create(global_position + a * 5.0, global_position + a * (length - 1.0), Layers.WORLD | Layers.PROP)
	return not space.intersect_ray(q).is_empty()

func _push_from_bodies(delta: float) -> void:
	var a := leaf_dir()
	_near.clear()
	var crowd := Crowd.get_crowd(get_tree())
	if crowd:
		crowd.query(global_position, length + 8.0, _near)
	else:
		_near.append_array(get_tree().get_nodes_in_group("player"))
		_near.append_array(get_tree().get_nodes_in_group("enemies"))
	for b in _near:
		var body := b as CharacterBody2D
		if body == null or not is_instance_valid(body) or body.is_in_group("npcs"):
			continue
		if body.has_method("is_alive") and not body.is_alive():
			continue
		if body is Player and not (body as Player).alive:
			continue
		var rel := body.global_position - global_position
		var along := rel.dot(a)
		if along < -2.0 or along > length + 2.0:
			continue
		var perp := a.cross(rel)   # signed distance from leaf line
		var r := 7.0
		if absf(perp) < r:
			var overlap := r - absf(perp)
			var side := signf(perp) if perp != 0.0 else 1.0
			var lever := maxf(along, 4.0)
			var speed := body.velocity.length()
			var push := (overlap * 40.0 + speed * 0.9) / lever
			var before := omega
			omega -= side * push * delta * 60.0 * 0.1
			# walking opens doors briskly but never slams them
			if absf(omega) > 5.0 and absf(omega) > absf(before):
				omega = signf(omega) * maxf(absf(before), 5.0)
			var dashing := body is Player and (body as Player).is_dashing()
			if dashing:
				omega = -side * 16.0
				_slammer_is_player = true
				_handle = 1.0
				_play_slam()
			elif speed > 20.0 and absf(omega) < 1.0 and _sound_cd <= 0.0:
				Audio.play_at("door_open", global_position, -10.0)
				Events.noise.emit(global_position, 70.0, &"door", body)
				_sound_cd = 0.6
				_handle = 0.6
				_slammer_is_player = body is Player
			elif body is Player:
				_slammer_is_player = true

## Player kick. Returns true if this door took the kick. The kicker has to be
## on one side of the leaf, close, facing it, and with nothing solid between.
func kick(from: Vector2, dir: Vector2) -> bool:
	if broken:
		return false
	var hp_pos := hit_point(from)
	var to := hp_pos - from
	if to.length() > 26.0:
		return false
	var t := Tuning.get_t()
	if to.length() > 6.0 and absf(angle_difference(dir.angle(), to.angle())) > deg_to_rad(t.kick_max_angle_deg * 0.5):
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, hp_pos, Layers.WORLD | Layers.PROP)
	if not space.intersect_ray(q).is_empty():
		return false   # wall between the boot and the door
	var rel := from - global_position
	if locked:
		Audio.play_at("metal_clang" if metal else "door_slam", global_position, -4.0)
		Audio.play_at("hit_blunt", global_position, -6.0, 0.05)
		Events.hint.emit("LOCKED", 0.8)
		Events.noise.emit(global_position, 200.0, &"door", null)
		Events.camera_shake.emit(2.0)
		_rattle = 0.8
		_handle = 1.0
		Effects.dust(hp_pos, -to.normalized(), 0.5)
		return true
	var a := leaf_dir()
	var side := signf(a.cross(rel)) if a.cross(rel) != 0.0 else 1.0
	# positive omega swings the tip toward -orthogonal(leaf); the kicker is
	# on `side`, so the leaf must go the other way (-side), away from them.
	# (It used to be +side: kicked doors swung back at the player.)
	omega = -side * t.kick_speed
	_slammer_is_player = true
	_handle = 1.0
	# the boot lands on the leaf: splinters off the impact side, dust shaken
	# out of the frame at the hinge
	var push_dir := a.orthogonal() * side   # away from the kicker
	Effects.splinters(hp_pos, push_dir, not metal)
	Effects.dust(global_position, push_dir, 1.0)
	Audio.play_at("door_kick", global_position, 0.0, 0.06)
	Events.noise.emit(global_position, t.kick_noise, &"door", null)
	_sound_cd = 0.25
	Events.hit_stop.emit(0.045)
	Events.camera_shake.emit(5.0)
	Events.camera_nudge.emit(push_dir * 5.0)
	InputSetup.vibrate(0.7, 0.5, 0.14)
	return true

func _play_slam() -> void:
	if _sound_cd <= 0.0:
		Audio.play_at("door_slam", global_position)
		Events.noise.emit(global_position, 260.0, &"door", null)
		_sound_cd = 0.25

func _sweep_hits() -> void:
	var a := leaf_dir()
	_near.clear()
	var crowd := Crowd.get_crowd(get_tree())
	if crowd:
		crowd.query(global_position, length + 10.0, _near, &"enemies")
	else:
		_near.append_array(get_tree().get_nodes_in_group("enemies"))
	for e in _near:
		if not is_instance_valid(e) or not e.is_alive() or _knocked.has(e):
			continue
		var rel: Vector2 = (e as Node2D).global_position - global_position
		var along := rel.dot(a)
		if along < 0.0 or along > length + 4.0:
			continue
		if absf(a.cross(rel)) < 9.0:
			_knocked.append(e)
			var dir := a.orthogonal() * signf(omega)
			var info := DamageInfo.make(DamageInfo.Type.DOOR, get_tree().get_first_node_in_group("player") if _slammer_is_player else null, e.global_position, dir, &"door", &"door")
			info.lethal = false
			info.knockback = 240.0
			info.from_player = _slammer_is_player
			e.take_damage(info)
			Audio.play_at("hit_blunt", e.global_position)
			Effects.dust(e.global_position, dir, 0.5)
			Events.hit_stop.emit(0.06)
			Events.camera_shake.emit(4.0)
			# the leaf loses speed on the body it just flattened
			omega *= 0.6

func take_damage(info: DamageInfo) -> String:
	if broken:
		return "pass"
	match info.type:
		DamageInfo.Type.MELEE, DamageInfo.Type.PUNCH:
			if locked:
				hp -= 1 if info.heavy else 0
				_rattle = 0.6
			else:
				var side := signf(leaf_dir().cross(info.pos - info.dir * 10.0 - global_position))
				omega = -side * (15.0 if info.heavy else 9.0)   # away from the attacker
				_slammer_is_player = info.from_player
				_handle = 0.8
				_play_slam()
			if hp <= 0:
				_break(info.dir)
			return "hurt"
		DamageInfo.Type.EXPLOSIVE:
			_break(info.dir)
			return "hurt"
		DamageInfo.Type.BALLISTIC:
			hp -= 1
			_rattle = maxf(_rattle, 0.35)
			if metal:
				Effects.sparks(info.pos, -info.dir)
			else:
				Effects.splinters(info.pos, -info.dir, true, 0.5)
			if hp <= 0:
				_break(info.dir)
				return "pass"
			return "blocked" if not info.weapon_id in [&"rifle", &"revolver", &"hotshot"] else "pass"
	return "blocked"

func _break(dir: Vector2) -> void:
	broken = true
	leaf.collision_layer = 0
	remove_from_group("damageable")
	Audio.play_at("door_break", global_position)
	for i in 3:
		Effects.splinters(global_position + leaf_dir() * length * (i + 0.5) / 3.0, dir, not metal)
	Effects.dust(global_position + leaf_dir() * length * 0.5, dir, 1.2)
	Events.noise.emit(global_position, 260.0, &"door", null)
	queue_redraw()

func unlock() -> void:
	locked = false

## Something slams it shut from the other side and holds it (the dream).
func slam_shut(hold := 4.0) -> void:
	if broken:
		return
	swing = 0.0
	omega = 0.0
	_apply()
	_rattle = 1.0
	_play_slam()
	var was := locked
	locked = true
	get_tree().create_timer(hold, false).timeout.connect(func():
		if is_instance_valid(self):
			locked = was)

func _draw() -> void:
	if broken:
		# splintered stump on the hinge + a few boards on the floor (seeded so
		# they don't dance every redraw)
		var rng := RandomNumberGenerator.new()
		rng.seed = get_instance_id()
		var stub := Vector2.from_angle(closed_angle + swing)
		draw_line(Vector2.ZERO, stub * 5.0, Color(0.42, 0.24, 0.12), 3.0)
		for i in 4:
			var p := stub * (i * 8.0 + 3.0) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			draw_set_transform(p, rng.randf_range(-1.0, 1.0), Vector2.ONE)
			draw_rect(Rect2(-2, -1, 4 + rng.randf_range(0, 3), 2), Color(0.35, 0.2, 0.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var shake := sin(_rattle_t * 70.0) * _rattle * 0.035
	var a := closed_angle + swing + shake
	var dir := Vector2.from_angle(a)
	var n := dir.orthogonal()
	var end := dir * length
	var base := Color(0.62, 0.36, 0.18) if not metal else Color(0.45, 0.46, 0.52)
	var dark := base.darkened(0.35)
	var pts := PackedVector2Array([n * 1.8, end + n * 1.8, end - n * 1.8, -n * 1.8])
	draw_colored_polygon(pts, base)
	# grain / panel lines and a darker hinge-side edge give the leaf some depth
	if not metal:
		draw_line(dir * 3.0 + n * 0.6, end - dir * 3.0 + n * 0.6, base.lightened(0.12), 0.6)
		draw_line(dir * 3.0 - n * 0.7, end - dir * 3.0 - n * 0.7, dark, 0.6)
	else:
		for k in 3:
			var p := dir * (length * (k + 1) / 4.0)
			draw_line(p + n * 1.6, p - n * 1.6, dark, 0.6)
	draw_line(n * 1.8, -n * 1.8, dark, 1.4)
	draw_polyline(PackedVector2Array([n * 1.8, end + n * 1.8, end - n * 1.8, -n * 1.8, n * 1.8]), Color(0.08, 0.04, 0.06), 1.0)
	# handle on both faces; it droops when the door is shoved and springs back
	var hpos := dir * (length - 5.0)
	var droop := dir * (-_handle * 1.2)
	var brass := Color(0.95, 0.8, 0.3) if not metal else Color(0.8, 0.82, 0.86)
	draw_line(hpos + n * 1.8, hpos + n * 2.8 + droop, brass, 1.0)
	draw_line(hpos - n * 1.8, hpos - n * 2.8 + droop, brass, 1.0)
	draw_circle(Vector2.ZERO, 2.0, Color(0.1, 0.08, 0.1))
	draw_circle(Vector2.ZERO, 0.8, Color(0.55, 0.5, 0.45))


class DoorLeaf extends StaticBody2D:
	var door: Door
	func take_damage(info: DamageInfo) -> String:
		return door.take_damage(info) if is_instance_valid(door) else "pass"
