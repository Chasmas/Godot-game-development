extends Node
## Dev tool: a close-up of every auto-placed decor item.  GALLERY_MISSION=<id> AUDIT_OUT=<folder>
func _ready() -> void:
	Engine.set_meta("autoplay", true)
	Engine.set_meta("trailer", true)
	Game.force_intro_calls = false
	await get_tree().process_frame
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	Game.start_mission(OS.get_environment("GALLERY_MISSION"))
	for i in 140:
		if Dialogue.active: Dialogue._end()
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl: pl.god_mode = true
		await get_tree().process_frame
	var level := get_tree().get_first_node_in_group("level") as Level
	if level.hud: level.hud.visible = false
	var probe := Node2D.new()
	level.add_child(probe)
	level.camera.target = probe
	level.camera.zoom_bias = 2.0
	var out := OS.get_environment("AUDIT_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	var n := 0
	for it in level.data.get("decor", []):
		if not it.get("auto", false): continue
		var p: Array = it["pos"]
		probe.global_position = Vector2(float(p[0]) * 16 + 8, float(p[1]) * 16 + 8)
		level.camera.snap_to_target()
		for k in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var c := img.get_region(Rect2i(img.get_width() / 2 - 320, img.get_height() / 2 - 200, 640, 400))
		c.save_png("%s/%02d_%s.png" % [out, n, it["id"]])
		n += 1
	get_tree().quit()
