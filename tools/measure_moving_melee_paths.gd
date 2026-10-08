extends Node
func _ready() -> void:
	var heavy := OS.get_environment("MELEE_PATH_HEAVY") == "1"
	var midpoint := OS.get_environment("MELEE_PATH_MIDPOINT") == "1"
	var output := OS.get_environment("MELEE_PATH_OUTPUT")
	if output == "":
		output = "moving_weapon_paths.json"
	assert(output == output.get_file() and output.get_extension() == "json")
	var report := {"runtime_model": "res://assets/art/cast3d_rt/cass/cass.glb", "runtime_sha256": FileAccess.get_sha256("res://assets/art/cast3d_rt/cass/cass.glb"), "heavy": heavy, "midpoint": midpoint, "samples": []}
	for weapon in ["bat", "knife"]:
		for direction in 16:
			var visual := CharacterVisual.new()
			add_child(visual)
			visual.setup("cass")
			visual.set_process(false)
			visual.set_weapon(DB.weapon(StringName(weapon)))
			var angle := (direction + (0.5 if midpoint else 0.0)) * TAU / 16.0
			visual.set_aim(angle)
			# Warm up a real lateral stride before the strike; do not reset hips per pose.
			visual._cast_velocity = Vector2.from_angle(angle + PI * 0.5) * 118.0
			for warmup in 24:
				visual._process_cast(1.0 / 120.0)
			visual.swing(heavy, weapon == "knife")
			var points := []
			for frame in 65:
				var phase := minf(frame / 64.0, 0.995)
				visual._swing_t = maxf(0.0, (phase - 1.0 / 64.0) * visual._swing_dur)
				visual.position += visual._cast_velocity * visual._swing_dur / 64.0
				visual._process_cast(visual._swing_dur / 64.0)
				var hand := visual.rig.to_global(visual._hand) - visual.global_position
				var tip := visual.muzzle_tip_global() - visual.global_position
				points.append({"phase":(visual.cast_sprite as CastModel)._progress,"hand":[hand.x,hand.y],"tip":[tip.x,tip.y],"sprite_angle": visual.weapon_sprite.global_rotation, "clip": visual.cast_sprite.clip})
			report.samples.append({"weapon":weapon,"angle":angle,"points":points})
			visual.free()
	var file := FileAccess.open("res://build/melee_trail_review/" + output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("MELEE PATHS: 2080 moving hand and weapon-tip samples exported")
	Game.request_quit()
