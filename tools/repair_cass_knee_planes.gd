extends Node

func _ready() -> void:
	for file in DirAccess.get_files_at("res://assets/art/locomotion3d"):
		if file.ends_with(".res"):
			_repair(file.trim_suffix(".res"))
	get_tree().quit()

func _repair(id: String) -> void:
	var source := load("res://assets/art/locomotion3d/"+id+".res") as AnimationLibrary
	var library := source.duplicate(true) as AnimationLibrary
	var actor := (load(CastModel.RT_PATH % [id, id]) as PackedScene).instantiate() as Node3D
	add_child(actor)
	var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("repair", source)
	for name in library.get_animation_list():
		var animation := library.get_animation(name)
		var poses: Dictionary = {}
		for side in ["Left", "Right"]:
			for suffix in ["UpLeg", "Leg", "Foot"]: poses[side+suffix] = []
		player.play("repair/"+name, 0)
		for frame in 241:
			player.seek(animation.length*frame/240.0, true)
			player.advance(0.000001)
			skeleton.force_update_all_bone_transforms()
			for side in ["Left", "Right"]:
				var thigh := skeleton.find_bone(side+"UpLeg")
				var shin := skeleton.find_bone(side+"Leg")
				var foot := skeleton.find_bone(side+"Foot")
				var h := _world(skeleton, thigh)
				var k := _world(skeleton, shin)
				var a := _world(skeleton, foot)
				var foot_rotation := a.basis.orthonormalized().get_rotation_quaternion()
				var axis := (a.origin-h.origin).normalized()
				var along := (k.origin-h.origin).dot(axis)
				var radius := (k.origin-h.origin-axis*along).length()
				# The model faces +Z. Keep the knee in its forward sagittal plane,
				# rather than retaining the backwards/outward Blender pole solution.
				var forward := actor.global_basis.z.normalized()
				var pole := (forward-axis*forward.dot(axis)).normalized()
				var target := h.origin+axis*along+pole*radius
				_rotate(skeleton, thigh, Quaternion((k.origin-h.origin).normalized(), (target-h.origin).normalized())*h.basis.orthonormalized().get_rotation_quaternion())
				k = _world(skeleton, shin)
				var new_ankle := _world(skeleton, foot)
				_rotate(skeleton, shin, Quaternion((new_ankle.origin-k.origin).normalized(), (a.origin-k.origin).normalized())*k.basis.orthonormalized().get_rotation_quaternion())
				_rotate(skeleton, foot, foot_rotation)
				assert(_world(skeleton,foot).origin.distance_to(a.origin)<0.0001,"Knee repair must preserve foot contact")
			for bone in poses: poses[bone].append(skeleton.get_bone_pose_rotation(skeleton.find_bone(bone)))
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			var bone := str(path.get_subname(0)) if path.get_subname_count()>0 else ""
			if not poses.has(bone) or animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D: continue
			for key in range(animation.track_get_key_count(track)-1,-1,-1): animation.track_remove_key(track,key)
			for frame in 241: animation.track_insert_key(track,animation.length*frame/240.0,poses[bone][frame])
		print("REPAIRED KNEE PLANE ",id," ",name)
	library.set_meta("knee_plane", "forward sagittal; original ankle positions and orientations preserved")
	assert(ResourceSaver.save(library,"res://assets/art/locomotion3d/"+id+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	actor.free()

func _world(s: Skeleton3D,b: int) -> Transform3D:
	return s.global_transform*s.get_bone_global_pose(b)

func _rotate(s: Skeleton3D,b: int,q: Quaternion) -> void:
	var axes := s.global_basis
	var parent := s.get_bone_parent(b)
	if parent>=0: axes*=s.get_bone_global_pose(parent).basis
	s.set_bone_pose_rotation(b,axes.orthonormalized().get_rotation_quaternion().inverse()*q)
	s.force_update_all_bone_transforms()
