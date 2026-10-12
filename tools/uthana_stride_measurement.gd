extends Node
## Measure actual low-foot travel, including variation during stance, rather
## than assigning the requested API speed as an animation calibration.
func _ready() -> void:
	var id := OS.get_environment("UTHANA_MERGE_CAST")
	if id.is_empty(): id = "guard"
	var actor := (load(CastModel.RT_PATH % [id,id]) as PackedScene).instantiate()
	add_child(actor)
	var skeleton := actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var player := actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := load("res://build/uthana/cast_roster/motions/%s/merged/contact_library.res" % id) as AnimationLibrary
	player.add_animation_library("review",library)
	var records: Array = []
	for gait in ["walk","run","sneak"]:
		var name: String = "review/armed_"+gait
		var duration := player.get_animation(name).length
		player.play(name,0)
		var per_foot: Array = []
		for side in 2:
			var foot := skeleton.find_bone("LeftFoot" if side==0 else "RightFoot")
			var samples: Array[Vector3] = []
			var lowest := INF
			var highest := -INF
			for frame in 241:
				player.seek(duration*frame/240.0,true)
				player.advance(.000001)
				skeleton.force_update_all_bone_transforms()
				var point := skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
				samples.append(point)
				lowest=minf(lowest,point.y)
				highest=maxf(highest,point.y)
			var velocities: Array[float] = []
			for frame in range(1,240):
				if maxf(samples[frame].y,samples[frame-1].y)>lowest+(highest-lowest)*.25: continue
				velocities.append((samples[frame].z-samples[frame-1].z)*240/duration)
			velocities.sort()
			assert(not velocities.is_empty())
			var trajectory: Array = []
			for point in samples: trajectory.append([point.x,point.y,point.z])
			per_foot.append({"side":side,"samples":velocities.size(),"median_signed_m_s":velocities[velocities.size()/2],"minimum_m_s":velocities.front(),"maximum_m_s":velocities.back(),"foot_height_range_m":highest-lowest,"trajectory":trajectory})
		records.append({"gait":gait,"duration_seconds":duration,"feet":per_foot})
	var output := FileAccess.open("res://build/uthana/cast_roster/motions/%s/merged/stride_measurement.json" % id,FileAccess.WRITE)
	output.store_string(JSON.stringify({"cast":id,"runtime_approved":false,"clips":records},"\t"))
	print("UTHANA STRIDE MEASURED ",id," three cycles with 241 samples per foot")
	Game.request_quit(0)
