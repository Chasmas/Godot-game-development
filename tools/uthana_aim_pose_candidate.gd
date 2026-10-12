extends RefCounted
## Review-only aiming pose. Finger closure remains a separate mesh task.
static func apply(skeleton: Skeleton3D, targets: Dictionary = {}) -> float:
	var right := skeleton.find_bone("RightArm")
	var left := skeleton.find_bone("LeftArm")
	var shoulders := (_world(skeleton,right).origin+_world(skeleton,left).origin)*.5
	var grip := shoulders+Vector3(-.055,-.16,.30)
	var worst := 0.0
	for side in ["Right","Left"]:
		var upper := skeleton.find_bone(side+"Arm")
		var lower := skeleton.find_bone(side+"ForeArm")
		var hand := skeleton.find_bone(side+"Hand")
		var shoulder := _world(skeleton,upper)
		var elbow := _world(skeleton,lower)
		var wrist := _world(skeleton,hand)
		# Opposed palms are 78mm apart at the wrists: their authored grip
		# centres each sit 39mm inward, around the same pistol handle.
		var target := grip+ (Vector3(-.078,-.015,0) if side=="Left" else Vector3.ZERO)
		if targets.has(side): target=targets[side]
		var a := shoulder.origin.distance_to(elbow.origin)
		var b := elbow.origin.distance_to(wrist.origin)
		var axis := (target-shoulder.origin).normalized()
		var distance := clampf(target.distance_to(shoulder.origin),absf(a-b)+.0001,a+b-.0001)
		var along := (a*a-b*b+distance*distance)/(2*distance)
		var pole := Vector3(-.8 if side=="Right" else .8,-1,-.2)
		if not targets.is_empty():
			pole=Vector3(-.3 if side=="Right" else .3,-1,0)
		pole-=axis*pole.dot(axis)
		var orbit_text:=OS.get_environment("UTHANA_PREVIEW_ELBOW_ORBIT")
		if not targets.is_empty() and not orbit_text.is_empty():
			var orbit_values:=orbit_text.split(",")
			var orbit:=deg_to_rad(float(orbit_values[0 if side=="Right" else 1]))*(1 if side=="Right" else -1)
			pole=Quaternion(axis,orbit)*pole
		var desired_elbow := shoulder.origin+axis*along+pole.normalized()*sqrt(maxf(0,a*a-along*along))
		_set_rotation(skeleton,upper,Quaternion((elbow.origin-shoulder.origin).normalized(),(desired_elbow-shoulder.origin).normalized())*shoulder.basis.orthonormalized().get_rotation_quaternion())
		elbow=_world(skeleton,lower)
		var moved := _world(skeleton,hand)
		_set_rotation(skeleton,lower,Quaternion((moved.origin-elbow.origin).normalized(),(target-elbow.origin).normalized())*elbow.basis.orthonormalized().get_rotation_quaternion())
		var twist_text:=OS.get_environment("UTHANA_PREVIEW_ARM_TWIST")
		if not targets.is_empty() and not twist_text.is_empty():
			var lower_pose:=_world(skeleton,lower)
			var upper_pose:=_world(skeleton,upper)
			var upper_axis:=(lower_pose.origin-upper_pose.origin).normalized()
			var twist:=Quaternion(upper_axis,deg_to_rad(float(twist_text))*(1 if side=="Right" else -1))
			_set_rotation(skeleton,upper,twist*upper_pose.basis.orthonormalized().get_rotation_quaternion())
			_set_rotation(skeleton,lower,lower_pose.basis.orthonormalized().get_rotation_quaternion())
		# Authored pistol fingers use local X as grip up and Y along the
		# fingers. Both thumbs must sit above the opposed grip.
		var hand_axes := Basis(Vector3.DOWN,Vector3.BACK,Vector3.LEFT) if side=="Right" else Basis(Vector3.UP,Vector3.BACK,Vector3.RIGHT)
		if side=="Left" and targets.has("support_axes"): hand_axes=targets.support_axes
		_set_rotation(skeleton,hand,hand_axes.get_rotation_quaternion())
		var remaining:=_world(skeleton,hand).origin.distance_to(target)
		if remaining>.002:
			var posed_shoulder:=_world(skeleton,upper).origin
			var posed_elbow:=_world(skeleton,lower).origin
			var posed_wrist:=_world(skeleton,hand).origin
			print("ARM REACH DIAG side=",side," error=",remaining," initial_lengths=",Vector2(a,b)," posed_lengths=",Vector2(posed_shoulder.distance_to(posed_elbow),posed_elbow.distance_to(posed_wrist))," requested_distance=",posed_shoulder.distance_to(target)," parent_scale=",skeleton.get_bone_global_pose(skeleton.get_bone_parent(upper)).basis.get_scale())
		worst=maxf(worst,_world(skeleton,hand).origin.distance_to(target))
	return worst
static func _world(skeleton: Skeleton3D,bone: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone)
static func _set_rotation(skeleton: Skeleton3D,bone: int,rotation: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var axes := skeleton.global_basis
	if parent>=0: axes*=skeleton.get_bone_global_pose(parent).basis
	skeleton.set_bone_pose_rotation(bone,axes.orthonormalized().get_rotation_quaternion().inverse()*rotation)
	skeleton.force_update_all_bone_transforms()
