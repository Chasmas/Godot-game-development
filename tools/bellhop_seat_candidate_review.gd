extends Node2D

func _ready() -> void:
	var identity := OS.get_environment("SEATED_REVIEW_ID")
	if identity == "": identity="bellhop"
	var review_directory := "res://build/seated_contacts/%s_candidate_v2/" % identity
	add_child(Effects.new())
	RenderingServer.set_default_clear_color(Color("16141d"))
	var camera := Camera2D.new()
	camera.position=Vector2(78,65);camera.zoom=Vector2(5,5);add_child(camera)
	var guards: Array=[]
	for row in 2:
		for i in 4:
			var guard := Enemy.new()
			guard.position=Vector2(20+i*38,38+row*65)
			guard.idle_action="snooze"
			add_child(guard)
			guard.setup(DB.enemy(&"bellhop"),self,Vector2.from_angle(i*PI/2))
			guard.set_physics_process(false)
			if row>=0:
				var previous := guard.visual.cast_sprite
				var cast := CastModel.new()
				cast.configure(identity,review_directory+identity+"_full_candidate.glb" if row==1 else CastModel.RT_PATH % [identity,identity])
				assert(cast._player!=null)
				assert(cast.clips.has("doze") and cast.clips.has("idle") and cast.clips.has("aim"))
				guard.visual.rig.remove_child(previous);previous.queue_free()
				guard.visual.rig.add_child(cast);guard.visual.cast_sprite=cast
				guard.visual.idle_activity_pose="doze"
			guards.append(guard)
	for frame in 40:await get_tree().process_frame
	var rows: Array=[]
	for index in guards.size():
		var guard: Enemy=guards[index]
		var cast := guard.visual.cast_sprite as CastModel
		assert(cast.clip=="doze")
		var contact := guard.visual.rig.to_global(cast.seat_point())
		var chair := guard.idle_activity._chair
		var lift := Vector2(0,-.45*sin(deg_to_rad(CastModel.ELEVATION))*16)*chair.global_scale
		assert((chair.global_position+lift).distance_to(contact)<.05)
		rows.append({"candidate":index>=4,"facing":index%4,"chair_contact_error_px":(chair.global_position+lift).distance_to(contact)})
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(review_directory+"godot_comparison.png")
	var transitions: Array=[]
	for index in range(4,8):
		var guard: Enemy=guards[index]
		var chair := guard.idle_activity._chair
		var stationary := chair.global_transform
		guard._set_state(Enemy.State.SUSPICIOUS)
		assert(guard.idle_activity==null)
		for frame in 12:await get_tree().process_frame
		assert(is_instance_valid(chair) and chair.global_position.distance_to(stationary.origin)<.05)
		assert(chair.global_transform.x.distance_to(stationary.x)<.001)
		assert(guard.visual.idle_activity_pose=="")
		var cast := guard.visual.cast_sprite as CastModel
		for frame in 24:
			guard.visual.update_move(Vector2.RIGHT.rotated(guard.visual.aim_angle)*92,1.0/60)
			await get_tree().process_frame
		assert(cast.clip.contains("walk"),"Wake must resume locomotion")
		guard.visual.update_move(Vector2.ZERO,1.0/60)
		guard.visual.swing(false,true)
		var expected_attack := "stab" if cast.clips.has("stab") else "punch"
		var sampled_attack := false
		for frame in 24:
			await get_tree().process_frame
			if cast.clip==expected_attack:sampled_attack=true
			assert(cast.grip().is_finite() and cast.seat_point().is_finite())
		assert(sampled_attack,"Knife attack must resume after waking")
		transitions.append({"facing":index%4,"wake_preserves_chair":true,"walk_resumed":true,"attack_resumed":true,"attack_clip":expected_attack})
	var report := FileAccess.open(review_directory+"godot_review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_approved":false,"rows":rows,"transitions":transitions,"scope":"Top production, bottom full corrected candidate; scripted wake, locomotion and stab transitions verified; full level behavior pending"},"  "))
	report.close()
	print("BELLHOP SEAT REVIEW: eight occupied chairs, original and candidate four facings")
	Game.request_quit(0)
