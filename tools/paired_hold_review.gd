extends Node
var failures := 0
func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1440, 360)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var bg := ColorRect.new()
	bg.color = Color("191622")
	bg.size = Vector2(stage.size)
	stage.add_child(bg)
	var visuals := []
	var target_look := OS.get_environment("HOLD_REVIEW_LOOK")
	if target_look == "": target_look = "guard"
	for direction in 8:
		var cell := Node2D.new()
		cell.position = Vector2(70 + direction * 180, 195)
		cell.scale = Vector2.ONE * 4.0
		stage.add_child(cell)
		var angle := direction * TAU / 8.0
		for look in ["cass", target_look]:
			var visual := CharacterVisual.new()
			cell.add_child(visual)
			visual.setup(look)
			var source := OS.get_environment("HOLD_REVIEW_MODEL")
			if look != "cass": source = OS.get_environment("HOLD_REVIEW_TARGET_MODEL")
			if source != "":
				visual.cast_sprite.free()
				var cast := CastModel.new()
				assert(cast.configure(look, source))
				visual.cast_sprite = cast
				visual.rig.add_child(cast)
			visual.set_process(false)
			visual.set_weapon(null)
			visual.position = Vector2.from_angle(angle) * (6.0 if look != "cass" else 0.0)
			visual.set_aim(angle)
			visual.pose_override = "held" if look != "cass" else "grab"
			visuals.append(visual)
		var label := Label.new()
		label.position = Vector2(20 + direction * 180, 300)
		label.text = "Rear hold " + str(direction * 45)
		stage.add_child(label)
	for pose in 65:
		for visual in visuals:
			visual.pose_progress = minf(pose / 64.0, 0.995)
			visual.cast_sprite._body_init = false
			visual._process_cast(0.0)
			if visual.cast_sprite.clip != visual.pose_override or visual._arm.visible or absf(angle_difference(visual.rig.rotation,visual.aim_angle)) > 0.001:
				failures += 1
		await get_tree().process_frame
		if OS.get_environment("HOLD_CAPTURE_ALL") == "1" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png("res://build/sniper_held_pole_fixed_isolated/motion/%03d.png" % pose)
		if pose in [14,35,52] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png("res://build/execution_review/" + (target_look + "_" if OS.get_environment("HOLD_REVIEW_LOOK") != "" else ("compact_" if OS.get_environment("HOLD_REVIEW_MODEL") != "" else "rear_hold_")) + "%03d.png" % pose)
	print("PAIRED HOLD REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
