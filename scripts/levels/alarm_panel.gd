class_name AlarmPanel
extends Node2D
## Wall alarm. Scouts/technicians run to it; the player can smash it first
## (interact) to keep a floor quiet. Triggering calls reinforcements.

var armed := true
var triggered := false
var _t := 0.0

func _ready() -> void:
	add_to_group("alarm")
	add_to_group("interactable")
	z_index = 4

func is_armed() -> bool:
	return armed and not triggered

func can_interact(_p: Node) -> bool:
	return armed and not triggered

func get_prompt() -> String:
	return "SMASH ALARM"

func interact(_p: Node) -> void:
	armed = false
	Audio.play_at("tv_break", global_position)
	Effects.sparks(global_position, Vector2.DOWN)
	Score.add_bonus("SABOTAGE", 300, global_position)
	queue_redraw()

func trigger(_by: Node) -> void:
	if not is_armed():
		return
	triggered = true
	Audio.play_at("alarm", global_position, 2.0)
	Events.alarm_raised.emit(global_position)
	Events.noise.emit(global_position, 3000.0, &"alarm", self)
	Events.hint.emit("ALARM! REINFORCEMENTS INCOMING", 2.0)
	PostFX.flash(Color(1, 0, 0.1), 0.15)
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl and lvl.has_method("on_alarm"):
		lvl.on_alarm(global_position)
	for i in 3:
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(self):
			Audio.play_at("alarm", global_position, 0.0)

func _process(delta: float) -> void:
	_t += delta
	if triggered and Engine.get_process_frames() % 4 == 0:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-5, -4, 10, 8), Color(0.06, 0.03, 0.08))
	var c := Color(0.8, 0.1, 0.12)
	if triggered:
		c = Color(1, 0.2, 0.2) if fmod(_t, 0.4) < 0.2 else Color(0.4, 0.05, 0.05)
	elif not armed:
		c = Color(0.25, 0.25, 0.28)
	draw_rect(Rect2(-4, -3, 8, 6), c)
	draw_circle(Vector2.ZERO, 1.5, Color(1, 0.9, 0.9) if armed else Color(0.2, 0.2, 0.2))
