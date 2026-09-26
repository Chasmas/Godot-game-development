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
		var heel := global_position + facing.orthogonal() * 12.0 - facing * 4.0
		var off := heel - dog.global_position
		if off.length() > 3.0:
			dog.global_position += off * minf(1.0, delta * 6.0)
		dog.facing = facing
	if not is_alive() and not _released:
		_release()   # shot the handler: the dog goes for you anyway

func _draw() -> void:
	super._draw()
	# the leash
	if not _released and dog and is_instance_valid(dog) and is_alive():
		draw_line(visual.hand_global() - global_position, dog.global_position - global_position, Color(0.35, 0.22, 0.12), 1.0)

func _process(_delta: float) -> void:
	queue_redraw()
