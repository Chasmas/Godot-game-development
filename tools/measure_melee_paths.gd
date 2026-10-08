extends Node
func _ready() -> void:
	var heavy := OS.get_environment("MELEE_PATH_HEAVY") == "1"
	var directions := 16 if OS.get_environment("MELEE_PATH_DIRECTIONS") == "16" else 8
	var output := "actual_weapon_paths_16.json" if directions == 16 else "actual_weapon_paths.json"
	var requested := OS.get_environment("MELEE_PATH_OUTPUT")
	if requested != "":
		assert(requested == requested.get_file() and requested.get_extension() == "json")
		output = requested
	var report := {"runtime_model": "res://assets/art/cast3d_rt/cass/cass.glb", "runtime_sha256": FileAccess.get_sha256("res://assets/art/cast3d_rt/cass/cass.glb"), "heavy": heavy, "samples": []}
	for weapon in ["bat", "knife"]:
		for direction in directions:
			var visual := CharacterVisual.new()
			add_child(visual)
			visual.setup("cass")
			visual.set_process(false)
			visual.set_weapon(DB.weapon(StringName(weapon)))
			var angle := direction * TAU / directions
			visual.set_aim(angle)
			visual.swing(heavy, weapon == "knife")
			var points := []
			for frame in 65:
				var phase := minf(frame / 64.0, 0.995)
				visual._swing_t = phase * visual._swing_dur
				(visual.cast_sprite as CastModel)._body_init = false
				visual._process_cast(0.0)
				var hand := visual.rig.to_global(visual._hand) - visual.global_position
				var tip := visual.muzzle_tip_global() - visual.global_position
				points.append({"phase":phase,"hand":[hand.x,hand.y],"tip":[tip.x,tip.y],"sprite_angle": visual.weapon_sprite.global_rotation, "clip": visual.cast_sprite.clip})
			report.samples.append({"weapon":weapon,"angle":angle,"points":points})
			visual.free()
	var file := FileAccess.open("res://build/melee_trail_review/" + output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("MELEE PATHS: ", directions * 130, " actual hand and weapon-tip samples exported")
	Game.request_quit()
