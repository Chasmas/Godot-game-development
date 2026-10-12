extends Node

func _ready() -> void:
	var report := {"units": "game pixels per second; 16 pixels per metre", "models": {}}
	for id in ["cass", "guard", "gunner", "biker", "bellhop", "handler", "heavy", "hunter", "security", "sniper", "stagehand", "civilian", "boss", "buck", "fireman", "riot", "scout", "scrapper", "welder", "burnt", "cultist", "ghoul", "zombie", "demon"]:
		var path := CastModel.RT_PATH % [id, id]
		var model := (load(path) as PackedScene).instantiate()
		add_child(model)
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var feet := [skeleton.find_bone("LeftFoot"), skeleton.find_bone("RightFoot")]
		var clips := {}
		for clip in player.get_animation_list():
			var base := str(clip).trim_prefix("armed_").trim_prefix("dual_").trim_prefix("melee_")
			if not base in ["walk", "run", "sneak"] or feet.has(-1): continue
			var duration := player.get_animation(clip).length
			player.play(clip, 0)
			var samples: Array = []
			for frame in 121:
				player.seek(duration * float(frame) / 121.0, true)
				player.advance(0.00001)
				var positions := []
				for foot in feet: positions.append(skeleton.global_transform * skeleton.get_bone_global_pose(foot).origin)
				samples.append(positions)
			var velocities: Array[float] = []
			for side in 2:
				var low := INF
				var high := -INF
				for sample in samples:
					low = minf(low, sample[side].y)
					high = maxf(high, sample[side].y)
				for frame in range(1, samples.size()):
					var a: Vector3 = samples[frame - 1][side]
					var b: Vector3 = samples[frame][side]
					if maxf(a.y, b.y) <= low + (high - low) * .35:
						velocities.append(absf(b.z - a.z) * 121.0 / duration * 16.0)
			velocities.sort()
			clips[clip] = {"duration": duration, "stance_samples": velocities.size(), "median_stance_speed": velocities[velocities.size() / 2] if not velocities.is_empty() else 0}
		report.models[id] = {"sha256": FileAccess.get_sha256(path), "clips": clips}
		model.free()
	var file := FileAccess.open("res://build/locomotion_stride_measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("LOCOMOTION STRIDE MEASUREMENTS DONE")
	Game.request_quit()
