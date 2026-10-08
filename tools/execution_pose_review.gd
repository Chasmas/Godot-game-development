extends Node

func _ready() -> void:
	var target_look := OS.get_environment("EXECUTION_REVIEW_LOOK")
	if target_look == "":
		target_look = "guard"
	var stage := SubViewport.new()
	stage.size = Vector2i(1320, 260)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(stage.size)
	stage.add_child(background)
	var models: Array[CastModel] = []
	for col in 6:
		for look in ["cass", target_look]:
			var rig := Node2D.new()
			rig.position = Vector2(90 + col * 220 + (24 if look != "cass" else 0), 195)
			stage.add_child(rig)
			var model := CastModel.new()
			var source := "res://assets/art/cast3d_rt/cass/cass.glb" if look == "cass" else OS.get_environment("EXECUTION_REVIEW_MODEL")
			if source == "":
				source = "res://assets/art/cast3d_rt/%s/%s.glb" % [look, look]
			if not model.configure(look, source):
				get_tree().quit(1)
				return
			rig.add_child(model)
			model.scale *= 4.0
			model.set_meta("review_clip", "grab" if look == "cass" else "held")
			model.set_meta("review_progress", float(col) / 5.0)
			models.append(model)
		var label := Label.new()
		label.text = "Rear hold  %.2f" % (float(col) / 5.0)
		label.position = Vector2(20 + col * 220, 220)
		stage.add_child(label)
	for frame in 12:
		for model in models:
			model.play_sample(model.get_meta("review_clip"), 1.0 / 60.0, model.get_meta("review_progress"))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := stage.get_texture().get_image().save_png("res://build/%s_execution_pose_review.png" % target_look)
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit(err)
