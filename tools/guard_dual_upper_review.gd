extends Node

func _ready() -> void:
	var source := OS.get_environment("DUAL_REVIEW_SOURCE")
	if source.is_empty(): source="res://build/guard_dual_upper_v2/guard.glb"
	var clip := OS.get_environment("DUAL_REVIEW_CLIP")
	if clip.is_empty(): clip="aim_dual"
	var output := OS.get_environment("DUAL_REVIEW_OUTPUT")
	if output.is_empty(): output="res://build/guard_dual_upper_v2"
	DirAccess.make_dir_recursive_absolute(output)
	var failures: Array = []
	var stage := SubViewport.new()
	stage.size=Vector2i(1280,720)
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.size=Vector2(stage.size)
	background.color=Color("191622")
	stage.add_child(background)
	var rows: Array = []
	for direction in 8:
		var angle := direction*PI/4
		var visual := CharacterVisual.new()
		stage.add_child(visual)
		visual.position=Vector2(160+(direction%4)*320,250+(direction/4)*350)
		visual.scale=Vector2.ONE*6
		visual.setup("guard")
		visual.cast_sprite.free()
		var cast := CastModel.new()
		assert(cast.configure("guard",source))
		assert(cast.clips.has(clip))
		visual.cast_sprite=cast
		visual.rig.add_child(cast)
		visual.set_process(false)
		visual.set_weapon(DB.weapon(&"pistol"),true)
		visual.set_aim(angle)
		visual._face_angle=angle
		cast._body_angle=angle
		cast._body_init=true
		visual.pose_override=clip
		assert(not cast._spine.is_empty())
		var chest_bone: int = cast._spine[0]
		var minimum_forward := INF
		var separation := INF
		var head_lowest := INF
		for phase in 33:
			visual.pose_progress=phase/33.0
			visual._process_cast(0)
			var chest := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(chest_bone).origin)
			var head := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._head).origin)
			var hands: Array[Vector3] = []
			for side in 2:
				var hand := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[side]).origin)
				hands.append(hand)
				minimum_forward=minf(minimum_forward,(hand-chest).dot(cast._model.global_basis.z.normalized()))
				head_lowest=minf(head_lowest,head.y-hand.y)
				var gun := visual.weapon_sprite if side==0 else visual.weapon_sprite2
				assert(gun.position.distance_to(cast.grip(side==1))<.001)
			separation=minf(separation,hands[0].distance_to(hands[1]))
		if minimum_forward<=.10: failures.append("Hands behind chest at %d degrees" % (direction*45))
		if head_lowest<=.10: failures.append("Hands too high at %d degrees" % (direction*45))
		if separation<=.12: failures.append("Grips too close at %d degrees" % (direction*45))
		rows.append({"degrees":direction*45,"minimum_hand_forward_m":minimum_forward,"minimum_hand_separation_m":separation,"minimum_below_head_m":head_lowest})
		visual.pose_progress=.35
		visual._process_cast(0)
		var label := Label.new()
		label.text="%d degrees" % (direction*45)
		label.position=Vector2(110+(direction%4)*320,300+(direction/4)*350)
		stage.add_child(label)
	for frame in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(output+"/directions.png")
	var file := FileAccess.open(output+"/directions_audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"source":source,"clip":clip,"rows":rows,"failures":failures,"scope":"33 phases in eight directions; wrist-linked weapon origins and geometric arm posture"},"\t"))
	print("GUARD DUAL REVIEW: ",clip," eight directions, 264 phases; failures=",failures.size())
	Game.request_quit(0 if failures.is_empty() else 1)
