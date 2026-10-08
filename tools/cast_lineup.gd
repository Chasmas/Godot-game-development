extends Node
## Review shot: one look in a real mission next to Cass, at game scale.
## Eight copies around her in the eight compass facings (alternately armed),
## plus one downed and one corpse.
##   CAST_LOOK=guard CAST_PREVIEW_OUT=C:/tmp_shots/x.png godot --path . res://tools/cast_lineup.tscn --display-driver windows --audio-driver Dummy
## Optional CAST_ZOOM (camera zoom bias, default 1.0) and CAST_MISSION.

func _ready() -> void:
	Engine.set_meta("autoplay", true)
	Engine.set_meta("trailer", true)
	Game.force_intro_calls = false
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	var mission := OS.get_environment("CAST_MISSION")
	Game.start_mission(mission if mission != "" else "m01_checkout")
	for i in 600:
		if Dialogue.active: Dialogue._end()
		var player := get_tree().get_first_node_in_group("player") as Player
		if player: player.god_mode = true
		await get_tree().physics_frame
	var look := OS.get_environment("CAST_LOOK")
	if look == "":
		look = "guard"
	var p := get_tree().get_first_node_in_group("player") as Player
	var level := get_tree().get_first_node_in_group("level") as Level
	# the mission's own enemies would walk into the shot
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Node2D).process_mode = Node.PROCESS_MODE_DISABLED
		(e as Node2D).visible = false
	p.set_physics_process(false)
	p.input_enabled = false
	p.visible = true
	p.global_position = Vector2(248, 728)
	p.give_weapon(&"pistol")
	p.visual.set_aim(0.0)
	var visuals: Array[CharacterVisual] = []
	for i in 8:
		var v := CharacterVisual.new()
		level.actors_root.add_child(v)
		v.setup(look)
		var a := TAU * i / 8.0
		v.global_position = p.global_position + Vector2.from_angle(a) * 46.0
		if i % 2 == 0:
			v.set_weapon(DB.weapon("pistol"))
		# facing outward, so every compass facing shows once
		v.set_aim(a)
		visuals.append(v)
	var downed := CharacterVisual.new()
	level.actors_root.add_child(downed)
	downed.setup(look)
	downed.global_position = p.global_position + Vector2(-92, 0)
	downed.fall(Vector2.LEFT)
	visuals.append(downed)
	var corpse := Corpse.new()
	level.actors_root.add_child(corpse)
	corpse.global_position = p.global_position + Vector2(92, 0)
	corpse.setup(look, Vector2.RIGHT, false)
	level.camera.target = p
	var zoom := OS.get_environment("CAST_ZOOM")
	level.camera.zoom_bias = float(zoom) if zoom != "" else 1.0
	level.camera.snap_to_target()
	for i in 50:
		for v in visuals:
			v.update_move(Vector2.ZERO, 0.016)
		await get_tree().process_frame
	# Headless/dummy renderers may never emit frame_post_draw or expose a texture;
	# keep the review tool bounded and leave normal gameplay untouched.
	await get_tree().process_frame
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_warning("Cast lineup skipped: headless renderer has no visual capture")
		get_tree().quit()
		return
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		push_warning("Cast lineup skipped: renderer has no viewport texture")
		get_tree().quit()
		return
	var shot := viewport_texture.get_image()
	if shot == null:
		push_warning("Cast lineup skipped: renderer returned no image")
		get_tree().quit()
		return
	var out := OS.get_environment("CAST_PREVIEW_OUT")
	shot.save_png(out)
	# plus the lineup itself, cropped round Cass and blown up 2x (nearest)
	var vs := Vector2(shot.get_size())
	var at := p.get_global_transform_with_canvas().origin * vs / get_viewport().get_visible_rect().size
	var half := Vector2(vs.x * 0.2, vs.y * 0.2)
	var rect := Rect2i(Vector2i((at - half).clamp(Vector2.ZERO, vs - half * 2.0)), Vector2i(half * 2.0))
	var crop := shot.get_region(rect)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.get_basename() + "_crop.png")
	print("cast lineup: ", look, " cast=", visuals[0].cast_sprite != null)
	get_tree().quit()
