extends Node

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1320, 690)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(stage.size)
	stage.add_child(background)
	var models: Array[CastModel] = []
	for row in 3:
		var clip_name: String = ["punch", "punch_left", "melee"][row]
		for col in 6:
			var rig := Node2D.new()
			rig.position = Vector2(110 + col * 220, 170 + row * 220)
			stage.add_child(rig)
			var model: CastModel
			var candidate := OS.get_environment("COMBAT_REVIEW_MODEL")
			if candidate != "":
				model = CastModel.new()
				if not model.configure("cass", candidate):
					push_error("Could not load combat review candidate")
					get_tree().quit(1)
					return
			else:
				model = CastModel.create("cass") as CastModel
			rig.add_child(model)
			model.scale *= 4.0
			model.set_meta("review_clip", clip_name)
			model.set_meta("review_progress", float(col) / 5.0)
			models.append(model)
			var label := Label.new()
			label.text = "%s  %.2f" % [clip_name, float(col) / 5.0]
			label.position = Vector2(20 + col * 220, 195 + row * 220)
			stage.add_child(label)
	for frame in 12:
		for model in models:
			model.play_sample(model.get_meta("review_clip"), 1.0 / 60.0, model.get_meta("review_progress"))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("COMBAT_REVIEW_OUT")
	if out == "":
		out = "res://build/cass_combat_review.png"
	var err := stage.get_texture().get_image().save_png(out)
	print("Combat pose review: ", err, " ", out)
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit(err)
