class_name ExplosiveTank
extends StaticBody2D
## Propane tank / gas can. Shoot it, it goes up. Chains into other tanks.
## Kills count as ENVIRONMENT/EXPLOSION when the player lit the fuse.

const RADIUS := 58.0

var hit_radius := 6.0
var exploded := false
var _fuse := -1.0
var _player_caused := false

func _ready() -> void:
	add_to_group("damageable")
	collision_layer = Layers.PROP
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	cs.shape = c
	add_child(cs)

func hit_point(_from: Vector2) -> Vector2:
	return global_position

func take_damage(info: DamageInfo) -> String:
	if exploded:
		return "pass"
	if info.type in [DamageInfo.Type.BALLISTIC, DamageInfo.Type.EXPLOSIVE, DamageInfo.Type.FIRE] or info.heavy:
		_player_caused = info.from_player or bool(info.get_meta("player_caused", false))
		if _fuse < 0.0:
			_fuse = 0.12 if info.type == DamageInfo.Type.EXPLOSIVE else 0.35
			Audio.play_at("spark", global_position)
		return "blocked"
	return "blocked"

func _physics_process(delta: float) -> void:
	if _fuse >= 0.0 and not exploded:
		_fuse -= delta
		queue_redraw()
		if _fuse <= 0.0:
			explode()

func explode() -> void:
	if exploded:
		return
	exploded = true
	collision_layer = 0
	Audio.play_at("explosion", global_position, 3.0)
	Effects.explosion(global_position, RADIUS)
	Events.camera_shake.emit(10.0)
	Events.hit_stop.emit(0.06)
	Events.noise.emit(global_position, 800.0, &"explosion", self)
	InputSetup.vibrate(1.0, 1.0, 0.35)
	blast(self, global_position, RADIUS, _player_caused)
	queue_redraw()
	await get_tree().create_timer(0.1).timeout
	queue_free()

## Shared blast logic (also used by grenades etc.).
static func blast(src: Node2D, pos: Vector2, radius: float, player_caused: bool) -> void:
	var space := src.get_world_2d().direct_space_state
	for n in src.get_tree().get_nodes_in_group("damageable"):
		if n == src or not is_instance_valid(n) or not (n is Node2D):
			continue
		var p: Vector2 = (n as Node2D).global_position
		var d := p.distance_to(pos)
		if d > radius:
			continue
		var q := PhysicsRayQueryParameters2D.create(pos, p, Layers.WORLD, [])
		if not space.intersect_ray(q).is_empty() and d > 20.0:
			continue
		var info := DamageInfo.make(DamageInfo.Type.EXPLOSIVE, src, p, p - pos, &"explosion", &"explosion")
		info.lethal = true
		info.heavy = true
		info.knockback = 260.0
		info.set_meta("player_caused", player_caused)
		n.take_damage(info)
	var pl := src.get_tree().get_first_node_in_group("player") as Player
	if pl and pl.alive and pl.global_position.distance_to(pos) < radius * 0.85:
		var info2 := DamageInfo.make(DamageInfo.Type.EXPLOSIVE, src, pl.global_position, pl.global_position - pos, &"explosion", &"explosion")
		pl.take_damage(info2)

func _draw() -> void:
	if exploded:
		return
	draw_circle(Vector2.ZERO, 5.0, Color(0.06, 0.03, 0.08))
	draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.85, 0.8) if _fuse < 0.0 else Color(1, 0.4 + 0.6 * absf(sin(_fuse * 60.0)), 0.2))
	draw_rect(Rect2(-1.5, -1.5, 3, 3), Color(0.8, 0.1, 0.1))
