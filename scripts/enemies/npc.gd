class_name NPC
extends CharacterBody2D
## Non-combatant: talks, panics at violence, flees or hides, can be hurt.
## Killing civilians costs points and is remembered by the story.

var npc_id := "guest"
var palette := "civilian"
var lines: Array = []
var visual: CharacterVisual
var hit_radius := 6.0
var panicking := false
var alive := true
var cowering := false
var _line_i := 0
var _panic_t := 0.0
var _flee_dir := Vector2.ZERO
var _bark_t := 0.0
var _bark := ""
var facing := Vector2.DOWN

func _ready() -> void:
	add_to_group("npcs")
	add_to_group("interactable")
	add_to_group("damageable")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.LOW | Layers.GLASS | Layers.PIT | Layers.PROP
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	cs.shape = c
	add_child(cs)
	visual = CharacterVisual.new()
	add_child(visual)
	if palette == "civilian":
		palette = "civilian#%d" % (absi(hash(npc_id)) % 4)
	visual.setup(palette)
	visual.set_aim(facing.angle())
	Events.noise.connect(_on_noise)

func can_interact(_p: Node) -> bool:
	return alive and not lines.is_empty()

func get_prompt() -> String:
	return "TALK"

func interact(_p: Node) -> void:
	if lines.is_empty():
		return
	_say(str(lines[_line_i % lines.size()]))
	_line_i += 1

func _say(text: String) -> void:
	_bark = text
	_bark_t = 2.8
	queue_redraw()

func _on_noise(pos: Vector2, radius: float, kind: StringName, _src: Node) -> void:
	if not alive:
		return
	if kind in [&"gunshot", &"explosion", &"glass"] and global_position.distance_to(pos) < radius:
		if not panicking:
			panicking = true
			_say(["Oh God--", "Don't shoot! DON'T SHOOT!", "I didn't see nothing!", "Mama..."][randi() % 4])
		_panic_t = 3.0
		_flee_dir = (global_position - pos).normalized()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_bark_t = maxf(0.0, _bark_t - delta)
	if panicking:
		_panic_t -= delta
		if _panic_t > 1.2:
			velocity = _flee_dir * 110.0
		else:
			velocity = Vector2.ZERO
			cowering = true
		move_and_slide()
		if get_slide_collision_count() > 0:
			_flee_dir = _flee_dir.rotated(randf_range(1.0, 2.2))
		if _panic_t <= 0.0:
			panicking = false
	if velocity.length() > 5.0:
		facing = velocity.normalized()
	visual.set_aim(facing.angle())
	visual.update_move(velocity, delta)
	visual.scale = Vector2(0.85, 0.85) if cowering else Vector2.ONE
	if _bark_t > 0.0 or Engine.get_physics_frames() % 10 == 0:
		queue_redraw()

func take_damage(info: DamageInfo) -> String:
	if not alive:
		return "pass"
	if not info.lethal and info.type == DamageInfo.Type.PUNCH:
		_say("OW! What the hell?!")
		_on_noise(global_position, 100.0, &"gunshot", null)
		return "hurt"
	alive = false
	collision_layer = 0
	remove_from_group("interactable")
	remove_from_group("damageable")
	var corpse := Corpse.new()
	corpse.setup(palette, info.dir, false)
	corpse.global_position = global_position
	get_parent().add_child(corpse)
	Effects.blood(global_position, info.dir, true)
	Audio.play_at("death", global_position)
	if info.from_player:
		Score.add_bonus("COLLATERAL", -1000, global_position)
		SaveManager.set_flag("killed_civilian_" + npc_id, true)
	queue_free()
	return "killed"

func _draw() -> void:
	if _bark_t > 0.0:
		var f := UIStyle.font_bold()
		var w := f.get_string_size(_bark, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_rect(Rect2(-w * 0.5 - 3, -24, w + 6, 11), Color(0.04, 0.02, 0.08, 0.85))
		draw_string(f, Vector2(-w * 0.5, -16), _bark, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UIStyle.PAPER)
	elif alive and not lines.is_empty() and not panicking:
		draw_string(UIStyle.font_bold(), Vector2(-2, -11), "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(UIStyle.CYAN, 0.7))
