extends RefCounted
## Build a per-instance animation: retain combat/arm tracks, replace legs/hips
## with a verified contact cycle. Does not edit imported animation resources.
const LOWER := ["Hips","LeftUpLeg","LeftLeg","LeftFoot","LeftToeBase","RightUpLeg","RightLeg","RightFoot","RightToeBase"]

static func bone_name(path: NodePath) -> String:
	return str(path.get_subname(0)) if path.get_subname_count()>0 else ""

static func merge(original: Animation, contact: Animation) -> Animation:
	assert(original.length>0 and contact.length>0)
	var result := original.duplicate(true) as Animation
	var paths: Dictionary={}
	for track in original.get_track_count():
		var bone := bone_name(original.track_get_path(track))
		if bone in LOWER:paths[bone]=original.track_get_path(track)
	for track in range(result.get_track_count()-1,-1,-1):
		if bone_name(result.track_get_path(track)) in LOWER:
			result.remove_track(track)
			continue
		# Retiming in place can collide with an unretimed key and discard it.
		# Snapshot every key, empty the track, then rebuild at scaled times.
		var keys: Array = []
		for key in result.track_get_key_count(track):
			keys.append([result.track_get_key_time(track,key)*contact.length/original.length, result.track_get_key_value(track,key), result.track_get_key_transition(track,key)])
		for key in range(result.track_get_key_count(track)-1,-1,-1):
			result.track_remove_key(track,key)
		for key in keys:
			result.track_insert_key(track,key[0],key[1],key[2])
	var imported := 0
	for track in contact.get_track_count():
		var bone := bone_name(contact.track_get_path(track))
		if bone not in LOWER:continue
		assert(paths.has(bone),"Contact bone must exist in destination rig: "+bone)
		var index := result.get_track_count()
		contact.copy_track(track,result)
		result.track_set_path(index,paths[bone])
		imported+=1
	assert(imported>0)
	result.length=contact.length
	result.loop_mode=Animation.LOOP_LINEAR
	return result
