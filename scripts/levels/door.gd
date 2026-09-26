class_name Door
extends Node2D
## Swinging door. Characters push it open just by walking into it; kicks
## and dashes slam it hard enough to knock people down on the far side.
## The leaf blocks bullets and sight; it can be shot apart.

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
var _slammer_is_player := false
var _knocked: Array = []
var _sound_cd := 0.0
var leaf: StaticBody2D
var _shape: CollisionShape2D

func setup(hinge: Vector2, p_length: float, p_closed_angle: float, p_locked := false) -> void:
	position = hinge
	length = p_length
	closed_angle = p_closed_angle
	locked = p_locked

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
	if absf(omega) > 0.01:
		swing += omega * delta
		if absf(swing) > MAX_SWING:
			swing = clampf(swing, -MAX_SWING, MAX_SWING)
			if absf(omega) > SLAM_SPEED * 0.6 and _sound_cd <= 0.0:
				Audio.play_at("door_slam", global_position, -6.0)
				_sound_cd = 0.2
			omega = -omega * 0.25
		omega *= exp(-3.2 * delta)
		if absf(omega) > SLAM_SPEED:
			_sweep_hits()
		else:
			_knocked.clear()
		_apply()

func _push_from_bodies(delta: float) -> void:
	var a := leaf_dir()
	for group in ["player", "enemies"]:
		for b in get_tree().get_nodes_in_group(group):
			var body := b as CharacterBody2D
			if body == null:
				continue
			if body.has_method("is_alive") and not body.is_alive():
				continue
			if body is Player and not (body as Player).alive:
				continue
			var rel := body.global_position - global_position
			if rel.length() > length + 8.0:
				continue
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
					_play_slam()
				elif speed > 20.0 and absf(omega) < 1.0 and _sound_cd <= 0.0:
					Audio.play_at("door_open", global_position, -10.0)
					Events.noise.emit(global_position, 70.0, &"door", body)
					_sound_cd = 0.6
					_slammer_is_player = body is Player
				elif body is Player:
					_slammer_is_player = true

func kick(from: Vector2, dir: Vector2) -> bool:
	if broken:
		return false
	var rel := from - global_position
	if (hit_point(from) - from).length() > 26.0:
		return false
	if locked:
		Audio.play_at("door_slam", global_position, -4.0)
		Events.hint.emit("LOCKED", 0.8)
		Events.noise.emit(global_position, 200.0, &"door", null)
		return true
	var a := leaf_dir()
	var side := signf(a.cross(rel)) if a.cross(rel) != 0.0 else 1.0
	omega = side * 17.0
	_slammer_is_player = true
	_play_slam()
	return true

func _play_slam() -> void:
	if _sound_cd <= 0.0:
		Audio.play_at("door_slam", global_position)
		Events.noise.emit(global_position, 260.0, &"door", null)
		_sound_cd = 0.25

func _sweep_hits() -> void:
	var a := leaf_dir()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or _knocked.has(e):
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
			info.knockback = 220.0
			info.from_player = _slammer_is_player
			e.take_damage(info)
			Audio.play_at("hit_blunt", e.global_position)
			Events.hit_stop.emit(0.05)
			Events.camera_shake.emit(3.0)

func take_damage(info: DamageInfo) -> String:
	if broken:
		return "pass"
	match info.type:
		DamageInfo.Type.MELEE, DamageInfo.Type.PUNCH:
			if locked:
				hp -= 1 if info.heavy else 0
			else:
				var side := signf(leaf_dir().cross(info.pos - info.dir * 10.0 - global_position))
				omega = side * (15.0 if info.heavy else 9.0)
				_slammer_is_player = info.from_player
				_play_slam()
			if hp <= 0:
				_break(info.dir)
			return "hurt"
		DamageInfo.Type.EXPLOSIVE:
			_break(info.dir)
			return "hurt"
		DamageInfo.Type.BALLISTIC:
			hp -= 1
			Effects.debris(info.pos, -info.dir)
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
		Effects.debris(global_position + leaf_dir() * length * (i + 0.5) / 3.0, dir)
	Events.noise.emit(global_position, 260.0, &"door", null)
	queue_redraw()

func unlock() -> void:
	locked = false

func _draw() -> void:
	if broken:
		for i in 4:
			var p := Vector2.from_angle(closed_angle + swing) * (i * 8.0 + 3.0) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			draw_rect(Rect2(p, Vector2(4, 2)), Color(0.35, 0.2, 0.1))
		return
	var a := closed_angle + swing
	var dir := Vector2.from_angle(a)
	var n := dir.orthogonal()
	var end := dir * length
	var wood := Color(0.62, 0.36, 0.18) if not locked else Color(0.45, 0.46, 0.52)
	var pts := PackedVector2Array([n * 1.8, end + n * 1.8, end - n * 1.8, -n * 1.8])
	draw_colored_polygon(pts, wood)
	draw_polyline(PackedVector2Array([n * 1.8, end + n * 1.8, end - n * 1.8, -n * 1.8, n * 1.8]), Color(0.08, 0.04, 0.06), 1.0)
	draw_circle(dir * (length - 5.0) + n * 2.2, 1.2, Color(0.95, 0.8, 0.3))
	draw_circle(Vector2.ZERO, 2.0, Color(0.1, 0.08, 0.1))


class DoorLeaf extends StaticBody2D:
	var door: Door
	func take_damage(info: DamageInfo) -> String:
		return door.take_damage(info) if is_instance_valid(door) else "pass"
