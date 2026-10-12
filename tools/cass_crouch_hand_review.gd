extends Node2D
func _ready() -> void:
	var rig := Node2D.new()
	add_child(rig)
	var model := CastModel.create("cass") as CastModel
	rig.add_child(model)
	var worst := 0.0
	for facing in 8:
		rig.rotation = facing * PI / 4
		for sample in 32:
			var phase := sample / 32.0
			model.play_sample("armed_sneak",0.0,phase)
			var skeleton := model._skeleton
			skeleton.force_update_all_bone_transforms()
			var right := skeleton.find_bone("RightHand")
			var left := skeleton.find_bone("LeftHand")
			var target := skeleton.to_global(skeleton.get_bone_global_pose(right).origin) + Vector3.DOWN * 0.12
			preload("res://scripts/player/crouch_weapon_pose.gd").apply(model,1.0)
			var actual := skeleton.to_global(skeleton.get_bone_global_pose(right).origin)
			worst = maxf(worst,actual.distance_to(target))
			var support := skeleton.to_global(skeleton.get_bone_global_pose(left).origin)
			assert(actual.is_finite() and support.is_finite())
			assert(actual.distance_to(support) < 0.09, "Support hand must remain at the grip")
	print("CROUCH HAND TARGET worst error metres: ",worst)
	Game.request_quit(0 if worst < 0.01 else 1)


