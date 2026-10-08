extends Node

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1320, 600)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(stage.size)
	background.z_index = -100
	stage.add_child(background)
	var visuals: Array[CharacterVisual] = []
	var phases := [0.0, 0.22, 0.45, 0.62, 0.8, 0.995]
	for cell_index in 12:
		var column := cell_index % 6
		var row := cell_index / 6
		var rig := Node2D.new()
		rig.position = Vector2(110 + column * 220, 210 + row * 300)
		rig.scale = Vector2.ONE * 4
		stage.add_child(rig)
		var visual := CharacterVisual.new()
		rig.add_child(visual)
		visual.setup("cass")
		visual.cast_sprite.free()
		var candidate := CastModel.new()
		if not candidate.configure("cass", ("res://assets/art/cast3d_rt/cass/cass.glb" if row == 0 else "res://build/cass_stab_reach/cass.glb")):
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
		label.position = Vector2(20 + column * 220, 255 + row * 300)
		label.text = ("Runtime" if row == 0 else "Extended") + " %.2f" % phases[column]
		stage.add_child(label)
	for frame in 12:
		for index in 12:
			visuals[index].cast_sprite._body_init = false
			visuals[index]._swing_t = phases[index % 6] * visuals[index]._swing_dur
			visuals[index]._process_cast(0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := stage.get_texture().get_image().save_png("res://build/cass_stab_reach/pose_comparison.png")
	stage.queue_free()
	await get_tree().process_frame
	print("KNIFE POSE REVIEW: ", result)
	Game.request_quit(result)
