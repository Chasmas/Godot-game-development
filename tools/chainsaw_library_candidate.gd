extends Node
func _ready() -> void:
	var current := CastModel.create("cass") as CastModel
	var donor := CastModel.new()
	assert(donor.configure("cass", "res://build/chainsaw_pose_candidate/cass.glb"))
	add_child(current)
	add_child(donor)
	var max_rest_delta := 0.0
	var failures: Array = []
	for bone in donor._skeleton.get_bone_count():
		var name := donor._skeleton.get_bone_name(bone)
		var target := current._skeleton.find_bone(name)
		if target < 0:
			failures.append("Missing bone " + name)
			continue
		var a := donor._skeleton.get_bone_rest(bone)
		var b := current._skeleton.get_bone_rest(target)
		max_rest_delta = maxf(max_rest_delta, a.origin.distance_to(b.origin))
		for axis in 3: max_rest_delta = maxf(max_rest_delta, a.basis[axis].distance_to(b.basis[axis]))
	var library := AnimationLibrary.new()
	for name in ["aim", "armed_walk", "armed_run", "armed_sneak", "chainsaw_raise"]:
		var animation := donor._player.get_animation(name).duplicate(true) as Animation
		donor._skeleton.reset_bone_poses()
		donor._player.play(name, 0.0)
		donor._player.seek(0.0, true)
		donor._player.advance(0.001)
		var rotation_paths: Dictionary = {}
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				rotation_paths[str(animation.track_get_path(track))] = true
		var skeleton_path := donor._player.get_node(donor._player.root_node).get_path_to(donor._skeleton)
		for bone in donor._skeleton.get_bone_count():
			var path := NodePath(str(skeleton_path) + ":" + donor._skeleton.get_bone_name(bone))
			if rotation_paths.has(str(path)): continue
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, path)
			animation.track_insert_key(track, 0.0, donor._skeleton.get_bone_pose_rotation(bone))
			animation.track_insert_key(track, animation.length, donor._skeleton.get_bone_pose_rotation(bone))
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			if not current._player.get_node(current._player.root_node).has_node(NodePath(path.get_concatenated_names())):
				failures.append("Unresolved track " + str(path))
		library.add_animation(name if name.begins_with("chainsaw_") else "chainsaw_" + name.trim_prefix("armed_"), animation)
	if max_rest_delta > 0.0001: failures.append("Rest mismatch " + str(max_rest_delta))
	var saved := ResourceSaver.save(library, "res://build/chainsaw_pose_candidate/chainsaw_clips.res", ResourceSaver.FLAG_COMPRESS)
	if saved != OK: failures.append("Save error " + str(saved))
	var file := FileAccess.open("res://build/chainsaw_pose_candidate/library_compatibility.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures, "max_rest_delta":max_rest_delta,"animations":library.get_animation_list(),"scope":"Bone rest and animation track resolution on current Cass model; not gameplay/transitions"}, "  "))
	print("CHAINSAW LIBRARY COMPATIBILITY: ", failures)
	Game.request_quit(0 if failures.is_empty() else 1)
