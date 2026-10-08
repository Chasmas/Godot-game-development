extends Node

func _ready() -> void:
	var job := Node.new()
	add_child(job)
	job.add_to_group("level")
	var stage := SubViewport.new()
	stage.size = Vector2i(540, 200)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(stage.size)
	background.z_index = -100
	stage.add_child(background)
	for i in 2:
		var p := Portrait.new()
		var talk_review := OS.get_environment("PORTRAIT_TALK_REVIEW") == "1"
		var wide_review := OS.get_environment("PORTRAIT_WIDE_REVIEW") == "1"
		var blink_review := OS.get_environment("PORTRAIT_BLINK_REVIEW") == "1"
		var character_review := OS.get_environment("PORTRAIT_CHARACTER_REVIEW")
		p.speaker = "cass" if talk_review or blink_review or wide_review else ["cass", "tommy"][i]
		if character_review != "": p.speaker = character_review
		p.talking = wide_review or (talk_review and i == 1)
		p._mouth = 1 if p.talking else 0
		p.position = Vector2(40 + i * 260, 20)
		p.size = Vector2(124, 124)
		stage.add_child(p)
		p.set_process(false)
		p.talking = true
		p.speech_energy = 0.8
		p._process(0.001)
		var opened := p._mouth == 2
		for sample in 20:
			p.speech_energy = 0.49 if sample % 2 == 0 else 0.51
			p._process(0.02)
			if p._mouth != 2:
				push_error("Small voice-energy fluctuations flicker the mouth frame")
				get_tree().quit(1)
				return
		p.speech_energy = 0.3
		p._process(0.02)
		if p._mouth != 1:
			push_error("Soft speech cannot leave the wide mouth frame")
			get_tree().quit(1)
			return
		p.speech_energy = 0.0
		p._process(0.001)
		if not opened or p._mouth != 0:
			push_error("Measured speech does not open/close the portrait mouth")
			get_tree().quit(1)
			return
		p.speech_energy = -1.0
		p.talking = wide_review or (talk_review and i == 1)
		if character_review != "": p.talking = wide_review or (not blink_review and i == 1)
		p._mouth = (i+1 if wide_review else 1) if p.talking else 0
		if not p.talking:
			p._mouth = 2
			p._mouth_t = 1.0
			p._process(0.001)
			if p._mouth != 0:
				push_error("Portrait mouth stays open after speech ends")
				get_tree().quit(1)
				return
		if blink_review and i == 1: p._blinking = 0.12
		# Expression captures freeze processing, so discard the transient
		# speaker-change glitch rather than freezing it across the whole face.
		p._glitch = 0.0
		var texture := p._art_frame()
		if texture == null or not texture.resource_path.begins_with("res://assets/art/pixellab_ui_v3_approved/portraits/"):
			push_error("Dialogue portrait falls back to incompatible art")
			get_tree().quit(1)
			return
		var speaking_frame := "cass_star_talk_wide.png" if p._mouth == 2 else "cass_star_talk.png"
		var expected := "cass_star_blink.png" if p._blinking > 0.0 else (speaking_frame if p.talking else "cass_star.png")
		if character_review != "":
			expected = character_review + ("_blink.png" if p._blinking > 0.0 else ("_talk_wide.png" if p.talking and p._mouth == 2 else ("_talk.png" if p.talking else ".png")))
			if not texture.resource_path.ends_with(expected):
				push_error("Character review does not resolve the requested authored expression")
				get_tree().quit(1)
				return
		if p.speaker == "cass" and not texture.resource_path.ends_with(expected):
			push_error("Job does not load the approved Cass star portrait")
			get_tree().quit(1)
			return
		print(p.speaker, " portrait: ", texture.resource_path)
		var label := Label.new()
		label.position = Vector2(40 + i * 260, 160)
		label.text = p.speaker.capitalize() + (" speaking" if p.talking else " resting") + " · dialogue scale"
		stage.add_child(label)
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := stage.get_texture().get_image().save_png("res://build/cass_portrait_style_review.png")
	print("PORTRAIT STYLE REVIEW: ", result)
	get_tree().quit(result)
