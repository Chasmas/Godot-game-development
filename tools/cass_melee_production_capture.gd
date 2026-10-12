extends Node

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 760)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("181622")
	background.size = Vector2(stage.size)
	stage.add_child(background)
	var phases := [0.0, 0.28, 0.58, 0.82, 0.995]
	var weapons := [&"bat", &"knife"]
	for row in weapons.size():
		for column in phases.size():
			var holder := Node2D.new()
			holder.position = Vector2(128 + column * 256, 205 + row * 350)
			holder.scale = Vector2.ONE * 6.5
			stage.add_child(holder)
			var visual := CharacterVisual.new()
			holder.add_child(visual)
			visual.setup("cass")
			visual.set_weapon(DB.weapon(weapons[row]))
			visual.set_aim(0.0)
			visual.swing(row == 0, row == 1)
			visual.set_process(false)
			visual._swing_t = float(phases[column]) * visual._swing_dur
			visual._process_cast(0.0)
			var label := Label.new()
			label.position = Vector2(27 + column * 256, 310 + row * 350)
			label.text = "%s  %d%%" % [str(weapons[row]).to_upper(), int(float(phases[column]) * 100.0)]
			label.add_theme_font_size_override("font_size", 18)
			stage.add_child(label)
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := stage.get_texture().get_image().save_png("res://build/cass_melee_production_review.png")
	stage.queue_free()
	print("CASS PRODUCTION MELEE CAPTURE ", "PASSED" if error == OK else "FAILED")
	get_tree().quit(0 if error == OK else 1)
