extends Node
func _ready() -> void:
	var cast_id := OS.get_environment("CAST_STRIDE_REVIEW")
	if cast_id.is_empty():cast_id="cass"
	var source := (load("res://assets/art/cast3d_rt/%s/%s.glb" % [cast_id,cast_id]) as PackedScene).instantiate()
	add_child(source)
	var player := source.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton := source.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var library := AnimationLibrary.new()
	player.add_animation_library("contact_review",library)
	var results: Array=[]
	var native_speeds: Dictionary={}
	var stance_fractions: Dictionary={}
	var profile := OS.get_environment("CAST_STRIDE_PROFILE")
	if profile.is_empty():profile="study"
	assert(profile in ["study","grounded","preserved"])
	for gait in ["walk","run","sneak"]:
		var directory: String = "res://build/locomotion_candidates/"+cast_id+"/"+(profile+"/" if profile!="study" else "")+(gait+"/" if gait!="walk" else "")
		var document := GLTFDocument.new();var state := GLTFState.new()
		assert(document.append_from_file(directory+gait+"_contact_candidate.glb",state)==OK)
		var candidate := document.generate_scene(state, 240.0)
		add_child(candidate)
		var animations := candidate.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		var contact: Animation
		var specification: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"review.json"))
		native_speeds[gait]=float(specification.stride_metres)/float(specification.stance_fraction)/float(specification.duration_seconds)*16.0
		stance_fractions[gait]=float(specification.stance_fraction)
		for name in animations.get_animation_list():
			if name!="RESET":contact=animations.get_animation(name)
		assert(contact!=null)
		for prefix in ["","armed_","armed_dual_","armed_melee_"]:
			var name: String = prefix+gait
			var source_name: String=name if player.has_animation(name) else prefix+"walk"
			if not player.has_animation(source_name):continue
			var original := player.get_animation(source_name)
			var merged: Animation=preload("res://scripts/player/contact_locomotion_merge.gd").merge(original,contact)
			assert(merged.length==contact.length and merged.loop_mode==Animation.LOOP_LINEAR)
			_check_upper_tracks(original,merged)
			library.add_animation(name,merged)
			player.play("contact_review/"+name,0)
			var drift := _check_contact(source as Node3D,skeleton,player,specification)
			results.append({"clip":name,"original_tracks":original.get_track_count(),"merged_tracks":merged.get_track_count(),"duration":merged.length,"upper_tracks_preserved":true,"worst_foot_drift_metres":drift,"directional_stance_sweeps":32})
		candidate.queue_free()
	library.set_meta("native_speeds",native_speeds)
	library.set_meta("stance_fractions",stance_fractions)
	library.set_meta("runtime_approved",false)
	var library_path: String="res://build/locomotion_candidates/"+cast_id+"/"+(profile+"/" if profile!="study" else "")+"contact_library.res"
	assert(ResourceSaver.save(library,library_path,ResourceSaver.FLAG_COMPRESS)==OK)
	var report := FileAccess.open("res://build/contact_locomotion_merge_review_"+cast_id+("_"+profile if profile!="study" else "")+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Merged foot contact in 8 facings forward/reverse and retained upper tracks; gameplay cadence and visual quality still require review","clips":results},"\t"))
	print("CONTACT LOCOMOTION MERGE PASSED")
	Game.request_quit(0)

func _check_upper_tracks(original: Animation,merged: Animation) -> void:
	var helper = preload("res://scripts/player/contact_locomotion_merge.gd")
	for track in original.get_track_count():
		if helper.bone_name(original.track_get_path(track)) in helper.LOWER:continue
		var target := merged.find_track(original.track_get_path(track),original.track_get_type(track))
		assert(target>=0,"Upper-body track must survive merge")
		assert(original.track_get_key_count(track)==merged.track_get_key_count(target))
		for key in original.track_get_key_count(track):
			assert(original.track_get_key_value(track,key)==merged.track_get_key_value(target,key),"Combat pose values must remain intact")
			assert(absf(merged.track_get_key_time(target,key)-original.track_get_key_time(track,key)*merged.length/original.length)<.00001)

func _check_contact(actor: Node3D,skeleton: Skeleton3D,player: AnimationPlayer,specification: Dictionary) -> float:
	var duration := float(specification.duration_seconds)
	var stance := float(specification.stance_fraction)
	var speed := float(specification.stride_metres)/stance/duration
	var samples := int((stance-.02)*duration*960)+1
	var worst := 0.0
	for facing in 8:
		actor.rotation.y=facing*PI/4
		for reverse in [false,true]:
			for side in 2:
				var foot := skeleton.find_bone("LeftFoot" if side==0 else "RightFoot")
				var start := Vector3.ZERO
				for sample in samples:
					var phase := ((samples-1-sample) if reverse else sample)/960.0
					var time := phase+side*duration*.5
					actor.position=actor.basis*Vector3(0,0,speed*time)
					player.seek(fposmod(time,duration),true)
					player.advance(.000001)
					skeleton.force_update_all_bone_transforms()
					var point := skeleton.global_transform*skeleton.get_bone_global_pose(foot).origin
					if sample==0:start=point
					worst=maxf(worst,point.distance_to(start))
	assert(worst<.002,"Merged combat clip must retain planted foot contact: "+str(worst))
	return worst
