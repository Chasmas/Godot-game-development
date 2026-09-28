class_name WeaponPickup
extends Node2D
## A weapon lying on the floor or flying through the air after a throw.
## Thrown weapons stun/knock down, kill if bladed, break glass, and make noise.

const FRICTION := 900.0
const PICKUP_RADIUS := 16.0

var weapon: WeaponInstance
var velocity := Vector2.ZERO
var spin := 0.0
var thrower: Node = null
var thrown := false
var _hit_this_throw: Array = []
var sprite: Sprite2D
var _t := 0.0
var _exclude: Array[RID] = []

static func spawn(parent: Node, w: WeaponInstance, pos: Vector2, vel := Vector2.ZERO, by: Node = null) -> WeaponPickup:
	var p := WeaponPickup.new()
	p.weapon = w
	p.position = pos
	p.velocity = vel
	p.thrower = by
	p.thrown = vel.length() > 80.0
	p.rotation = randf() * TAU
	if p.thrown:
		p.spin = 22.0 * (1.0 if randf() > 0.5 else -1.0)
	parent.add_child(p)
	return p

func _ready() -> void:
	add_to_group("pickups")
	z_index = -2
	sprite = Sprite2D.new()
	var sk: String = weapon.data.sprite_key if weapon and weapon.data else "pistol"
	sprite.texture = SpriteLib.weapon_side(sk)   # on the floor: the side view
	sprite.scale = Vector2.ONE / SpriteLib.weapon_density(sk)
	sprite.light_mask = 2
	add_child(sprite)
	if thrower is CollisionObject2D:
		_exclude.append((thrower as CollisionObject2D).get_rid())

func can_pick_up() -> bool:
	return not thrown and velocity.length() < 60.0

func _physics_process(delta: float) -> void:
	_t += delta
	if velocity.length() < 1.0:
		velocity = Vector2.ZERO
		if thrown:
			thrown = false
			z_index = -2
		# gentle pulse so weapons read on busy floors
		sprite.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.5, 1.2), 0.5 + 0.5 * sin(_t * 5.0))
		return
	var step := velocity * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step + step.normalized() * 3.0, Layers.THROW_MASK, _exclude)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col and col.has_method("take_damage") and thrown and not _hit_this_throw.has(col):
			_hit_this_throw.append(col)
			var info := DamageInfo.make(DamageInfo.Type.THROWN, thrower if is_instance_valid(thrower) else null, hit.position, velocity, weapon.data.id, &"thrown")
			info.lethal = weapon.data.throw_lethal
			info.knockback = 160.0
			var r := str(col.take_damage(info))
			if r == "pass":
				_exclude.append(hit.rid)
				position += step
				return
			Audio.play_at(weapon.data.sfx_hit if weapon.data.throw_lethal else "hit_blunt", hit.position)
			if weapon.data.id == &"bottle":
				_shatter()
				return
		else:
			Audio.play_at("metal_clang" if weapon.data.is_firearm() else "hit_blunt", hit.position, -8.0)
			Events.noise.emit(hit.position, 140.0, &"thrown", self)
			if weapon.data.id == &"bottle" and velocity.length() > 250.0:
				_shatter()
				return
		global_position = hit.position + hit.normal * 2.0
		velocity = velocity.bounce(hit.normal) * 0.35
		spin *= -0.5
		thrown = velocity.length() > 160.0
	else:
		position += step
	rotation += spin * delta
	spin = move_toward(spin, 0.0, delta * 30.0)
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta * (0.5 if thrown else 1.4))
	if thrown and velocity.length() < 160.0:
		thrown = false

func _shatter() -> void:
	Audio.play_at("bottle_break", global_position)
	Effects.glass(global_position, velocity.normalized())
	queue_free()

## Nearest pickup the player can grab.
static func nearest(from: Vector2, tree: SceneTree, radius := PICKUP_RADIUS) -> WeaponPickup:
	var best: WeaponPickup = null
	var bd := radius
	for n in tree.get_nodes_in_group("pickups"):
		var p := n as WeaponPickup
		if p == null or not p.can_pick_up():
			continue
		var d := p.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = p
	return best
