extends Node2D
func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1200, 700)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	for i in 8:
		var visual := CharacterVisual.new()
		stage.add_child(visual)
		visual.setup("cass")
		if OS.get_environment("CHAINSAW_POSE_MODEL") != "":
			visual.cast_sprite.free()
			var model := CastModel.new()
			assert(model.configure("cass", OS.get_environment("CHAINSAW_POSE_MODEL")))
			visual.cast_sprite = model
			visual.rig.add_child(model)
		visual.set_weapon(DB.weapon(&"chainsaw"))
		visual.idle_fidgets = false
		visual.position = Vector2(150 + (i % 4) * 300, 230 + (i / 4) * 320)
		visual.scale = Vector2.ONE * 6.0
		visual.set_aim(i * PI * 0.25)
		visual.set_powered_cutting(true)
		var label := Label.new()
		label.text = str(i * 45) + " degrees"
		label.position = Vector2(110 + (i % 4) * 300, 280 + (i / 4) * 320)
		stage.add_child(label)
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(OS.get_environment("CHAINSAW_POSE_IMAGE") if OS.get_environment("CHAINSAW_POSE_IMAGE") != "" else "res://build/chainsaw_facings.png")
	Audio.shutdown()
	get_tree().quit()
