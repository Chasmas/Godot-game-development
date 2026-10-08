extends Node2D

func _ready() -> void:
	var rows: Array = []
	var directory := DirAccess.open("res://assets/art/cast3d_rt")
	assert(directory != null)
	var sources: Array = Array(directory.get_directories())
	sources.append("guard_direct")
	for entry in sources:
		var id: String = "guard" if entry == "guard_direct" else str(entry)
		if not FileAccess.file_exists(CastModel.RT_PATH % [id,id]): continue
		var cast := CastModel.new()
		cast.configure(id, CastModel.RT_PATH % [id,id] if entry == "guard_direct" else "")
		add_child(cast)
		if cast._player == null or not cast._player.has_animation("doze"):
			cast.queue_free()
			continue
		for phase in [0.0,0.25,0.5,0.75]:
			cast.play_sample("doze",0.0,phase)
			var legs: Array = []
			for side in ["Left","Right"]:
				var points: Array[Vector3] = []
				for suffix in ["UpLeg","Leg","Foot"]:
					var bone := cast._skeleton.find_bone(side+suffix)
					if bone < 0: continue
					points.append(cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(bone).origin))
				if points.size() != 3: continue
				var thigh := points[1]-points[0]
				var shin := points[2]-points[1]
				legs.append({"side":side,"knee_bend_degrees":rad_to_deg(thigh.angle_to(shin)),"hip_height_m":points[0].y,"foot_height_m":points[2].y,"thigh_vertical_fraction":absf(thigh.normalized().y)})
			rows.append({"id":entry,"phase":phase,"legs":legs})
		cast.queue_free()
		await get_tree().process_frame
	var report := FileAccess.open("res://build/seated_cast_anatomy_review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_approved":false,"scope":"Current production doze clip joint geometry; visual quality not inferred from socket alignment","rows":rows},"  "))
	report.close()
	print("SEATED ANATOMY: ",rows.size()," production samples recorded")
	Game.request_quit(0)
