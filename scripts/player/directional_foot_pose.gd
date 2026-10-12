extends RefCounted
## Adapt a planted stride to movement while the whole body faces the aim.
## Original mesh, rest rig, upper-body animations and combat remain intact.
static func apply(cast: CastModel,gait: String,yaw: float) -> void:
	var skeleton:=cast._skeleton
	skeleton.force_update_all_bone_transforms()
	var targets: Array[Vector3]=[]
	var feet: Array[int]=[]
	var foot_rotations: Array[Quaternion]=[]
	var lengths: Array[Vector2]=[]
	var drop:=0.0
	for side in 2:
		var thigh: int=cast._legs[side*2]
		var shin: int=cast._legs[side*2+1]
		var foot:=skeleton.find_bone("LeftFoot" if side==0 else "RightFoot")
		feet.append(foot)
		var hip_world:=_world(skeleton,thigh)
		var knee_world:=_world(skeleton,shin)
		var foot_world:=_world(skeleton,foot)
		var center: Vector3=cast._contact_neutral[gait][side]
		var sampled:=cast._model.to_local(foot_world.origin)
		var offset:=sampled-center
		var target:=cast._model.to_global(center+Vector3(offset.x,0,offset.z).rotated(Vector3.UP,yaw)+Vector3(0,offset.y,0))
		targets.append(target)
		foot_rotations.append(foot_world.basis.orthonormalized().get_rotation_quaternion())
		var reach:=Vector2(hip_world.origin.distance_to(knee_world.origin),knee_world.origin.distance_to(foot_world.origin))
		lengths.append(reach)
		var horizontal:=Vector2(hip_world.origin.x-target.x,hip_world.origin.z-target.z).length()
		var vertical:=sqrt(maxf(.000001,pow(reach.x+reach.y-.001,2)-horizontal*horizontal))
		drop=maxf(drop,hip_world.origin.y-target.y-vertical)
	if drop>.000001:
		var parent:=skeleton.get_bone_parent(cast._hips)
		var parent_basis:=skeleton.global_basis
		if parent>=0:parent_basis*=skeleton.get_bone_global_pose(parent).basis
		cast._procedural_positions[cast._hips]=skeleton.get_bone_pose_position(cast._hips)
		skeleton.set_bone_pose_position(cast._hips,skeleton.get_bone_pose_position(cast._hips)+parent_basis.inverse()*Vector3(0,-drop,0))
		skeleton.force_update_all_bone_transforms()
	for side in 2:
		var thigh: int=cast._legs[side*2]
		var shin: int=cast._legs[side*2+1]
		var foot:=feet[side]
		var hip:=_world(skeleton,thigh)
		var knee:=_world(skeleton,shin)
		var direction: Vector3=(targets[side]-hip.origin).normalized()
		var reach:=lengths[side]
		var distance:=clampf(hip.origin.distance_to(targets[side]),absf(reach.x-reach.y)+.000001,reach.x+reach.y-.000001)
		var along: float=(reach.x*reach.x-reach.y*reach.y+distance*distance)/(2*distance)
		var height:=sqrt(maxf(0,reach.x*reach.x-along*along))
		var pole:=cast._model.global_basis*Vector3(0,0,1)
		pole-=direction*pole.dot(direction)
		if pole.length_squared()<.000001:pole=direction.cross(Vector3.RIGHT)
		var target_knee:=hip.origin+direction*along+pole.normalized()*height
		var turn:=Quaternion((knee.origin-hip.origin).normalized(),(target_knee-hip.origin).normalized())
		_set_rotation(cast,thigh,turn*hip.basis.orthonormalized().get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()
		knee=_world(skeleton,shin)
		var ankle:=_world(skeleton,foot)
		turn=Quaternion((ankle.origin-knee.origin).normalized(),(targets[side]-knee.origin).normalized())
		_set_rotation(cast,shin,turn*knee.basis.orthonormalized().get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()
		_set_rotation(cast,foot,foot_rotations[side])
	skeleton.force_update_all_bone_transforms()

static func _world(skeleton: Skeleton3D,bone: int) -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone)

static func _set_rotation(cast: CastModel,bone: int,rotation: Quaternion) -> void:
	var skeleton:=cast._skeleton
	if not cast._procedural_rotations.has(bone):cast._procedural_rotations[bone]=skeleton.get_bone_pose_rotation(bone)
	var parent:=skeleton.get_bone_parent(bone)
	var axes:=skeleton.global_basis
	if parent>=0:axes*=skeleton.get_bone_global_pose(parent).basis
	var local:=axes.orthonormalized().get_rotation_quaternion().inverse()*rotation
	skeleton.set_bone_pose_rotation(bone,local)
