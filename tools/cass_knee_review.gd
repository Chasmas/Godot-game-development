extends Node2D

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	for file in DirAccess.get_files_at("res://assets/art/locomotion3d"):
		if file.ends_with(".res"):
			_review(file.trim_suffix(".res"))
	get_tree().quit()

func _review(id: String) -> void:
	var worst := 1.0
	var row := 0
	var preview_gaits := ["walk", "run", "sneak"]
	for gait in (load("res://assets/art/locomotion3d/"+id+".res") as AnimationLibrary).get_animation_list():
		var model := CastModel.create(id) as CastModel
		add_child(model)
		model._player.play(gait, 0)
		for frame in 241:
			model._player.seek(model._player.get_animation(gait).length * frame / 240.0, true)
			model._player.advance(0.000001)
			model._skeleton.force_update_all_bone_transforms()
			for side in ["Left", "Right"]:
				var s := model._skeleton
				var h := model._model.to_local(s.to_global(s.get_bone_global_pose(s.find_bone(side + "UpLeg")).origin))
				var k := model._model.to_local(s.to_global(s.get_bone_global_pose(s.find_bone(side + "Leg")).origin))
				var a := model._model.to_local(s.to_global(s.get_bone_global_pose(s.find_bone(side + "Foot")).origin))
				var axis := (a-h).normalized()
				var bend := k-h-axis*(k-h).dot(axis)
				worst = minf(worst, bend.z)
				assert(bend.z > 0.0, "Knees must bend forward: " + gait + " " + side)
				assert(absf(bend.x)<0.002,"Knees must not buckle sideways by more than 2 mm")
		model.queue_free()
		if DisplayServer.get_name() != "headless" and id == "cass" and gait in preview_gaits:
			for phase in 8:
				var rig := Node2D.new()
				rig.position = Vector2(65+phase*125,150+preview_gaits.find(gait)*180)
				add_child(rig)
				var preview := CastModel.create("cass") as CastModel
				rig.add_child(preview)
				preview.scale = Vector2.ONE*2
				preview.play_sample(gait,0,phase/8.0)
		row += 1
	print("WORST KNEE FORWARD OFFSET ",worst)
	print("KNEE REVIEW PASSED ",id,": all clips, 241 phases, both legs")
	if DisplayServer.get_name() != "headless":
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/cass_knee_review.png")
