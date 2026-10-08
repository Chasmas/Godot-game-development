extends CastModel
## Negative test control: emulate the former accumulating procedural offsets.
func _rotate_pose_bone(bone: int, offset: Quaternion) -> void:
	_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_pose_rotation(bone) * offset)
