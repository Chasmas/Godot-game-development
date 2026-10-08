class_name Handler
extends Enemy
## Dog handler: walks a German Shepherd at heel. The moment he's alerted he
## lets it go ("Sic 'em!") and the dog runs you down while he shoots.

var dog: Dog = null
var _released := false

func setup(p_data: EnemyData, p_level: Node, p_facing: Vector2) -> void:
	super.setup(p_data, p_level, p_facing)
	# the dog waits at heel until released
	var d := Dog.new()
	d.enemy_id = enemy_id + "_dog"
	d.position = position + p_facing.orthogonal() * 12.0
	if level and level.get("actors_root"):
		level.actors_root.add_child(d)
	else:
		get_parent().add_child(d)
	d.setup(DB.enemy(&"dog"), p_level, p_facing)
	d.sniff_mode = false
	d.set_physics_process(false)
	dog = d

func _enter_combat() -> void:
	if _held or state == State.DOWNED:
		return
	super._enter_combat()
	_release()

func _release(announce := true) -> void:
	if _released or dog == null or not is_instance_valid(dog) or not dog.is_alive():
		return
	_released = true
	_leash_points.clear()
	_leash_previous.clear()
	_reset_pose()
	dog.set_physics_process(true)
	dog._last_known = _last_known
	dog._enter_combat()
	var bl := BarkLayer.find(get_tree())
	if bl and announce:
		bl.say(self, "Sic 'em!", 1.6, Color(1, 0.6, 0.3))
	Audio.play_at("bark", dog.global_position, 0.0, 0.1)

func _die(info: DamageInfo) -> void:
	if not is_alive():
		return
	# Enemy death queues the handler for deletion. Do not rely on another
	# physics tick to release the surviving dog or it can stay frozen at heel.
	_release(false)
	super._die(info)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# at heel: the dog trots beside him until let go
	if not _released and dog and is_instance_valid(dog) and dog.is_alive():
		# heel sits a little ahead when walking so the leash pulls taut
		var ahead := 3.0 if velocity.length() > 10.0 else -4.0
		var heel := global_position + facing.orthogonal() * 11.0 + facing * ahead
		dog.heel_follow(delta, heel, facing)
		_walk_anim(delta)
	if not is_alive() and not _released:
		_release()   # shot the handler: the dog goes for you anyway

## Walking the dog: shoulders roll with each stride, a little bounce, gun
## carried low at his side, and he leans back when the dog pulls ahead.
var _stride := 0.0
func _walk_anim(delta: float) -> void:
	if not is_alive() or state == State.DOWNED or visual.is_swinging() or is_snoozing():
		return
	var sp := velocity.length()
	var k := clampf(sp / 50.0, 0.0, 1.0)
	_stride += delta * (1.2 + sp * 0.11) if sp > 5.0 else 0.0
	var pull := 0.0
	if dog and is_instance_valid(dog):
		var d := dog.global_position.distance_to(global_position)
		pull = clampf((d - 11.0) / 6.0, 0.0, 1.0)
	visual.torso.rotation = sin(_stride * 2.0) * 0.09 * k
	visual.torso.position = Vector2(-0.6 * pull + absf(sin(_stride * 2.0)) * 0.5 * k, sin(_stride * 2.0) * 0.4 * k)
	var bob := 0.5 + absf(sin(_stride * 2.0)) * 0.018 * k
	visual.torso.scale = Vector2(bob, bob)
	# gun held low along the thigh while he's calm
	visual.weapon_sprite.rotation = lerp_angle(visual.weapon_sprite.rotation, 0.85 + sin(_stride * 2.0) * 0.12 * k, minf(1.0, delta * 8.0))

func _reset_pose() -> void:
	visual.torso.rotation = 0.0
	visual.torso.position = Vector2.ZERO
	visual.torso.scale = Vector2(0.5, 0.5)
	visual.weapon_sprite.rotation = 0.0

func _leash_hand_point() -> Vector2:
	if visual and visual.cast_sprite is CastModel:
		return to_local(visual.rig.to_global(visual.cast_sprite.grip(true)))
	return facing.orthogonal() * 4.0 + facing * (2.0 + sin(_stride * 2.0) * 1.2)

# World-space Verlet particles keep inertia when either anchor changes direction.
var _leash_points := PackedVector2Array()
var _leash_previous := PackedVector2Array()
var _leash_last_dt := 1.0 / 120.0
const LEASH_SEGMENTS := 8

func _simulate_leash(delta: float) -> void:
	if _released or not is_alive() or not is_instance_valid(dog) or not dog.is_alive():
		_leash_points.clear()
		_leash_previous.clear()
		return
	var a := to_global(_leash_hand_point())
	var b := dog.global_position + dog.facing * 3.5
	var size_scale := maxf(global_scale.length() / sqrt(2.0), 0.1)
	if _leash_points.is_empty() or _leash_points[0].distance_to(a) > 48.0 * size_scale or _leash_points[LEASH_SEGMENTS].distance_to(b) > 48.0 * size_scale:
		_leash_points.resize(LEASH_SEGMENTS + 1)
		_leash_previous.resize(LEASH_SEGMENTS + 1)
		for i in LEASH_SEGMENTS + 1:
			_leash_points[i] = a.lerp(b, float(i) / LEASH_SEGMENTS)
			_leash_previous[i] = _leash_points[i]
		_leash_last_dt = 1.0 / 120.0
	if delta <= 0.0:
		_leash_points[0] = a
		_leash_points[LEASH_SEGMENTS] = b
		return
	# Bound work and integration time after a pause; gravity acts in screen space.
	var elapsed := clampf(delta, 0.0, 0.05)
	var steps := maxi(1, ceili(elapsed / (1.0 / 120.0)))
	var dt := elapsed / steps
	var segment_length := maxf(14.0 * size_scale, a.distance_to(b) * 1.01) / LEASH_SEGMENTS
	for step in steps:
		for i in range(1, LEASH_SEGMENTS):
			var point := _leash_points[i]
			var inertia := (point - _leash_previous[i]) * (dt / _leash_last_dt) * pow(0.12, dt)
			_leash_points[i] += inertia + Vector2(0.0, 90.0 * size_scale) * dt * dt
			_leash_previous[i] = point
		for iteration in 24:
			_leash_points[0] = a
			_leash_points[LEASH_SEGMENTS] = b
			for i in LEASH_SEGMENTS:
				var offset := _leash_points[i + 1] - _leash_points[i]
				var length := offset.length()
				if length < 0.0001:
					continue
				var correction := offset * ((length - segment_length) / length)
				if i == 0:
					_leash_points[i + 1] -= correction
				elif i == LEASH_SEGMENTS - 1:
					_leash_points[i] += correction
				else:
					_leash_points[i] += correction * 0.5
					_leash_points[i + 1] -= correction * 0.5
		_leash_points[0] = a
		_leash_points[LEASH_SEGMENTS] = b
		_leash_last_dt = dt

func _draw() -> void:
	super._draw()
	if _leash_points.size() < 2 or _released:
		return
	var points := PackedVector2Array()
	for point in _leash_points:
		points.append(to_local(point))
	draw_polyline(points, Color(0.1, 0.06, 0.04), 1.6, true)
	draw_polyline(points, Color(0.55, 0.32, 0.16), 0.8, true)
	if not (visual.cast_sprite is CastModel):
		draw_circle(points[0], 1.6, Color(0.05, 0.03, 0.06))
		draw_circle(points[0], 1.1, Color(0.78, 0.56, 0.42))

func _process(delta: float) -> void:
	_simulate_leash(delta)
	queue_redraw()
