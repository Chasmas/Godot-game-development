extends Node

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 840)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(stage.size)
	background.z_index = -100
	stage.add_child(background)
	var visuals: Array[CharacterVisual] = []
	for row in 4:
		for column in 8:
			var cell := Node2D.new()
			cell.position = Vector2(80 + column * 160, 145 + row * 205)
			cell.scale = Vector2.ONE * 3.0
			stage.add_child(cell)
			var visual := CharacterVisual.new()
			cell.add_child(visual)
			visual.setup("cass")
			visual.set_process(false)
			visual.set_weapon(DB.weapon(&"bat") if row == 2 else (DB.weapon(&"knife") if row == 3 else null))
			visual.set_aim(float(column) * TAU / 8.0)
			visual._face_angle = visual.aim_angle
			if row < 2:
				visual.punch()
				visual._punch_left = row == 1
				visual._punch_t = CharacterVisual.PUNCH_DURATION * CharacterVisual.PUNCH_CONTACT
			else:
				visual.swing(false, row == 3)
				visual._swing_t = visual._swing_dur * (0.62 if row == 3 else 0.58)
			visual.set_aim(visual.aim_angle + PI)
			visuals.append(visual)
			var label := Label.new()
			label.position = Vector2(column * 160 + 12, row * 205 + 178)
			label.text = "%s %d°" % [["Right", "Left", "Bat", "Knife"][row], column * 45]
			stage.add_child(label)
	for frame in 12:
		for visual in visuals:
			visual._process_cast(0.0)
			if visual._arm.visible:
				push_error("Duplicate procedural arm in rendered combat")
				get_tree().quit(1)
				return
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := stage.get_texture().get_image().save_png("res://build/cass_combat_committed_directions.png")
	stage.queue_free()
	await get_tree().process_frame
	print("COMBAT DIRECTION REVIEW: ", result)
	Game.request_quit(result)
