extends Node
var failures := 0
func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1440, 540)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var bg := ColorRect.new()
	bg.color = Color("191622")
	bg.size = Vector2(stage.size)
	stage.add_child(bg)
	var visuals := []
	for row in 2:
		for direction in 8:
			var cell := Node2D.new()
			cell.position = Vector2(65 + direction * 180, 165 + row * 260)
			cell.scale = Vector2.ONE * 3.0
			stage.add_child(cell)
			var visual := CharacterVisual.new()
			cell.add_child(visual)
			visual.setup("cass")
			visual.cast_sprite.free()
			var cast := CastModel.new()
			if not cast.configure("cass", "res://assets/art/cast3d_rt/cass/cass.glb"):
				Game.request_quit(1)
				return
			visual.cast_sprite = cast
			visual.rig.add_child(cast)
			visual.set_weapon(DB.weapon(&"knife"))
			visual.set_aim(direction * TAU / 8.0)
			visual.set_process(false)
			visual.update_move(Vector2.RIGHT * 118.0, 0.0)
			for warmup in 24:
				visual._process_cast(1.0 / 120.0)
			visual.swing(row == 1,true)
			visuals.append(visual)
			var label := Label.new()
			label.position = Vector2(12 + direction * 180, 214 + row * 260)
			label.text = ("Light stab" if row == 0 else "Heavy slash") + " " + str(direction * 45)
			stage.add_child(label)
	for pose in 65:
		for visual in visuals:
			var delta: float = visual._swing_dur / 64.0
			visual.position += Vector2.RIGHT * 118.0 * delta
			visual._swing_t = maxf(0.0, (minf(pose / 64.0,0.995) - 1.0 / 64.0) * visual._swing_dur)
			visual._process_cast(delta)
			if visual._arm.visible or visual.cast_sprite.clip != ("melee" if visual._heavy_swing else "stab") or not is_finite(visual.muzzle_tip_global().x):
				failures += 1
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png("res://build/melee_trail_review/heavy_motion/%03d.png" % pose)
	for visual in visuals:
		visual.roll(Vector2.RIGHT,0.3)
		visual._process_cast(0.0)
		if visual.is_swinging():
			failures += 1
	print("MOVING HEAVY KNIFE REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
