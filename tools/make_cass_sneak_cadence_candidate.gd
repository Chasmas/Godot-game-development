extends SceneTree

## Builds a staging-only Cass library: preserve every promoted clip except the
## freshly reviewed moderate-stride stealth lower body.
func _init() -> void:
	var runtime := load("res://assets/art/locomotion3d/cass.res") as AnimationLibrary
	assert(runtime != null)
	var source := load("res://assets/art/cast3d_rt/cass/cass.glb") as PackedScene
	var actor := source.instantiate()
	var source_player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file("res://build/locomotion_candidates/cass/grounded/sneak/sneak_contact_candidate.glb", state) == OK)
	var candidate := document.generate_scene(state)
	var candidate_player := candidate.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var candidate_animation: Animation = null
	for animation_name in candidate_player.get_animation_list():
		if animation_name != "RESET":
			candidate_animation = candidate_player.get_animation(animation_name)
	assert(candidate_animation != null)
	var output := runtime.duplicate(true) as AnimationLibrary
	for name in ["sneak", "armed_sneak", "armed_dual_sneak", "armed_melee_sneak"]:
		var original := source_player.get_animation(name)
		assert(original != null)
		if output.has_animation(name): output.remove_animation(name)
		output.add_animation(name, preload("res://scripts/player/contact_locomotion_merge.gd").merge(original, candidate_animation))
	var native: Dictionary = output.get_meta("native_speeds").duplicate()
	native["sneak"] = 20.0
	output.set_meta("native_speeds", native)
	output.set_meta("runtime_approved", false)
	assert(ResourceSaver.save(output, "res://build/locomotion_candidates/cass/cass_moderate_sneak_staging.res", ResourceSaver.FLAG_COMPRESS) == OK)
	print("CASS MODERATE SNEAK LIBRARY BUILT")
	quit()
