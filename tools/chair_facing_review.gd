extends Node2D

func _ready() -> void:
	add_child(Effects.new())
	RenderingServer.set_default_clear_color(Color("16141d"))
	var camera := Camera2D.new()
	camera.position = Vector2(78, 30)
	camera.zoom = Vector2(6, 6)
	add_child(camera)
	var guards: Array = []
	for i in 4:
		var guard := Enemy.new()
		guard.position = Vector2(20 + i * 38, 38)
		guard.idle_action = "snooze"
		add_child(guard)
		guard.setup(DB.enemy(&"guard"), self, Vector2.from_angle(i * PI / 2))
		guard.set_physics_process(false)
		guards.append(guard)
	for frame in 30: await get_tree().process_frame
	for guard in guards:
		var cast := guard.visual.cast_sprite as CastModel
		var model := guard.idle_activity._chair.get_child(0) as PropModel
		print("CHAIR_FACING aim=", guard.visual.aim_angle, " chair_yaw=", model.yaw, " cast_yaw=", cast._model.rotation.y)
		var hips := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hips).origin)
		var initial_height := hips.y
		cast.play_sample("doze",0,.5)
		var settled_height := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hips).origin).y
		assert(absf(initial_height-settled_height)<.001,"seated pose must not retain a standing-animation blend")
		var floor_pixel := (cast._camera.unproject_position(Vector3(hips.x,0,hips.z))-cast._origin)*cast.world_scale
		print("CHAIR_CONTACT look=",cast._look_id," pelvis_height_m=", hips.y, " floor_pixel=",floor_pixel," chair_offset_px=",guard.idle_activity._chair.global_position-guard.global_position)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/chair_facing_review.png")
	print("CHAIR FACING REVIEW: four occupied chairs rendered")
	Game.request_quit(0)
