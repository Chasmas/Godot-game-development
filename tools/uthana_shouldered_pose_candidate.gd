extends RefCounted
static func apply(skeleton: Skeleton3D, weapon: Node3D) -> float:
	# A shouldered long gun needs the support shoulder advanced. Keeping
	# both shoulders square made the forward grip unreachable.
	var chest:=skeleton.find_bone("Spine02")
	assert(chest>=0)
	var chest_world:=skeleton.global_transform*skeleton.get_bone_global_pose(chest)
	var support_marker:=weapon.find_child("SupportGrip",true,false) as Node3D
	var stock_marker:=weapon.find_child("ShoulderAnchor",true,false) as Node3D
	var reach_length:=support_marker.position.distance_to(stock_marker.position)
	var chest_yaw := -.80 if reach_length>.52 else -.76
	preload("res://tools/uthana_aim_pose_candidate.gd")._set_rotation(skeleton,chest,Quaternion(Vector3.UP,chest_yaw)*chest_world.basis.orthonormalized().get_rotation_quaternion())
	var shoulder_bone:=skeleton.find_bone("RightArm")
	var shoulder:=skeleton.to_global(skeleton.get_bone_global_pose(shoulder_bone).origin)+Vector3(-.055,-.035,-.02)
	var butt:=weapon.find_child("ShoulderAnchor",true,false) as Node3D
	var grip:=weapon.find_child("GripAnchor",true,false) as Node3D
	var support:=weapon.find_child("SupportRearGrip",true,false) as Node3D
	assert(butt!=null and grip!=null and support!=null)
	var local_butt:=weapon.global_transform.affine_inverse()*butt.global_transform
	weapon.global_transform=Transform3D(Basis.IDENTITY,shoulder)*local_butt.affine_inverse()
	assert(butt.global_position.distance_to(shoulder)<.00001)
	var targets: Dictionary={
		# Main hand belongs on the trigger grip. The old 6cm rear offset put
		# it behind the physical handle and into the chest in a side review.
		"Right":grip.global_position+Vector3(0,-.01,.01),
		"Left":support.global_position-Vector3(.06,.039,0),
		"support_axes":Basis(Vector3.BACK,Vector3.RIGHT,Vector3.UP)}
	return preload("res://tools/uthana_aim_pose_candidate.gd").apply(skeleton,targets)
