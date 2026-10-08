extends Node
func _ready() -> void:
	var report := {"runtime_model": "res://assets/art/cast3d_rt/cass/cass.glb", "samples": []}
	for weapon in ["bat", "knife"]:
		for direction in 16:
			var visual := CharacterVisual.new()
			add_child(visual)
			visual.setup("cass")
			visual.set_process(false)
			visual.set_weapon(DB.weapon(StringName(weapon)))
			var angle := (direction + 0.5) * TAU / 16.0
			visual.set_aim(angle)
			# Warm up a real lateral stride before the strike; do not reset hips per pose.
			visual._cast_velocity = Vector2.from_angle(angle + PI * 0.5) * 118.0
			for warmup in 24:
				visual._process_cast(1.0 / 120.0)
			visual.swing(false, weapon == "knife")
			var points := []
			for frame in 65:
				var phase := minf(frame / 64.0, 0.995)
				visual._swing_t = maxf(0.0, (phase - 1.0 / 64.0) * visual._swing_dur)
				visual.position += visual._cast_velocity * visual._swing_dur / 64.0
				visual._process_cast(visual._swing_dur / 64.0)
				var hand := visual.rig.to_global(visual._hand) - visual.global_position
				var tip := visual.muzzle_tip_global() - visual.global_position
				points.append({"phase":(visual.cast_sprite as CastModel)._progress,"hand":[hand.x,hand.y],"tip":[tip.x,tip.y],"sprite_angle": visual.weapon_sprite.global_rotation})
			report.samples.append({"weapon":weapon,"angle":angle,"points":points})
			visual.free()
	var file := FileAccess.open("res://build/melee_trail_review/moving_weapon_paths_32_midpoints.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("MELEE PATHS: 2080 moving hand and weapon-tip samples exported")
	Game.request_quit()
