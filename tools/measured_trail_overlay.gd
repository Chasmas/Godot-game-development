extends Node
func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 430)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var visuals := []
	for row in 2:
		var weapon := "bat" if row == 0 else "knife"
		for direction in 8:
			var cell := Node2D.new()
			cell.position = Vector2(80 + direction * 160, 165 + row * 210)
			cell.scale = Vector2.ONE * 3.0
			viewport.add_child(cell)
			var visual := CharacterVisual.new()
			cell.add_child(visual)
			visual.setup("cass")
			visual.set_process(false)
			visual.set_weapon(DB.weapon(StringName(weapon)))
			visual.set_aim(direction * TAU / 8.0)
			visual.swing(false, weapon == "knife")
			visual._swing_t = visual._swing_dur * 0.62
			visuals.append(visual)
			var trail := Sprite2D.new()
			trail.texture = load("res://build/melee_trail_review/measured/%s/%d/005.png" % [weapon, direction * 45])
			trail.scale = Vector2.ONE * 80.0 / 256.0
			trail.z_index = 25
			cell.add_child(trail)
			var label := Label.new()
			label.position = Vector2(12 + direction * 160, 183 + row * 210)
			label.text = "%s %d degrees" % [weapon, direction * 45]
			viewport.add_child(label)
	for frame in 12:
		for visual in visuals:
			(visual.cast_sprite as CastModel)._body_init = false
			visual._process_cast(0.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://build/melee_trail_review/measured/overlay.png")
	print("MEASURED TRAIL OVERLAY: captured")
	Game.request_quit()
