extends Node2D
var examples: Array = []
var elapsed := 0.0
var last_cycle := -1
var frames := 0
var movie := false
func _ready() -> void:
	movie = OS.get_environment("CAST_MOVIE") == "1"
	var requested_look := OS.get_environment("CAST_LOOK")
	if not requested_look.is_empty():
		# A chroma background makes automated pose-guide extraction reliable.
		RenderingServer.set_default_clear_color(Color("ff00ff"))
		if OS.get_environment("CAST_CORPSE") == "1":
			await _render_single_corpse(requested_look)
		else:
			await _render_single_look(requested_look)
		return
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
		if DisplayServer.get_name() == "headless":
			push_warning("Cast preview capture skipped: headless renderer has no visual texture")
		else:
			var texture := get_viewport().get_texture()
			if texture and not out.is_empty(): texture.get_image().save_png(out)
		get_tree().quit()

func _render_single_look(look: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CAST_LOOK capture requires the non-headless renderer.")
		get_tree().quit(2)
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var visual := CharacterVisual.new()
	add_child(visual)
	visual.setup(look)
	var model_source := OS.get_environment("CAST_MODEL_SOURCE")
	if not model_source.is_empty():
		assert(visual.cast_sprite!=null)
		visual.cast_sprite.free()
		var candidate := CastModel.new()
		assert(candidate.configure(look,model_source))
		visual.cast_sprite=candidate
		visual.rig.add_child(candidate)
	visual.position = viewport_size * 0.5
	visual.scale = Vector2.ONE * (float(OS.get_environment("CAST_SCALE")) if OS.get_environment("CAST_SCALE") != "" else 10.0)
	visual.set_process(false)
	visual.shadow.visible = false
	var pose := OS.get_environment("CAST_POSE")
	if pose == "armed":
		var requested_weapon := OS.get_environment("CAST_WEAPON")
		visual.set_weapon(DB.weapon(requested_weapon if not requested_weapon.is_empty() else "pistol"))
		visual.set_aim(deg_to_rad(float(OS.get_environment("CAST_AIM"))) if OS.get_environment("CAST_AIM")!="" else -PI*.5)
		visual.update_move(Vector2.UP * 120.0, 0.12)
	else:
		# CAST_AIM (degrees) checks that a top-down layer still reads when the rig rotates it.
		visual.set_aim(deg_to_rad(float(OS.get_environment("CAST_AIM"))))
		visual.update_move(Vector2.ZERO, 0.016)
	# Half a second of updates: a real-time cast needs its clip applied (and its
	# blend from the rest pose finished) before the grip and the picture are right.
	# `frame_post_draw` is not emitted reliably by the headless renderer used
	# by the automated audit. Process frames still flush the viewport texture.
	# CAST_CLIP forces a scripted clip (e.g. "drive", "car_exit"); CAST_PROGRESS 0..1 holds it there
	if OS.get_environment("CAST_CLIP") != "":
		visual.pose_override = OS.get_environment("CAST_CLIP")
		visual.pose_progress = float(OS.get_environment("CAST_PROGRESS")) if OS.get_environment("CAST_PROGRESS") != "" else -1.0
	for i in 30:
		if pose == "armed":
			# CAST_MOVE (degrees): walk that way while aiming up (Hotline Miami twist)
			var mv := Vector2.from_angle(deg_to_rad(float(OS.get_environment("CAST_MOVE")))) if OS.get_environment("CAST_MOVE") != "" else Vector2.UP
			visual.update_move(mv * 120.0, 1.0 / 60.0)
		visual._process(1.0 / 60.0)
		if OS.get_environment("CAST_NATIVE_MELEE_ANGLE")=="1" and visual.cast_sprite is CastModel:
			var cast := visual.cast_sprite as CastModel
			var hand := cast._skeleton.global_transform*cast._skeleton.get_bone_global_pose(cast._hand_bones[0])
			var start := cast._camera.unproject_position(hand.origin)
			var end := cast._camera.unproject_position(hand.origin+hand.basis.y.normalized()*.3)
			visual.weapon_sprite.rotation=(end-start).angle()-cast._facing_angle
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if OS.get_environment("CAST_FULL") != "1":
		var crop_size := Vector2i(320, 320)
		var image_centre := Vector2i(image.get_size()) / 2
		var crop_origin := image_centre - crop_size / 2
		image = image.get_region(Rect2i(crop_origin, crop_size))
	var out := OS.get_environment("CAST_PREVIEW_OUT")
	if not out.is_empty():
		image.save_png(out)
	get_tree().quit()

func _render_single_corpse(look: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CAST_CORPSE capture requires the non-headless renderer.")
		get_tree().quit(2)
		return
	var corpse := Corpse.new()
	add_child(corpse)
	corpse.setup(look, Vector2.RIGHT)
	corpse.position = get_viewport().get_visible_rect().size * 0.5
	corpse.scale = Vector2.ONE * 10.0
	corpse.set_process(false)
	for i in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if OS.get_environment("CAST_FULL") != "1":
		var crop_size := Vector2i(640, 400)
		var image_centre := Vector2i(image.get_size()) / 2
		image = image.get_region(Rect2i(image_centre - crop_size / 2, crop_size))
	var out := OS.get_environment("CAST_PREVIEW_OUT")
	if not out.is_empty():
		image.save_png(out)
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
