extends Node
func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(960,600)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var bg := ColorRect.new()
	bg.size = Vector2(stage.size)
	bg.color = Color("262332")
	stage.add_child(bg)
	var cell := Node2D.new()
	cell.position = Vector2(480,360)
	cell.scale = Vector2.ONE * 4.0
	stage.add_child(cell)
	var model := CarModel.new()
	cell.add_child(model)
	assert(model.add_driver("cass"))
	var source := OS.get_environment("CAR_EXIT_REVIEW_MODEL")
	var clip := OS.get_environment("CAR_EXIT_REVIEW_CLIP")
	if clip == "": clip = "car_exit"
	var prefix := OS.get_environment("CAR_EXIT_REVIEW_PREFIX")
	if prefix == "": prefix = "baseline" if source == "" else "smooth"
	if source != "":
		model.driver.free()
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(source,state) == OK)
		model.driver = doc.generate_scene(state)
		model.car.add_child(model.driver)
		model._driver_anim = model.driver.find_children("*","AnimationPlayer",true,false)[0]
	model.set_heading(PI * .5)
	model.set_door(1.0)
	var skeleton: Skeleton3D = model.driver.find_children("*","Skeleton3D",true,false)[0]
	var door_mesh := model.door as MeshInstance3D
	assert(door_mesh != null)
	var door_box := door_mesh.get_aabb()
	var door_corners := []
	for corner in 8:
		var v := door_box.get_endpoint(corner)
		var at := model.car.to_local(door_mesh.to_global(v))
		door_corners.append([at.x,at.y,at.z])
	var close_rows := []
	var support_local := model.door.to_local(model.car.to_global(Vector3(1.171825,1.10,.234360)))
	for index in 65:
		var k := index / 64.0
		var close_phase := smoothstep(0.20,0.78,k)
		model.set_door(1.0-close_phase)
		var at := model.car.to_local(model.door.to_global(support_local))
		close_rows.append({"phase":k,"door_open":1.0-close_phase,"point":[at.x,at.y,at.z]})
	var path_file := FileAccess.open("res://build/car_exit_review/door_close_path.json",FileAccess.WRITE)
	path_file.store_string(JSON.stringify({"approved":false,"seat_at":[model.seat_at.x,model.seat_at.y,model.seat_at.z],"driver_at":[model._out_point(1.0).x,model._out_point(1.0).y,model._out_point(1.0).z],"rows":close_rows},"  "))
	model.set_door(1.0)
	var rows := []
	for index in 65:
		var k := index / 64.0
		if clip == "car_close":
			model.set_door(1.0-smoothstep(.20,.78,k))
			model.pose_driver(clip,k,1.0,1.0)
		else:
			model.pose_driver(clip,k,lerpf(.15,1.0,smoothstep(0.0,1.0,k)),1.0)
		var points := {}
		for name in ["Hips","Head","LeftFoot","RightFoot","LeftToeBase","RightToeBase","LeftHand","RightHand","LeftForeArm","RightForeArm"]:
			var bone := skeleton.find_bone(name)
			assert(bone >= 0)
			var at := model.car.to_local(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
			points[name] = [at.x,at.y,at.z]
		rows.append({"phase":k,"points":points})
		await get_tree().process_frame
		if index in [0,12,24,35,48,64] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			stage.get_texture().get_image().save_png("res://build/car_exit_review/pose/"+(prefix + "_")+"%03d.png" % index)
	var file := FileAccess.open("res://build/car_exit_review/"+(prefix + "_anatomy.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"approved":false,"source":source,"clip":clip,"seat_at":[model.seat_at.x,model.seat_at.y,model.seat_at.z],"door_corners":door_corners,"rows":rows},"  "))
	print("CAR EXIT POSE REVIEW: ",rows.size()," samples")
	Game.request_quit()
