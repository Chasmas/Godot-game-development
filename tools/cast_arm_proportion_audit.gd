extends SceneTree

func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	var report: Array=[]
	var looks := DirAccess.get_directories_at("res://assets/art/cast3d_rt/")
	for look in looks:
		if not ResourceLoader.exists("res://assets/art/cast3d_rt/%s/%s.glb" % [look,look]):continue
		var packed := load("res://assets/art/cast3d_rt/%s/%s.glb" % [look,look]) as PackedScene
		if packed==null:continue
		var model := packed.instantiate()
		root.add_child(model)
		var skeletons := model.find_children("*","Skeleton3D",true,false)
		var players := model.find_children("*","AnimationPlayer",true,false)
		if skeletons.is_empty() or players.is_empty():
			print("CAST ARM AUDIT: static model skipped: ",look)
			model.free();continue
		var skeleton := skeletons[0] as Skeleton3D
		var player := players[0] as AnimationPlayer
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in ["idle","smoke","aim","armed_walk","aim_melee","armed_melee_walk","melee","stab","punch"]:
			if not player.has_animation(clip):continue
			var samples: Array=[]
			player.play(clip,0)
			for phase in [0.0,.25,.5,.75]:
				player.seek(player.get_animation(clip).length*phase,true)
				player.advance(.00001)
				skeleton.force_update_all_bone_transforms()
				var arms: Dictionary={}
				for side in ["Left","Right"]:
					var points: Array[Vector3]=[]
					for suffix in ["Arm","ForeArm","Hand"]:
						var index := skeleton.find_bone(side+suffix)
						if index>=0:points.append(skeleton.to_global(skeleton.get_bone_global_pose(index).origin))
					if points.size()==3:arms[side]={"upper_m":points[0].distance_to(points[1]),"forearm_m":points[1].distance_to(points[2]),"reach_m":points[0].distance_to(points[2])}
				samples.append({"phase":phase,"arms":arms})
			report.append({"look":look,"clip":clip,"samples":samples})
		model.free()
	var file := FileAccess.open("res://build/cast_arm_proportion_audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("CAST ARM AUDIT: ",report.size()," sampled look/clip combinations")
	quit()
