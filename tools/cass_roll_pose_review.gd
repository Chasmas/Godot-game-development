extends Node2D
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	scale = Vector2.ONE * 2.0
	for row in 2:
		for sample in 8:
			var rig := Node2D.new()
			rig.position = Vector2(40 + sample * 50, 90 + row * 110)
			rig.rotation = 0.0 if row == 0 else PI / 2
			add_child(rig)
			var model := CastModel.create("cass") as CastModel
			rig.add_child(model)
			model.roll_mode = 0
			model.set_meta("review_phase",sample / 7.0)
			model.play_sample("roll",0.0,sample / 7.0)
	for frame in 8:
		for model in find_children("*","Sprite2D",true,false):
			if model is CastModel: model.play_sample("roll",0.0,float(model.get_meta("review_phase")))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for model in find_children("*","Sprite2D",true,false):
		if not model is CastModel: continue
		var used: Rect2i = model._viewport.get_texture().get_image().get_used_rect()
		assert(used.size.x > 8 and used.size.y > 8, "Cass roll must keep a visible silhouette at every sampled phase")
		print("viewport pixels ",used," stage meshes=",model._model.find_children("*","MeshInstance3D",true,false).size())
		var head: Vector3 = model._skeleton.to_global(model._skeleton.get_bone_global_pose(model._head).origin)
		var pelvis: Vector3 = model._skeleton.to_global(model._skeleton.get_bone_global_pose(model._hips).origin)
		print("ROLL phase=",model.get_meta("review_phase")," alpha=",model.self_modulate.a," head_uv=",model._camera.unproject_position(head)," hips_uv=",model._camera.unproject_position(pelvis)," root=",model._model.position)
	get_viewport().get_texture().get_image().save_png("res://build/cass_roll_pose_review.png")
	print("CASS ROLL POSE REVIEW PASSED: all 16 sampled orientations retain a visible silhouette")
	Game.request_quit(0)

