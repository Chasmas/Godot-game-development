extends Node

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(600, 360)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.size = Vector2(stage.size)
	background.color = Color("292536")
	background.z_index = -100
	stage.add_child(background)
	for column in 2:
		for row in 2:
			var prop: Node2D = CharacterVisual._MagInHand.new() if column == 0 else CharacterVisual._DroppedMag.new()
			prop.position = Vector2(150 + column * 300, 60 + row * 110)
			if column == 1:
				prop.start_pos = prop.position
			prop.scale = Vector2.ONE * (1.0 if row == 0 else 8.0)
			stage.add_child(prop)
			prop.set_process(false)
		var label := Label.new()
		label.text = "LOADED / IN HAND" if column == 0 else "EMPTY / DROPPED"
		label.position = Vector2(40 + column * 300, 10)
		stage.add_child(label)
		var shell := Effects.DecalChunk.new()
		shell.position = Vector2(150 + column * 300, 290)
		shell.scale = Vector2.ONE * 8
		shell.shells.append([Vector2.ZERO, 0.0, column == 1])
		stage.add_child(shell)
		shell.dirty()
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := stage.get_texture().get_image().save_png("res://build/reload_prop_review/godot_review.png")
	print("RELOAD PROP REVIEW: ", err)
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit(err)
