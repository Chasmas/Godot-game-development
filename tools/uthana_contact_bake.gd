extends Node
var _maximum_reach_deficit := 0.0
## Bake small support corrections onto Uthana poses. Runtime is never modified.
func _ready() -> void:
	var id := OS.get_environment("UTHANA_MERGE_CAST")
	if id.is_empty(): id = "guard"
	var directory := "res://build/uthana/cast_roster/motions/%s/merged/" % id
	var targets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"contact_targets.json"))
	var source := load(directory+"contact_library.res") as AnimationLibrary
	var output := source.duplicate(true) as AnimationLibrary
	var actor := (load(CastModel.RT_PATH % [id,id]) as PackedScene).instantiate()
	add_child(actor)
	var skeleton := actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var player := actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("study",source)
	var records: Array = []
	for clip in targets.clips:
		var gait: String = clip.gait
		var duration: float = clip.duration_seconds
		var poses: Dictionary = {}
		var worst := 0.0
		var smallest_knee := PI
		_maximum_reach_deficit = 0.0
		for side in ["Left","Right"]:
			for suffix in ["UpLeg","Leg","Foot"]: poses[side+suffix] = []
		player.play("study/armed_"+gait,0)
		# Find one constant pelvis adjustment for the cycle. This preserves the
		# generated bounce and avoids frame-dependent body pumping.
		var pelvis_drop := 0.0
		for frame in 241:
			player.seek(duration*frame/240.0,true)
			player.advance(.000001)
			skeleton.force_update_all_bone_transforms()
			for side_index in 2:
				var side: String = "Left" if side_index==0 else "Right"
				var h := _world(skeleton,skeleton.find_bone(side+"UpLeg")).origin
				var k := _world(skeleton,skeleton.find_bone(side+"Leg")).origin
				var f := _world(skeleton,skeleton.find_bone(side+"Foot")).origin
				var values: Array = clip.feet[side_index].targets[frame]
				var t := Vector3(values[0],values[1],values[2])
				var reach := h.distance_to(k)+k.distance_to(f)-.002
				var horizontal := Vector2(h.x-t.x,h.z-t.z).length_squared()
				assert(horizontal<reach*reach,"Foot target exceeds horizontal leg reach")
				pelvis_drop=maxf(pelvis_drop,h.y-t.y-sqrt(reach*reach-horizontal))
		assert(pelvis_drop<.05,"Pelvis adjustment needs an authored gait review")
		var hip_positions: Array[Vector3] = []
		var hip_bone := skeleton.find_bone("Hips")
		for frame in 241:
			player.seek(duration*frame/240.0,true)
			player.advance(.000001)
			skeleton.force_update_all_bone_transforms()
			var local_drop := skeleton.global_basis.inverse()*Vector3(0,pelvis_drop,0)
			var parent := skeleton.get_bone_parent(hip_bone)
			if parent>=0: local_drop=skeleton.get_bone_global_pose(parent).basis.inverse()*local_drop
			skeleton.set_bone_pose_position(hip_bone,skeleton.get_bone_pose_position(hip_bone)-local_drop)
			skeleton.force_update_all_bone_transforms()
			hip_positions.append(skeleton.get_bone_pose_position(hip_bone))
			for side_index in 2:
				var side: String = "Left" if side_index==0 else "Right"
				var values: Array = clip.feet[side_index].targets[frame]
				var target := Vector3(values[0],values[1],values[2])
				worst=maxf(worst,_solve(skeleton,side,target))
				var hip := _world(skeleton,skeleton.find_bone(side+"UpLeg")).origin
				var knee := _world(skeleton,skeleton.find_bone(side+"Leg")).origin
				var ankle := _world(skeleton,skeleton.find_bone(side+"Foot")).origin
				smallest_knee=minf(smallest_knee,acos(clampf((hip-knee).normalized().dot((ankle-knee).normalized()),-1,1)))
			for bone_name in poses:
				poses[bone_name].append(skeleton.get_bone_pose_rotation(skeleton.find_bone(bone_name)))
		for prefix in ["","armed_","armed_dual_","armed_melee_"]:
			var name: String = prefix+gait
			if not output.has_animation(name): continue
			var animation := output.get_animation(name)
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				var bone := str(path.get_subname(0)) if path.get_subname_count()>0 else ""
				if bone=="Hips" and animation.track_get_type(track)==Animation.TYPE_POSITION_3D:
					for key in range(animation.track_get_key_count(track)-1,-1,-1): animation.track_remove_key(track,key)
					for frame in 241: animation.track_insert_key(track,duration*frame/240.0,hip_positions[frame])
					continue
				if not poses.has(bone) or animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D: continue
				for key in range(animation.track_get_key_count(track)-1,-1,-1): animation.track_remove_key(track,key)
				for frame in 241: animation.track_insert_key(track,duration*frame/240.0,poses[bone][frame])
		records.append({"gait":gait,"pelvis_drop_m":pelvis_drop,"worst_target_error_m":worst,"maximum_unreachable_distance_m":_maximum_reach_deficit,"minimum_knee_angle_degrees":rad_to_deg(smallest_knee),"contact_target_gate":worst<.002,"anatomical_fold_gate":smallest_knee>deg_to_rad(25)})
	output.set_meta("runtime_approved",false)
	assert(ResourceSaver.save(output,directory+"contact_corrected_library.res",ResourceSaver.FLAG_COMPRESS)==OK)
	var report := FileAccess.open(directory+"contact_bake_review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_approved":false,"cast":id,"clips":records,"pending":"Subframe contacts, temporal visual and upper-body parity review"},"\t"))
	print("UTHANA CONTACT BAKED ",JSON.stringify(records))
	Game.request_quit(0)

func _world(skeleton: Skeleton3D,bone: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone)

func _rotation(skeleton: Skeleton3D,bone: int,value: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var axes := skeleton.global_basis
	if parent>=0: axes *= skeleton.get_bone_global_pose(parent).basis
	skeleton.set_bone_pose_rotation(bone,axes.orthonormalized().get_rotation_quaternion().inverse()*value)
	skeleton.force_update_all_bone_transforms()

func _solve(skeleton: Skeleton3D,side: String,target: Vector3) -> float:
	var thigh := skeleton.find_bone(side+"UpLeg")
	var shin := skeleton.find_bone(side+"Leg")
	var foot := skeleton.find_bone(side+"Foot")
	var hip := _world(skeleton,thigh)
	var knee := _world(skeleton,shin)
	var ankle := _world(skeleton,foot)
	var rotation := ankle.basis.orthonormalized().get_rotation_quaternion()
	var a := hip.origin.distance_to(knee.origin)
	var b := knee.origin.distance_to(ankle.origin)
	var direction := (target-hip.origin).normalized()
	_maximum_reach_deficit = maxf(_maximum_reach_deficit, target.distance_to(hip.origin)-(a+b))
	var distance := clampf(target.distance_to(hip.origin),absf(a-b)+.000001,a+b-.000001)
	var along := (a*a-b*b+distance*distance)/(2*distance)
	# Preserve the generated knee plane instead of imposing a global pole.
	var pole := knee.origin-hip.origin
	pole -= direction*pole.dot(direction)
	if pole.length_squared()<.000001: pole=direction.cross(Vector3.RIGHT)
	var target_knee := hip.origin+direction*along+pole.normalized()*sqrt(maxf(0,a*a-along*along))
	_rotation(skeleton,thigh,Quaternion((knee.origin-hip.origin).normalized(),(target_knee-hip.origin).normalized())*hip.basis.orthonormalized().get_rotation_quaternion())
	knee=_world(skeleton,shin)
	ankle=_world(skeleton,foot)
	_rotation(skeleton,shin,Quaternion((ankle.origin-knee.origin).normalized(),(target-knee.origin).normalized())*knee.basis.orthonormalized().get_rotation_quaternion())
	_rotation(skeleton,foot,rotation)
	return _world(skeleton,foot).origin.distance_to(target)
