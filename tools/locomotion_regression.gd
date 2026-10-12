extends Node

var failures := 0

func _ready() -> void:
	var looks := DirAccess.get_directories_at("res://assets/art/cast3d_rt")
	var requested_look := OS.get_environment("LOCOMOTION_REVIEW_LOOK")
	for look in looks:
		if requested_look != "" and look != requested_look: continue
		if look == "eldorado": continue # vehicle, not a walking actor
		var model := CastModel.create(look)
		if not model is CastModel:
			continue
		add_child(model)
		for requested in ["walk", "run", "sneak", "armed_walk", "armed_run", "armed_sneak"]:
			var clip_name: String = model._available(requested)
			var base := clip_name.trim_prefix("armed_").trim_prefix("dual_").trim_prefix("melee_")
			if base not in ["walk", "run", "sneak"]:
				failures += 1
				push_error(look + " substitutes a stationary pose for " + requested)
			var player: AnimationPlayer = model._player
			var anim := player.get_animation(clip_name)
			if anim.loop_mode != Animation.LOOP_LINEAR:
				failures += 1
				push_error(look + " does not loop " + clip_name)
			model.moving = true
			model.move_speed = 100.0
			for frame in 900:
				model.play_sample(requested, 1.0 / 60.0)
			if not player.is_playing():
				failures += 1
				push_error(look + " stopped after sustained motion: " + requested)
			print(look, " ", requested, " still playing after 15 seconds")
			# A character scraping slowly along a wall must not keep full strides.
			for speed in [0.0, 3.0, 20.0]:
				player.seek(0.0, true)
				model.move_speed = speed
				model.play_sample(requested, 0.1)
				var native: float=float(model._contact_native_speed.get(base,CastModel.NATIVE_SPEED[base]))
				var expected: float = 0.1 * float(speed) / native
				if absf(player.current_animation_position - expected) > 0.002:
					failures += 1
					push_error(look + " gait does not follow slow travel: " + str(speed))
		model.play_sample("run", 0.0)
		model._player.seek(model._player.get_animation(model.clip).length * 0.37, true)
		for next_pose in ["armed_run", "armed_sneak", "sneak", "run"]:
			model.play_sample(next_pose, 0.0)
			var phase: float = model._player.current_animation_position / model._player.get_animation(model.clip).length
			if absf(phase - 0.37) > 0.002:
				failures += 1
				push_error(look + " resets footfall phase when changing to " + next_pose)
		model.queue_free()
	print("LOCOMOTION REGRESSION: ", failures, " failures")
	get_tree().quit(1 if failures else 0)

