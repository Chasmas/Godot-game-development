class_name BulletSystem
extends Node2D
## Pooled, ray-swept projectile simulation. One node draws every bullet, so
## hundreds of pellets cost one draw pass. Supports physical projectiles,
## hitscan, pellets, penetration and ricochets.

const MAX_BULLETS := 400

class Bullet:
	var pos: Vector2
	var vel: Vector2
	var dist_left: float
	var pen: int
	var ric: int
	var weapon: WeaponData
	var shooter: Node
	var exclude: Array[RID] = []
	var from_player := false
	var group := -1
	var color := Color.WHITE
	var trail: Vector2

var bullets: Array[Bullet] = []
var tracers: Array = []   # [from, to, color, life]
var _groups: Dictionary = {}   # id -> {left, hit, weapon_id}
var _next_group := 0

static func get_system() -> BulletSystem:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("bullets") as BulletSystem if tree else null

func _ready() -> void:
	add_to_group("bullets")
	z_index = 15

## Fire a weapon's full shot (all pellets). Returns nothing; results via signals.
func fire(origin: Vector2, dir: Vector2, weapon: WeaponData, shooter: Node, spread_deg: float) -> void:
	var from_player := shooter != null and shooter.is_in_group("player")
	var gid := -1
	if from_player:
		gid = _next_group
		_next_group += 1
		_groups[gid] = {"left": weapon.pellets, "hit": false, "weapon_id": weapon.id}
	for i in weapon.pellets:
		var ang := deg_to_rad(randf_range(-spread_deg, spread_deg) * 0.5)
		if weapon.pellets > 1:
			ang = deg_to_rad(lerpf(-spread_deg * 0.5, spread_deg * 0.5, (i + randf()) / weapon.pellets))
		var d := dir.rotated(ang)
		var b := Bullet.new()
		b.pos = origin
		b.trail = origin
		var speed := weapon.bullet_speed * (randf_range(0.85, 1.1) if weapon.pellets > 1 else 1.0)
		b.vel = d * speed
		b.dist_left = weapon.max_range * (randf_range(0.8, 1.0) if weapon.pellets > 1 else 1.0)
		b.pen = weapon.penetration
		b.ric = weapon.ricochet
		b.weapon = weapon
		b.shooter = shooter
		b.from_player = from_player
		b.group = gid
		b.color = weapon.tracer_color
		if shooter is CollisionObject2D:
			b.exclude.append((shooter as CollisionObject2D).get_rid())
		if weapon.hitscan:
			_simulate(b, b.dist_left)
		elif bullets.size() < MAX_BULLETS:
			bullets.append(b)
		else:
			_resolve_group(b.group, false)

func _physics_process(delta: float) -> void:
	if bullets.is_empty() and tracers.is_empty():
		return
	var i := bullets.size() - 1
	while i >= 0:
		var b := bullets[i]
		var step := b.vel.length() * delta
		b.trail = b.pos
		if not _simulate(b, step):
			bullets.remove_at(i)
		i -= 1
	var j := tracers.size() - 1
	while j >= 0:
		tracers[j][3] -= delta
		if tracers[j][3] <= 0.0:
			tracers.remove_at(j)
		j -= 1
	queue_redraw()

## Advance bullet by `step` pixels. Returns false when the bullet is done.
func _simulate(b: Bullet, step: float) -> bool:
	var space := get_world_2d().direct_space_state
	var remaining := minf(step, b.dist_left)
	var guard := 0
	while remaining > 0.01 and guard < 8:
		guard += 1
		var dir := b.vel.normalized()
		var to := b.pos + dir * remaining
		var q := PhysicsRayQueryParameters2D.create(b.pos, to, Layers.BULLET_MASK, b.exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			b.dist_left -= remaining
			b.pos = to
			remaining = 0.0
			break
		var hp: Vector2 = hit.position
		var travelled := b.pos.distance_to(hp)
		remaining -= travelled
		b.dist_left -= travelled
		if b.weapon.hitscan:
			tracers.append([b.pos, hp, b.color, 0.08])
		b.pos = hp
		var col: Object = hit.collider
		var result := "wall"
		if col and col.has_method("take_damage"):
			var info := DamageInfo.make(DamageInfo.Type.BALLISTIC, b.shooter if is_instance_valid(b.shooter) else null, hp, dir, b.weapon.id, &"gun")
			info.amount = b.weapon.damage
			info.knockback = b.weapon.knockback
			result = str(col.take_damage(info))
		if b.shooter is Player and (result == "killed" or result == "hurt"):
			# hit confirm: a beat of weight when the player's shot lands
			Events.camera_shake.emit(1.6 if result == "killed" else 0.7)
			Events.hit_stop.emit(0.04 if result == "killed" else 0.015)
		match result:
			"killed", "hurt", "absorbed":
				_resolve_group(b.group, true)
				if b.pen > 0:
					b.pen -= 1
					b.exclude.append(hit.rid)
					continue
				return false
			"pass":
				# glass, weak doors: keep flying
				b.exclude.append(hit.rid)
				continue
			"blocked":
				Effects.sparks(hp, hit.normal)
				Audio.play_at("ricochet", hp, -10.0)
				_resolve_group(b.group, false)
				return false
			_:
				if b.ric > 0:
					b.ric -= 1
					b.vel = b.vel.bounce(hit.normal)
					b.pos = hp + hit.normal * 0.5
					Effects.sparks(hp, hit.normal)
					Audio.play_at("ricochet", hp, -6.0)
					continue
				if b.pen > 0 and col is StaticBody2D and (col as Node).is_in_group("door"):
					b.pen -= 1
					b.exclude.append(hit.rid)
					continue
				Effects.bullet_impact(hp, hit.normal)
				_resolve_group(b.group, false)
				return false
	if b.dist_left <= 0.01:
		_resolve_group(b.group, false)
		return false
	return true

func _resolve_group(gid: int, hit: bool) -> void:
	if gid < 0 or not _groups.has(gid):
		return
	var g: Dictionary = _groups[gid]
	if hit:
		g.hit = true
	g.left -= 1
	if g.left <= 0 or hit:
		if g.left <= 0 or g.hit:
			Events.player_fired.emit(g.weapon_id, g.hit)
			_groups.erase(gid)

func _draw() -> void:
	for b in bullets:
		var tail := b.pos - b.vel.normalized() * minf(10.0, b.pos.distance_to(b.trail) + 4.0)
		draw_line(tail, b.pos, Color(b.color, 0.35), 3.0)
		draw_line(tail, b.pos, b.color, 1.2)
	for t in tracers:
		var a: float = clampf(t[3] / 0.08, 0.0, 1.0)
		draw_line(t[0], t[1], Color(t[2], a), 1.5)
