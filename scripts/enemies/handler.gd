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
	super._enter_combat()
	_release()

func _release() -> void:
	if _released or dog == null or not is_instance_valid(dog) or not dog.is_alive():
		return
	_released = true
	_reset_pose()
	dog.set_physics_process(true)
	dog._last_known = _last_known
	dog._enter_combat()
	var bl := BarkLayer.find(get_tree())
	if bl:
		bl.say(self, "Sic 'em!", 1.6, Color(1, 0.6, 0.3))
	Audio.play_at("bark", dog.global_position, 0.0, 0.1)

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

func _draw() -> void:
	super._draw()
	# the leash
	if not _released and dog and is_instance_valid(dog) and is_alive():
		# from his off hand to the collar, sagging when slack, taut when the
		# dog pulls ahead
		var a := facing.orthogonal() * 4.0 + facing * (2.0 + sin(_stride * 2.0) * 1.2)
		var b := dog.global_position + dog.facing * 3.5 - global_position
		var slack := clampf(1.0 - (a.distance_to(b) - 7.0) / 6.0, 0.0, 1.0)
		var mid := (a + b) * 0.5 + Vector2(0, 3.0 * slack + sin(Time.get_ticks_msec() * 0.006) * 0.4 * slack)
		var pts := PackedVector2Array()
		for i in 7:
			var t := i / 6.0
			pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
		draw_polyline(pts, Color(0.1, 0.06, 0.04), 1.6)
		draw_polyline(pts, Color(0.55, 0.32, 0.16), 0.8)
		# his fist round the leash loop, swinging with the stride
		draw_circle(a, 1.6, Color(0.05, 0.03, 0.06))
		draw_circle(a, 1.1, Color(0.78, 0.56, 0.42))

func _process(_delta: float) -> void:
	queue_redraw()
