extends Node
func _ready() -> void:
	var rows: Array = []
	var looks := PackedStringArray(["guard", "hunter", "heavy", "biker", "bellhop"])
	if OS.get_environment("AIM_REVIEW_LOOKS") != "":
		looks = OS.get_environment("AIM_REVIEW_LOOKS").split(",",false)
	elif OS.get_environment("AIM_REVIEW_ALL") == "1":
		looks.clear()
		for directory in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
			if directory not in ["cass", "eldorado"] and FileAccess.file_exists(CastModel.RT_PATH % [directory,directory]):
				looks.append(directory)
	for look in looks:
		var cast: CastModel
		if OS.get_environment("AIM_REVIEW_CANDIDATE") == "1":
			cast = CastModel.new()
			var source := OS.get_environment("AIM_REVIEW_SOURCE")
			if source.is_empty(): source="res://build/stationary_aim_candidates/%s.glb" % look
			assert(cast.configure(look,source))
		else:
			cast = CastModel.create(look) as CastModel
		assert(cast != null)
		add_child(cast)
		for requested in ["idle", "aim", "aim_dual"]:
			if not cast.clips.has(requested): continue
			var positions := {}
			for phase in 33:
				cast.play_sample(requested, 0, phase / 33.0)
				for name in ["LeftFoot", "RightFoot", "Head"]:
					var index := cast._skeleton.find_bone(name)
					assert(index >= 0)
					var point := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(index).origin)
					if not positions.has(name): positions[name] = []
					positions[name].append(point)
			var spans := {}
			for name in positions:
				var span := 0.0
				for a in positions[name]:
					for b in positions[name]: span = maxf(span, a.distance_to(b))
				spans[name] = span
			rows.append({"look": look, "requested": requested, "actual": cast.clip, "bone_motion_metres": spans})
			if OS.get_environment("AIM_REVIEW_CANDIDATE") == "1" and requested.begins_with("aim"):
				assert(spans.LeftFoot < .0001 and spans.RightFoot < .0001)
				assert(spans.Head > .001, "upper body must remain animated")
			print("STATIONARY_AIM ", look, " ", requested, " -> ", cast.clip, " motion=", spans)
		cast.queue_free()
		await get_tree().process_frame
	var output := FileAccess.open("res://build/stationary_aim_anatomy_review.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(rows, "  "))
	print("STATIONARY AIM ANATOMY REVIEW: ",rows.size()," sampled clips in ",looks.size()," models")
	Game.request_quit(0)
