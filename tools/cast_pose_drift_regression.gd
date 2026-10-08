extends Node
var failures := 0
func _ready() -> void:
	for index in 8:
		var angle := index * TAU / 8.0
		var turning_rig := Node2D.new()
		var reference_rig := Node2D.new()
		add_child(turning_rig)
		add_child(reference_rig)
		var turning := CastModel.create("guard") as CastModel
		var source := OS.get_environment("CAST_DRIFT_MODEL")
		if source != "":
			turning.free()
			turning = CastModel.new()
			if not turning.configure("guard", source):
				get_tree().quit(1)
				return
		if OS.get_environment("CAST_DRIFT_NEGATIVE_CONTROL") == "1":
			turning.free()
			turning = load("res://tools/legacy_cast_pose_control.gd").new() as CastModel
			if not turning.configure("guard", source):
				get_tree().quit(1)
				return
		var reference := CastModel.create("guard") as CastModel
		if source != "":
			reference.free()
			reference = CastModel.new()
			if not reference.configure("guard", source):
				get_tree().quit(1)
				return
		turning_rig.add_child(turning)
		reference_rig.add_child(reference)
		turning.play_sample("aim_dual", 1.0 / 60.0)
		turning_rig.rotation = angle
		reference_rig.rotation = angle
		# Compare the same animation time: turning already sampled one frame
		# before its rotation changed; reference starts directly at this angle.
		reference.play_sample("aim_dual", 1.0 / 60.0)
		for frame in 180:
			turning.play_sample("aim_dual", 1.0 / 60.0)
			reference.play_sample("aim_dual", 1.0 / 60.0)
		for left in [false, true]:
			if turning.grip(left).distance_to(reference.grip(left)) > 0.02:
				print("DRIFT hand angle=",angle," left=",left," distance=",turning.grip(left).distance_to(reference.grip(left)))
				failures += 1
		for bone in turning._spine:
			if turning._skeleton.get_bone_pose_rotation(bone).angle_to(reference._skeleton.get_bone_pose_rotation(bone)) > 0.01:
				print("DRIFT spine angle=",angle," bone=",turning._skeleton.get_bone_name(bone))
				failures += 1
		turning.play_sample("roll", 1.0 / 60.0, 0.5)
		var poses := []
		for bone in turning._legs + turning._spine:
			poses.append(turning._skeleton.get_bone_pose_rotation(bone))
		for frame in 30:
			turning.play_sample("roll", 1.0 / 60.0, 0.5)
		var offset := 0
		for bone in turning._legs + turning._spine:
			if turning._skeleton.get_bone_pose_rotation(bone).angle_to(poses[offset]) > 0.01:
				print("DRIFT roll angle=",angle," bone=",turning._skeleton.get_bone_name(bone))
				failures += 1
			offset += 1
		turning_rig.queue_free()
		reference_rig.queue_free()
		await get_tree().process_frame
	print("CAST POSE DRIFT: eight turns and repeated roll, failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
