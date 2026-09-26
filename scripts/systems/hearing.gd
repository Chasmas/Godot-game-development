class_name Hearing
extends RefCounted
## Cheap sound propagation for AI.
##
##   noise(pos, radius, kind)  ->  each listener asks Hearing.perceive():
##     effective radius = radius * Tuning.noise_scale * listener hearing
##                        * wall_attenuation ^ walls * door_attenuation ^ doors
##     inside sure_hearing_fraction of it: always heard
##     beyond: the chance falls off smoothly to 0 at the edge
##   The listener gets an *estimate* of where the sound came from, off by an
##   error that grows with distance and with every wall in the way. Nobody
##   learns the player's exact position from a sound; they have to look.
##
## Occluders are counted with a few ray casts that step through bodies
## (excluding each one hit), capped by Tuning.max_occluders.

class Result:
	var heard := false
	var strength := 0.0        ## 1 = right next to it, 0 = at the edge of hearing
	var estimate := Vector2.ZERO
	var walls := 0
	var doors := 0

## Kinds that carry through walls normally. Soft kinds (steps, scuffles)
## are only heard with a clear line when Tuning.soft_noise_needs_line.
const SOFT_KINDS := [&"step", &"scuffle"]

static func perceive(listener: Node2D, pos: Vector2, radius: float, kind: StringName, hearing_mult: float) -> Result:
	var t := Tuning.get_t()
	var res := Result.new()
	var d := listener.global_position.distance_to(pos)
	var r := radius * t.noise_scale * hearing_mult
	if kind == &"alarm":
		r = radius   # building alarms are wired to every room
	if d > r:
		return res
	if kind != &"alarm":
		_count_occluders(listener, pos, res, t.max_occluders)
		if kind in SOFT_KINDS and t.soft_noise_needs_line and res.walls > 0:
			return res
		r *= pow(t.wall_attenuation, res.walls) * pow(t.door_attenuation, res.doors)
		if d > r:
			return res
	var k := d / maxf(r, 1.0)
	if k > t.sure_hearing_fraction:
		var chance := 1.0 - smoothstep(t.sure_hearing_fraction, 1.0, k)
		if randf() > chance:
			return res
	res.heard = true
	res.strength = clampf(1.0 - k, 0.0, 1.0)
	var err := clampf(d * t.position_error_fraction * (1.0 + res.walls * 0.8 + res.doors * 0.4), t.position_error_min, t.position_error_max)
	if kind == &"alarm":
		err = t.position_error_max
	res.estimate = pos + Vector2.from_angle(randf() * TAU) * randf_range(err * 0.35, err)
	return res

static func _count_occluders(listener: Node2D, pos: Vector2, res: Result, cap: int) -> void:
	var space := listener.get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	if listener is CollisionObject2D:
		exclude.append((listener as CollisionObject2D).get_rid())
	var last := Vector2.INF
	# wall runs are split into rectangles; two bodies hit within a tile of
	# each other are one physical wall (a corner or T-junction)
	for i in cap + 2:
		var q := PhysicsRayQueryParameters2D.create(listener.global_position, pos, Layers.WORLD | Layers.DOOR, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return
		exclude.append(hit.rid)
		var hp: Vector2 = hit.position
		var col: Object = hit.collider
		var is_door := col is Node and (col as Node).is_in_group("door")
		if not is_door and last != Vector2.INF and hp.distance_to(last) < 18.0:
			last = hp
			continue
		last = hp
		if is_door:
			res.doors += 1
		else:
			res.walls += 1
		if res.walls + res.doors >= cap:
			return
