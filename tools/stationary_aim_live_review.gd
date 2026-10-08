extends Node

func _ready() -> void:
	var checked := 0
	for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
		if look in ["cass", "eldorado"]: continue
		var selected := OS.get_environment("AIM_REVIEW_LOOKS")
		if not selected.is_empty() and not look in selected.split(",",false): continue
		var cast: CastModel
		var source := OS.get_environment("AIM_REVIEW_SOURCE")
		if source.is_empty():
			cast=CastModel.create(look) as CastModel
		else:
			cast=CastModel.new()
			assert(cast.configure(look,source))
		assert(cast != null)
		add_child(cast)
		var review_clips: Array = ["idle", "aim", "aim_dual"]
		if not OS.get_environment("AIM_REVIEW_CLIPS").is_empty():
			review_clips = Array(OS.get_environment("AIM_REVIEW_CLIPS").split(",",false))
		for clip in review_clips:
			assert(cast.clips.has(clip))
			var length := cast._player.get_animation(clip).length
			assert(cast._player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR)
			var frames := ceili(length * 60 * 3) + 90
			var points: Array[Vector3] = []
			for frame in frames:
				cast.play_sample(clip,1.0/60.0)
				if frame >= frames-90:
					points.append(cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._head).origin))
			var span := 0.0
			for a in points:
				for b in points: span = maxf(span,a.distance_to(b))
			assert(span > .001,"aim breathing must remain alive after three full loops")
			assert(cast._player.is_playing())
			checked += 1
		cast.queue_free()
		await get_tree().process_frame
	print("LIVE STATIONARY AIM REVIEW: ",checked," clips remain animated after three loops")
	Game.request_quit(0)
