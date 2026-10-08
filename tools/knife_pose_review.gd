extends Node

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1320, 300)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(stage.size)
	background.z_index = -100
	stage.add_child(background)
	var visuals: Array[CharacterVisual] = []
	var phases := [0.0, 0.22, 0.45, 0.62, 0.8, 0.995]
	for column in 6:
		var rig := Node2D.new()
		rig.position = Vector2(110 + column * 220, 210)
		rig.scale = Vector2.ONE * 4
		stage.add_child(rig)
		var visual := CharacterVisual.new()
		rig.add_child(visual)
		visual.setup("cass")
		visual.cast_sprite.free()
		var candidate := CastModel.new()
		if not candidate.configure("cass", "res://build/cast_activity_candidates/cass.glb"):
			get_tree().quit(1)
			return
		visual.cast_sprite = candidate
		visual.rig.add_child(candidate)
		visual.set_weapon(DB.weapon(&"knife"))
		visual.set_aim(0)
		visual.swing(false, true)
		visual.set_process(false)
		visuals.append(visual)
		var label := Label.new()
		label.position = Vector2(20 + column * 220, 255)
		label.text = "Knife %.2f" % phases[column]
		stage.add_child(label)
	for frame in 12:
		for column in 6:
			visuals[column]._swing_t = phases[column] * visuals[column]._swing_dur
			visuals[column]._process_cast(0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := stage.get_texture().get_image().save_png("res://build/knife_pose_review.png")
	stage.queue_free()
	await get_tree().process_frame
	print("KNIFE POSE REVIEW: ", result)
	get_tree().quit(result)
