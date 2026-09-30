extends Node2D
var examples: Array = []
var elapsed := 0.0
var last_cycle := -1
var frames := 0
var movie := false
func _ready() -> void:
	movie = OS.get_environment("CAST_MOVIE") == "1"
	RenderingServer.set_default_clear_color(Color("171523"))
	var title := Label.new()
	title.text = "CASS / WEAPON AND POSE CHECK"
	title.position = Vector2(30, 16)
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)
	for i in 9:
		var pos := Vector2(160 + (i % 3) * 310, 140 + (i / 3) * 155)
		var label := Label.new()
		label.text = ["RELAXED", "PISTOL", "RIFLE", "DUAL PISTOLS", "RELOAD", "MELEE", "DODGE", "KICK", "DEATH"][i]
		label.position = pos + Vector2(-65, 48)
		add_child(label)
		var v := CharacterVisual.new()
		add_child(v)
		v.setup("cass")
		v.position = pos
		v.scale = Vector2.ONE * 3.0
		v.set_process(false)
		v.shadow.visible = false
		if i in [1, 2, 3, 4, 5]:
			v.set_weapon(DB.weapon("rifle" if i == 2 else ("bat" if i == 5 else "pistol")), i == 3)
		v.set_aim(0.0)
		examples.append(v)
	if not movie:
		examples[4].reload_anim(1.0)
		examples[5].swing(true)
		examples[6].roll(Vector2.RIGHT, 0.5)
		examples[7].kick_leg()
		for v in examples: v._process(0.1)
		examples[4]._process(0.3)
		examples[8].cast_sprite.play_sample("death", 0.1, 1.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var out := OS.get_environment("CAST_PREVIEW_OUT")
		if not out.is_empty(): get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
func _process(delta: float) -> void:
	if not movie: return
	elapsed += delta
	var cycle := int(elapsed / 2.0)
	if cycle != last_cycle:
		last_cycle = cycle
		examples[4].reload_anim(1.5, ["mag", "shell", "dual"][cycle % 3])
		examples[5].swing(true)
		examples[6].roll(Vector2.from_angle(elapsed * 0.45), 0.45)
		examples[7].kick_leg()
	for i in examples.size():
		var v: CharacterVisual = examples[i]
		v.set_aim(elapsed * 0.45 if i < 4 else 0.0)
		v.update_move(Vector2.RIGHT * (120.0 if i in [2, 3] else 0.0), delta)
		if i == 8:
			v.cast_sprite.play_sample("death", delta, minf(fmod(elapsed, 2.0) / 0.75, 1.0))
		else:
			v._process(delta)
	if elapsed >= 10.0: get_tree().quit()
