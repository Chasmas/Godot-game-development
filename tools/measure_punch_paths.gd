extends Node
func _ready() -> void:
	var source := OS.get_environment("PUNCH_REVIEW_MODEL")
	if source == "":
		source = "res://assets/art/cast3d_rt/cass/cass.glb"
	var output := OS.get_environment("PUNCH_REVIEW_OUTPUT")
	if output == "":
		output = "punch_paths_16.json"
	assert(output == output.get_file() and output.get_extension() == "json")
	var report := {"runtime_sha256": FileAccess.get_sha256(source), "samples": []}
	for left in [false, true]:
		for direction in 16:
			var visual := CharacterVisual.new()
			add_child(visual)
			visual.setup("cass")
			if source != "res://assets/art/cast3d_rt/cass/cass.glb":
				visual.cast_sprite.free()
				var cast := CastModel.new()
				assert(cast.configure("cass", source))
				visual.cast_sprite = cast
				visual.rig.add_child(cast)
			visual.set_process(false)
			visual.set_weapon(null)
			visual.set_aim(direction * TAU / 16.0)
			visual.punch()
			visual._punch_left = left
			var points := []
			for pose in 65:
				var phase := minf(pose / 64.0, 0.995)
				visual._punch_t = phase * CharacterVisual.PUNCH_DURATION
				visual.cast_sprite._body_init = false
				visual._process_cast(0.0)
				var hand := visual.rig.to_global(visual._hand2 if left else visual._hand) - visual.global_position
				points.append({"phase": phase, "tip": [hand.x, hand.y], "clip": visual.cast_sprite.clip})
			report.samples.append({"weapon": "punch_left" if left else "punch_right", "angle": direction * TAU / 16.0, "points": points})
			visual.free()
	var file := FileAccess.open("res://build/melee_trail_review/" + output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PUNCH PATHS: 2080 projected hand samples exported")
	Game.request_quit()
