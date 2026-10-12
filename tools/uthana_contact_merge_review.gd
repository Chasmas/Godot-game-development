extends Node
## Stages a Uthana lower-body locomotion library on a preserved cast rig.
## It never touches assets/art/locomotion3d and marks the output non-production.

const MERGE := preload("res://scripts/player/contact_locomotion_merge.gd")

func _ready() -> void:
	var cast_id := OS.get_environment("UTHANA_MERGE_CAST")
	if cast_id.is_empty(): cast_id = "guard"
	var source := (load("res://assets/art/cast3d_rt/%s/%s.glb" % [cast_id, cast_id]) as PackedScene).instantiate()
	add_child(source)
	var player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := AnimationLibrary.new()
	var report: Array = []
	for source_gait in ["walk", "run", "stealth"]:
		var output_gait: String = "sneak" if source_gait == "stealth" else source_gait
		var glb := "res://build/uthana/cast_roster/motions/%s/conditioned/%s.glb" % [cast_id, source_gait]
		assert(FileAccess.file_exists(glb), "Missing conditioned Uthana study: " + glb)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(glb, state) == OK)
		var candidate := document.generate_scene(state)
		add_child(candidate)
		var candidate_player := candidate.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var contact: Animation = null
		for animation_name in candidate_player.get_animation_list():
			if animation_name != "RESET": contact = candidate_player.get_animation(animation_name)
		assert(contact != null)
		for prefix in ["", "armed_", "armed_dual_", "armed_melee_"]:
			var target_name: String = prefix + output_gait
			var original_name: String = target_name if player.has_animation(target_name) else prefix + "walk"
			if not player.has_animation(original_name): continue
			var original := player.get_animation(original_name)
			var merged := MERGE.merge(original, contact)
			_assert_upper_tracks(original, merged)
			library.add_animation(target_name, merged)
			report.append({
				"clip": target_name,
				"source": source_gait,
				"duration_seconds": merged.length,
				"upper_tracks_preserved": true,
				"runtime_approved": false,
			})
		candidate.queue_free()
	library.set_meta("runtime_approved", false)
	library.set_meta("scope", "Uthana lower body only; original combat upper body retained")
	var directory := "res://build/uthana/cast_roster/motions/%s/merged" % cast_id
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	assert(ResourceSaver.save(library, directory + "/contact_library.res", ResourceSaver.FLAG_COMPRESS) == OK)
	var output := FileAccess.open(directory + "/review.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"cast": cast_id, "clips": report, "runtime_approved": false}, "\t"))
	print("UTHANA LOWER-BODY MERGE STAGED ", cast_id, " clips=", report.size())
	Game.request_quit(0)

func _assert_upper_tracks(original: Animation, merged: Animation) -> void:
	for track in original.get_track_count():
		if MERGE.bone_name(original.track_get_path(track)) in MERGE.LOWER: continue
		var replacement := merged.find_track(original.track_get_path(track), original.track_get_type(track))
		assert(replacement >= 0, "An upper-body track was removed")
		var original_count := original.track_get_key_count(track)
		var merged_count := merged.track_get_key_count(replacement)
		assert(original_count == merged_count, "Upper-body keys must all survive retiming")
		for key in original_count:
			assert(original.track_get_key_value(track,key) == merged.track_get_key_value(replacement,key), "Upper-body pose changed")
			assert(absf(merged.track_get_key_time(replacement,key)-original.track_get_key_time(track,key)*merged.length/original.length)<.00001, "Upper-body key timing changed")
