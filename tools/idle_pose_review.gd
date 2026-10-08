extends Node

func _ready() -> void:
	var look := OS.get_environment("IDLE_REVIEW_LOOK")
	if look == "":
		look = "guard"
	var consumables := OS.get_environment("IDLE_REVIEW_CONSUMABLES") == "1"
	var directions := OS.get_environment("IDLE_REVIEW_DIRECTIONS") == "1"
	var columns := 8 if directions else 6
	var stage := SubViewport.new()
	stage.size = Vector2i(columns * 220, 480)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.z_index = -100
	background.size = Vector2(stage.size)
	stage.add_child(background)
	var pairs: Array = []
	for row in 2:
		for col in columns:
			var cell := Node2D.new()
			cell.position = Vector2(110 + col * 220, 195 + row * 220)
			cell.scale = Vector2.ONE * 4.0
			stage.add_child(cell)
			var visual := CharacterVisual.new()
			cell.add_child(visual)
			visual.setup(look)
			var source := OS.get_environment("IDLE_REVIEW_MODEL")
			if source != "":
				visual.cast_sprite.free()
				var candidate := CastModel.new()
				if not candidate.configure(look, source):
					get_tree().quit(1)
					return
				visual.cast_sprite = candidate
				visual.rig.add_child(candidate)
			var facing := float(col) * TAU / columns if directions else 0.0
			visual._face_angle = facing
			visual.set_aim(facing)
			if visual.cast_sprite is CastModel:
				# Frozen samples must initialize the hips to this facing too.
				(visual.cast_sprite as CastModel)._body_init = false
			visual.set_weapon(DB.weapon(&"pistol"), OS.get_environment("IDLE_REVIEW_DUAL") == "1")
			var activity := IdleActivity.new()
			visual.rig.add_child(activity)
			var kind := (IdleActivity.Kind.DRINK if row == 0 else IdleActivity.Kind.EAT) if consumables else (IdleActivity.Kind.SMOKE if row == 0 else IdleActivity.Kind.SNOOZE)
			activity.setup(visual, kind, "review")
			if col == 0: print("ACTIVITY_REVIEW ", kind, " pose=",visual.idle_activity_pose," clips=",visual.cast_sprite.clips.keys())
			visual.set_process(false)
			activity.set_process(false)
			var phase := (0.33 if row == 0 else 0.5) if directions else float(col) / 6.0
			pairs.append([visual, activity, phase])
			var label := Label.new()
			label.text = "%s  %s" % [("Drink" if row == 0 else "Eat") if consumables else ("Smoke" if row == 0 else "Doze"), "%d°" % int(rad_to_deg(facing)) if directions else "%.2f" % phase]
			label.position = Vector2(20 + col * 220, 210 + row * 220)
			stage.add_child(label)
	for frame in 12:
		for pair in pairs:
			var visual: CharacterVisual = pair[0]
			var activity: IdleActivity = pair[1]
			activity._t = float(pair[2]) * activity._cycle
			activity._process(0.0)
			visual._process_cast(0.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := stage.get_texture().get_image().save_png("res://build/%s_idle_review%s.png" % [look, ("_consumables" if consumables else "") + ("_directions" if directions else "") + ("_dual" if OS.get_environment("IDLE_REVIEW_DUAL") == "1" else "")])
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit(err)
