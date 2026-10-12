extends Node
func _ready() -> void:
	var records: Array=[]
	var output:="res://assets/art/locomotion3d"
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	for id in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
		if id=="eldorado":continue
		var merge: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/contact_locomotion_merge_review_"+id+"_preserved.json"))
		var renderer: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/contact_cast_renderer_"+id+".json"))
		assert(renderer.cast==id and renderer.clips.size()==3 and merge.clips.size()>=6)
		for clip in merge.clips:
			assert(clip.upper_tracks_preserved and clip.worst_foot_drift_metres<.002 and clip.directional_stance_sweeps==32)
		for clip in renderer.clips:
			assert(clip.aim_movement_pairs==64 and clip.both_feet and clip.worst_drift_px<.05)
		var library:=load("res://build/locomotion_candidates/"+id+"/preserved/contact_library.res") as AnimationLibrary
		assert(library!=null and library.has_meta("stance_fractions"))
		library.set_meta("runtime_approved",true)
		assert(ResourceSaver.save(library,output+"/"+id+".res",ResourceSaver.FLAG_COMPRESS)==OK)
		records.append({"cast":id,"unchanged_model_sha256":FileAccess.get_sha256("res://assets/art/cast3d_rt/%s/%s.glb" % [id,id]),"clips":library.get_animation_list(),"native_speed_px_s":library.get_meta("native_speeds"),"renderer_review":renderer.clips})
	assert(records.size()==24)
	var manifest:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"runtime_promoted":true,"scope":"Existing 24 humanoid models preserved; contact lower-body animation, directional step IK and whole-body aim","traversal_scale":Player.TRAVERSAL_SPEED_SCALE,"casts":records},"\t"))
	print("CONTACT LOCOMOTION PROMOTED ",records.size()," EXISTING MODELS PRESERVED")
	Game.request_quit(0)
