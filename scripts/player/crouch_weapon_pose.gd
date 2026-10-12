extends RefCounted
# Two-bone adjustment: move the hands with their arms, preserving wrist orientation.
static func apply(cast: CastModel, weight: float) -> void:
	var skeleton := cast._skeleton
	skeleton.force_update_all_bone_transforms()
	var right_hand := skeleton.find_bone("RightHand")
	if right_hand < 0: return
	var grip := _world(skeleton, right_hand).origin + Vector3.DOWN * 0.12
	for side in ["Right", "Left"]:
		var upper := skeleton.find_bone(side + "Arm")
		var lower := skeleton.find_bone(side + "ForeArm")
		var hand := skeleton.find_bone(side + "Hand")
		if upper < 0 or lower < 0 or hand < 0: continue
		skeleton.force_update_all_bone_transforms()
		var shoulder := _world(skeleton, upper)
		var elbow := _world(skeleton, lower)
		var wrist := _world(skeleton, hand)
		var support := cast._model.global_basis * Vector3(-0.045, 0.0, 0.035) if side == "Left" else Vector3.ZERO
		var target := wrist.origin.lerp(grip + support, weight)
		var a := shoulder.origin.distance_to(elbow.origin)
		var b := elbow.origin.distance_to(wrist.origin)
		var axis := (target - shoulder.origin).normalized()
		var distance := clampf(shoulder.origin.distance_to(target), absf(a-b)+0.0001, a+b-0.0001)
		var along := (a*a-b*b+distance*distance)/(2.0*distance)
		var pole := cast._model.global_basis * Vector3(-0.45 if side == "Left" else 0.45, -1.0, -0.2)
		pole -= axis * pole.dot(axis)
		if pole.length_squared() < 0.000001: pole = cast._model.global_basis * Vector3.RIGHT
		var knee := shoulder.origin + axis * along + pole.normalized() * sqrt(maxf(0.0,a*a-along*along))
		var turn := Quaternion((elbow.origin-shoulder.origin).normalized(), (knee-shoulder.origin).normalized())
		_set_rotation(cast,upper,turn*shoulder.basis.orthonormalized().get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()
		elbow = _world(skeleton,lower)
		var moved_wrist := _world(skeleton,hand)
		turn = Quaternion((moved_wrist.origin-elbow.origin).normalized(),(target-elbow.origin).normalized())
		_set_rotation(cast,lower,turn*elbow.basis.orthonormalized().get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()
		_set_rotation(cast,hand,wrist.basis.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()
static func _world(skeleton: Skeleton3D,bone: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone)
static func _set_rotation(cast: CastModel,bone: int,rotation: Quaternion) -> void:
	var skeleton := cast._skeleton
	if not cast._procedural_rotations.has(bone): cast._procedural_rotations[bone] = skeleton.get_bone_pose_rotation(bone)
	var parent := skeleton.get_bone_parent(bone)
	var axes := skeleton.global_basis
	if parent >= 0: axes *= skeleton.get_bone_global_pose(parent).basis
	skeleton.set_bone_pose_rotation(bone,axes.orthonormalized().get_rotation_quaternion().inverse()*rotation)


