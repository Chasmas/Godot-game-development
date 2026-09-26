class_name FilmCamera
extends StaticBody2D
## THE VOICE's hidden cameras. Somebody is filming, and here's the proof: a
## camcorder tucked in a corner, red REC light blinking. Two ways to play it:
##  - play to it: kills it can see score FOR THE CAMERA;
##  - cut the feed: shoot or smash it (a bonus, and he notices).
## Either way the director's notes on the results screen remember.

const VIEW := 120.0
var _t := 0.0
var _broken := false
var facing := Vector2.DOWN

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("film_cameras")
	collision_layer = Layers.PROP
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 3.5
	cs.shape = c
	add_child(cs)
	z_index = 6
	_t = randf() * 2.0
	Events.enemy_killed.connect(_on_kill)

func _on_kill(enemy: Node, _info: Dictionary) -> void:
	if _broken or enemy == null or not is_instance_valid(enemy):
		return
	var pos: Vector2 = (enemy as Node2D).global_position
	if pos.distance_to(global_position) > VIEW:
		return
	var q := PhysicsRayQueryParameters2D.create(global_position, pos, Layers.SIGHT_MASK, [get_rid()])
	if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		return
	Score.stats["camera_kills"] = int(Score.stats.get("camera_kills", 0)) + 1
	Score.add_bonus("FOR THE CAMERA", 200, pos)
	Audio.play_at("rec_beep", global_position, -10.0, 0.0)

func take_damage(info: DamageInfo) -> String:
	if _broken:
		return "pass"
	_broken = true
	collision_layer = 0
	Audio.play_at("camera_break", global_position, -2.0, 0.1)
	Effects.sparks(global_position, -info.dir if info.dir != Vector2.ZERO else Vector2.UP)
	Effects.shards(global_position, info.dir, Color(0.25, 0.25, 0.3), 6)
	Score.stats["feeds_cut"] = int(Score.stats.get("feeds_cut", 0)) + 1
	Score.add_bonus("CUT THE FEED", 300, global_position)
	return "hit"

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var ink := Color("0b0710")
	if _broken:
		draw_rect(Rect2(-3, -2, 6, 4), Color(0.18, 0.18, 0.22))
		draw_line(Vector2(-3, -2), Vector2(3, 2), ink, 1.0)
		if fmod(_t, 2.3) < 0.07:
			draw_circle(Vector2(2, 0), 1.2, Color(1, 0.9, 0.5))
		return
	# a camcorder on a little bracket, lens toward the room
	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
	draw_rect(Rect2(-4, -2.5, 7, 5), ink)
	draw_rect(Rect2(-3.5, -2, 6, 4), Color(0.22, 0.22, 0.26))
	draw_rect(Rect2(3, -1.5, 2, 3), ink)
	draw_circle(Vector2(4.5, 0), 1.1, Color(0.3, 0.35, 0.6))
	var rec := fmod(_t, 1.0) < 0.55
	draw_circle(Vector2(-2.5, -1.2), 0.9, Color(1, 0.1, 0.15) if rec else Color(0.3, 0.05, 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rec:
		draw_circle(Vector2.ZERO, 6.0, Color(1, 0.1, 0.15, 0.05))
	# when you're close, a faint viewfinder frame shows what it sees
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and p.global_position.distance_to(global_position) < VIEW:
		var k := clampf(1.0 - p.global_position.distance_to(global_position) / VIEW, 0.0, 1.0)
		var ctr := facing * VIEW * 0.5
		var hs := Vector2(VIEW * 0.45, VIEW * 0.32)
		var col := Color(1, 0.25, 0.4, 0.25 * k)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var cp: Vector2 = ctr + hs * corner
			draw_line(cp, cp - Vector2(corner.x * 8, 0), col, 1.0)
			draw_line(cp, cp - Vector2(0, corner.y * 8), col, 1.0)
		if fmod(_t, 1.0) < 0.55:
			draw_string(UIStyle.font_bold(), ctr + Vector2(-hs.x + 3, -hs.y + 8), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, col)
