extends Node
func _ready() -> void:
	var directory := "res://build/uthana/cast_roster/motions/guard/merged/"
	var original := load(directory+"contact_library.res") as AnimationLibrary
	var corrected := load(directory+"contact_corrected_library.res") as AnimationLibrary
	var targets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"contact_targets.json"))
	var actor := (load(CastModel.RT_PATH % ["guard","guard"]) as PackedScene).instantiate()
	add_child(actor)
	var skeleton := actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var player := actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("review",corrected)
	var unchanged_keys := 0
	for name in original.get_animation_list():
		var before := original.get_animation(name)
		var after := corrected.get_animation(name)
		assert(before.get_track_count()==after.get_track_count())
		for track in before.get_track_count():
			var path := before.track_get_path(track)
			var bone := str(path.get_subname(0)) if path.get_subname_count()>0 else ""
			if bone in ["Hips","LeftUpLeg","LeftLeg","LeftFoot","RightUpLeg","RightLeg","RightFoot"]: continue
			assert(before.track_get_key_count(track)==after.track_get_key_count(track))
			for key in before.track_get_key_count(track):
				assert(before.track_get_key_time(track,key)==after.track_get_key_time(track,key))
				assert(before.track_get_key_value(track,key)==after.track_get_key_value(track,key))
				unchanged_keys+=1
	var worst := 0.0
	for clip in targets.clips:
		player.play("review/armed_"+str(clip.gait),0)
		for frame in 960:
			var sample := frame/4.0
			var index := int(sample)
			player.seek(float(clip.duration_seconds)*sample/240.0,true)
			player.advance(.000001)
			skeleton.force_update_all_bone_transforms()
			for side in 2:
				var a: Array=clip.feet[side].targets[index]
				var b: Array=clip.feet[side].targets[index+1]
				var target := Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),sample-index)
				var bone := skeleton.find_bone("LeftFoot" if side==0 else "RightFoot")
				var actual := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
				worst=maxf(worst,actual.distance_to(target))
	assert(worst<.002,"Subframe contact exceeds 2mm: "+str(worst))
	var file := FileAccess.open(directory+"contact_subframe_review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"runtime_approved":false,"unchanged_upper_keys":unchanged_keys,"samples_per_gait":960,"worst_target_error_m":worst},"\t"))
	print("UTHANA CONTACT SUBFRAME PASSED keys=",unchanged_keys," worst_m=",worst)
	Game.request_quit(0)
