extends Node2D

func _ready() -> void:
	var cast_id := OS.get_environment("CAST_STRIDE_REVIEW")
	if cast_id.is_empty():cast_id="cass"
	var model := CastModel.create(cast_id) as CastModel
	assert(model!=null)
	var rig := Node2D.new()
	rig.position=Vector2(320,220)
	add_child(rig)
	rig.add_child(model)
	var library_path := OS.get_environment("CONTACT_LIBRARY_PATH")
	if library_path.is_empty():
		library_path = "res://build/locomotion_candidates/%s/preserved/contact_library.res" % cast_id
	model.apply_contact_locomotion(load(library_path) as AnimationLibrary)
	var profile := OS.get_environment("CONTACT_REVIEW_PROFILE")
	if profile.is_empty(): profile = "preserved"
	var sneak_profile := OS.get_environment("CONTACT_REVIEW_SNEAK_PROFILE")
	var report: Array=[]
	for gait in ["walk","run","sneak"]:
		var gait_profile := sneak_profile if gait == "sneak" and not sneak_profile.is_empty() else profile
		var directory: String="res://build/locomotion_candidates/%s/%s/" % [cast_id, gait_profile]+(gait+"/" if gait!="walk" else "")
		var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"review.json"))
		var duration:=float(spec.duration_seconds)
		var stance:=float(spec.stance_fraction)
		var native:=float(model._contact_native_speed[gait])
		var worst:=0.0
		for facing in 8:
			for aim in 8:
				var angle:=facing*PI/4
				rig.rotation=aim*PI/4
				# The hips and legs face actual locomotion.  The upper-body animation
				# remains free to track the aim through CastModel's spine twist.
				var reverse:=absf(angle_difference(angle,rig.rotation))>deg_to_rad(100.0)
				model.moving=true
				model.move_angle=angle
				model.move_speed=native
				for side in 2:
					var foot:=model._skeleton.find_bone("LeftFoot" if side==0 else "RightFoot")
					var span: float=(stance-.02)*duration
					var initial: float=side*duration*.5+(span if reverse else 0.0)
					model._player.play(gait,0)
					model.clip=gait
					model._player.seek(fposmod(initial,duration),true)
					model._player.advance(.000001)
					model.play_sample(gait,0)
					var expected_body := angle + (PI if absf(angle_difference(angle, rig.rotation)) > deg_to_rad(100.0) else 0.0)
					assert(absf(angle_difference(model._body_angle,expected_body))<.00001,"Legs must follow movement, with backpedal only beyond the torso twist limit")
					model._skeleton.force_update_all_bone_transforms()
					var start:=_foot(model,foot)
					for sample in range(1,33):
						model.play_sample(gait,span/32)
						model._skeleton.force_update_all_bone_transforms()
						_check_knee(model,side)
						var point:=_foot(model,foot)+Vector2.from_angle(angle)*native*span*sample/32
						worst=maxf(worst,point.distance_to(start))
		assert(worst<.05,"Real cast renderer must preserve contact (px): "+str(worst))
		report.append({"gait":gait,"aim_movement_pairs":64,"both_feet":true,"worst_drift_px":worst})
	var file:=FileAccess.open("res://build/contact_cast_renderer_"+cast_id+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"cast":cast_id,"runtime_promoted":false,"clips":report},"\t"))
	if cast_id=="cass" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://build/locomotion_runtime_review")
		model._viewport.size=Vector2i(512,512)
		rig.rotation=PI
		model.move_angle=PI
		model.move_speed=float(model._contact_native_speed.walk)
		for phase in [0.0,.25,.5,.75]:
			model._player.play("walk",0)
			model.clip="walk"
			model._player.seek(phase*model._player.get_animation("walk").length,true)
			model._player.advance(.000001)
			model.play_sample("walk",0)
			await RenderingServer.frame_post_draw
			var capture:=model._viewport.get_texture().get_image()
			capture.save_png("res://build/locomotion_runtime_review/cass_walk_%d.png" % roundi(phase*100))
	print("CONTACT CAST RENDERER PASSED ",cast_id," ",report)
	Game.request_quit(0)

func _foot(model: CastModel,bone: int) -> Vector2:
	var point:=model._skeleton.to_global(model._skeleton.get_bone_global_pose(bone).origin)
	return Vector2(point.x,point.z)*16.0

func _check_knee(model: CastModel,side: int) -> void:
	var skeleton:=model._skeleton
	var hip:=skeleton.to_global(skeleton.get_bone_global_pose(model._legs[side*2]).origin)
	var knee:=skeleton.to_global(skeleton.get_bone_global_pose(model._legs[side*2+1]).origin)
	var ankle:=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("LeftFoot" if side==0 else "RightFoot")).origin)
	var angle:=acos(clampf((hip-knee).normalized().dot((ankle-knee).normalized()),-1,1))
	assert(angle>deg_to_rad(25),"Knee must not fold into an impossible pose")
