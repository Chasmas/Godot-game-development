class_name ExplosiveTank
extends StaticBody2D
## A red fuel drum. Shoot it, blow it up or beat on it and it goes up,
## killing whoever's close (and chaining into the next drum). Some have a
## lazy fire going on the lid - a warning and a light source. Kills count as
## ENVIRONMENT/EXPLOSION when the player lit the fuse.

const RADIUS := 58.0

var hit_radius := 7.0
var exploded := false
var burning := false          ## a small fire licking the lid
var _fuse := -1.0
var _player_caused := false
var _t := 0.0
var _seed := 0.0
var _dent := 0.0
var _knocks := 0
var _light: PointLight2D

func _ready() -> void:
	add_to_group("damageable")
	collision_layer = Layers.PROP
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 6.5
	cs.shape = c
	add_child(cs)
	# stable per spot: which drums are alight, how they're turned, their dents
	var h := absi(hash(Vector2i(int(position.x), int(position.y))))
	_seed = float(h % 1000) / 1000.0
	burning = h % 3 == 0
	rotation = _seed * TAU
	_dent = float((h >> 4) % 100) / 100.0
	if burning:
		_light = PointLight2D.new()
		_light.texture = SpriteLib.light_texture(128)
		_light.texture_scale = 0.9
		_light.color = Color(1.0, 0.55, 0.2)
		_light.energy = 0.9
		add_child(_light)

func hit_point(_from: Vector2) -> Vector2:
	return global_position

func take_damage(info: DamageInfo) -> String:
	if exploded:
		return "pass"
	_player_caused = info.from_player or bool(info.get_meta("player_caused", false))
	if info.type in [DamageInfo.Type.BALLISTIC, DamageInfo.Type.EXPLOSIVE, DamageInfo.Type.FIRE] or info.heavy:
		_light_fuse(0.12 if info.type == DamageInfo.Type.EXPLOSIVE else 0.35)
	else:
		# a punch or a blade: dents it; the second knock splits a seam
		_knocks += 1
		_dent = minf(1.0, _dent + 0.4)
		Audio.play_at("spark", global_position, -6.0)
		if _knocks >= 2:
			_light_fuse(0.9)
		queue_redraw()
	return "blocked"

func _light_fuse(t: float) -> void:
	if _fuse < 0.0:
		_fuse = t
		Audio.play_at("spark", global_position)

func _physics_process(delta: float) -> void:
	_t += delta
	if _light:
		_light.energy = 0.8 + 0.25 * sin(_t * 17.0) * sin(_t * 5.3 + _seed * 9.0)
	if _fuse >= 0.0 and not exploded:
		_fuse -= delta
		if _fuse <= 0.0:
			explode()
	if burning or _fuse >= 0.0:
		queue_redraw()

func explode() -> void:
	if exploded:
		return
	exploded = true
	collision_layer = 0
	Audio.play_at("explosion", global_position, 3.0)
	Effects.explosion(global_position, RADIUS)
	# the drum's own pieces: the lid spinning off, shards of red steel
	Effects.shards(global_position, Vector2.from_angle(randf() * TAU), Color(0.72, 0.12, 0.1), 14)
	Effects.shards(global_position, Vector2.from_angle(randf() * TAU), Color(0.25, 0.22, 0.24), 8)
	Events.camera_shake.emit(10.0)
	Events.hit_stop.emit(0.06)
	Events.noise.emit(global_position, 800.0, &"explosion", self)
	InputSetup.vibrate(1.0, 1.0, 0.35)
	blast(self, global_position, RADIUS, _player_caused)
	if _light:
		_light.queue_free()
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
	var ink := Color("0b0710")
	var red := Color(0.7, 0.12, 0.1)
	var j := Vector2.ZERO
	if _fuse >= 0.0:
		j = Vector2(sin(_t * 70.0), cos(_t * 63.0)) * 0.6   # rattling as it cooks off
	# shadow, then the drum seen from above: rolled rim, two ribs, the lid
	draw_circle(Vector2(1.5, 2.2), 7.4, Color(0, 0, 0, 0.35))
	draw_circle(j, 7.2, ink)
	draw_circle(j, 6.4, red.darkened(0.25))
	draw_arc(j, 6.0, 0, TAU, 28, red.lightened(0.15), 1.0)            # the rolled rim
	draw_arc(j, 4.6, 0, TAU, 24, red.darkened(0.45), 0.8)             # a rib
	draw_circle(j, 4.2, red)
	# a dent catching the light the wrong way
	var da := _seed * TAU
	draw_circle(j + Vector2.from_angle(da) * 4.8, 1.2 + _dent, red.darkened(0.5))
	# rust bloom and a chipped patch of paint
	draw_circle(j + Vector2.from_angle(da + 2.1) * 3.0, 1.3, Color(0.45, 0.22, 0.08, 0.8))
	draw_circle(j + Vector2.from_angle(da + 2.5) * 3.4, 0.7, Color(0.62, 0.34, 0.12, 0.8))
	# the two bungs: big fill cap and a small vent
	draw_circle(j + Vector2(-1.8, -1.2), 1.4, ink)
	draw_circle(j + Vector2(-1.8, -1.2), 1.0, Color(0.6, 0.6, 0.64))
	draw_circle(j + Vector2(2.4, 1.6), 0.8, ink)
	draw_circle(j + Vector2(2.4, 1.6), 0.5, Color(0.55, 0.55, 0.6))
	# hazard diamond: yellow with a black flame
	var hz := j + Vector2(1.2, -2.4)
	draw_colored_polygon(PackedVector2Array([hz + Vector2(0, -1.8), hz + Vector2(1.8, 0), hz + Vector2(0, 1.8), hz + Vector2(-1.8, 0)]), Color(1.0, 0.8, 0.15))
	draw_line(hz + Vector2(0, 0.9), hz + Vector2(0, -0.8), ink, 0.6)
	# highlight on the rim
	draw_arc(j, 6.2, PI * 1.05, PI * 1.45, 6, Color(1, 0.7, 0.6, 0.55), 0.8)
	if burning:
		_draw_fire(j)
	if _fuse >= 0.0:
		# about to go: a hot glow bleeding through the steel
		var k := 0.5 + 0.5 * absf(sin(_t * 30.0))
		draw_circle(j, 7.0, Color(1.0, 0.45, 0.1, 0.25 * k))
		draw_circle(j + Vector2(-1.8, -1.2), 1.6, Color(1.0, 0.8, 0.3, k))

## A lazy fire on the lid: tongues that lean and flicker, a hot core, sparks.
func _draw_fire(o: Vector2) -> void:
	var c := o + Vector2(-1.0, -0.5)
	# counter the drum's own turn so the flames always rise "up" the screen
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	c = c.rotated(rotation)
	draw_circle(c, 4.2, Color(1.0, 0.45, 0.1, 0.18))
	for i in 5:
		var ph := _t * (6.0 + i) + i * 1.7 + _seed * 10.0
		var bx := c + Vector2((i - 2) * 1.2 + sin(ph) * 0.6, 0.6)
		var hgt := 3.5 + 1.8 * absf(sin(ph * 0.7)) - absf(i - 2) * 0.6
		var tip := bx + Vector2(sin(ph * 1.3) * 1.0 + 0.6, -hgt)
		draw_colored_polygon(PackedVector2Array([bx + Vector2(-1.1, 0), tip, bx + Vector2(1.1, 0)]), Color(1.0, 0.42, 0.08, 0.85))
		draw_colored_polygon(PackedVector2Array([bx + Vector2(-0.6, 0), bx.lerp(tip, 0.65), bx + Vector2(0.6, 0)]), Color(1.0, 0.85, 0.35, 0.95))
	for i in 3:
		var sp := fmod(_t * 0.9 + i * 0.37 + _seed, 1.0)
		draw_rect(Rect2(c + Vector2(sin(i * 5.0 + _t * 2.0) * 3.0, -4.0 - sp * 9.0), Vector2(0.8, 0.8)), Color(1.0, 0.75, 0.3, 1.0 - sp))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
