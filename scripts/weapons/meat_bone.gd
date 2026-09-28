class_name MeatBone
extends Node2D
## A bone with meat on it. Thrown, it skids to a stop and every dog that
## catches the smell (close by, not already chewing on her) trots over and
## eats for a minute - ignoring Cass the whole time. Hurt one and it's over.

const EAT_TIME := 60.0
const SMELL_RADIUS := 200.0

var velocity := Vector2.ZERO
var left := EAT_TIME
var _landed := false
var _rot := 0.0
var _spin := 0.0
var eaters: Array = []

## Levels with dogs get a couple of bones lying about: one soon after the
## start, one further in (spread along the navigation grid).
static func place_for(level: Node2D, start: Vector2) -> void:
	var dogs := level.get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Dog)
	var nav: AStarGrid2D = level.get("nav")
	if dogs.is_empty() or nav == null:
		return
	var a := Vector2i(int(start.x / 16.0), int(start.y / 16.0))
	var r := nav.region
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var cands: Array = []
	for i in 140:
		var c := Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 2), rng.randi_range(r.position.y + 1, r.end.y - 2))
		if nav.is_point_solid(c):
			continue
		var n := nav.get_id_path(a, c).size()
		if n > 0:
			cands.append([n, c])
	if cands.is_empty():
		return
	cands.sort_custom(func(x, y): return x[0] < y[0])
	for want in [8, int(cands[-1][0] * 0.5)]:
		var best: Array = cands[0]
		for cd in cands:
			if absi(int(cd[0]) - want) < absi(int(best[0]) - want):
				best = cd
		var pk := Pickup.new()
		pk.position = Vector2(best[1]) * 16.0 + Vector2(8, 8)
		level.add_child(pk)

func _ready() -> void:
	add_to_group("meat_bones")
	z_index = 3
	_spin = randf_range(-14.0, 14.0)

func _physics_process(delta: float) -> void:
	if velocity.length() > 5.0:
		var space := get_world_2d().direct_space_state
		var step := velocity * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step, Layers.WORLD | Layers.DOOR | Layers.GLASS | Layers.PROP)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			position += step
		else:
			global_position = hit.position + hit.normal * 2.0
			velocity = velocity.bounce(hit.normal) * 0.3
		velocity = velocity.move_toward(Vector2.ZERO, 520.0 * delta)
		_rot += _spin * delta * velocity.length() / 300.0
	elif not _landed:
		_landed = true
		Audio.play_at("splat", global_position, -10.0, 0.1)
		_call_dogs()
	else:
		eaters = eaters.filter(func(d): return is_instance_valid(d) and d.is_alive() and d.is_eating(self))
		if not eaters.is_empty():
			left -= delta
		if left <= 0.0:
			for d in eaters:
				d.stop_eating()
			queue_free()
	queue_redraw()

func _call_dogs() -> void:
	for d in get_tree().get_nodes_in_group("enemies"):
		if d is Dog and d.is_alive() and d.global_position.distance_to(global_position) < SMELL_RADIUS:
			if d.lure(self):
				eaters.append(d)
	if eaters.is_empty():
		Events.hint.emit(tr("NO DOG CLOSE ENOUGH TO SMELL IT"), 1.4)
	else:
		Events.hint.emit(tr("DINNER TIME"), 1.2)

func _draw() -> void:
	var k := clampf(left / EAT_TIME, 0.0, 1.0)   # meat gets eaten away
	draw_bone(self, _rot, k)


## The painted sprites (tools/gen_meat_bone.py): the full bone, and the one
## picked clean that shows through as the dogs eat. Cached: a texture held
## only by a local in _draw gets freed.
static var _tex_full: Texture2D
static var _tex_eaten: Texture2D
const SPRITE_SCALE := 0.3

static func draw_bone(ci: CanvasItem, rot: float, meat: float) -> void:
	if _tex_full == null:
		_tex_full = load("res://assets/art/props/meat_bone.png")
		_tex_eaten = load("res://assets/art/props/meat_bone_eaten.png")
	ci.draw_set_transform(Vector2(1, 2), rot, Vector2(1, 0.6))
	ci.draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.3))
	ci.draw_set_transform(Vector2.ZERO, rot, Vector2(SPRITE_SCALE, SPRITE_SCALE))
	var off := -_tex_full.get_size() * 0.5
	if meat < 1.0:
		ci.draw_texture(_tex_eaten, off)
	if meat > 0.02:
		ci.draw_texture(_tex_full, off, Color(1, 1, 1, clampf(meat * 1.3, 0.0, 1.0)))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## On the floor, waiting to be picked up.
class Pickup extends Node2D:
	var _t := 0.0
	func _ready() -> void:
		z_index = 3
		add_to_group("meat_bone_pickups")
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p and p.visible and p.global_position.distance_to(global_position) < 10.0 and p.get("bones") != null:
			p.bones += 1
			Audio.play("pickup")
			Events.tutorial.emit("bone")
			queue_free()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 9.0 + sin(_t * 3.0), Color(1, 0.55, 0.35, 0.1))
		MeatBone.draw_bone(self, 0.35 + sin(_t * 1.5) * 0.05, 1.0)
