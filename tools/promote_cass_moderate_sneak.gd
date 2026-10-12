extends SceneTree

## Promote only the reviewed moderate Cass stealth lower body. The model and
## all non-stealth clips remain the current approved runtime versions.
func _init() -> void:
	var source := load("res://build/locomotion_candidates/cass/cass_moderate_sneak_staging.res") as AnimationLibrary
	assert(source != null)
	assert(float((source.get_meta("native_speeds") as Dictionary).get("sneak", 0.0)) == 20.0)
	for clip in ["sneak", "armed_sneak", "armed_dual_sneak", "armed_melee_sneak"]:
		assert(source.has_animation(clip))
	source.set_meta("runtime_approved", true)
	assert(ResourceSaver.save(source, "res://assets/art/locomotion3d/cass.res", ResourceSaver.FLAG_COMPRESS) == OK)
	print("CASS MODERATE SNEAK PROMOTED")
	quit()
