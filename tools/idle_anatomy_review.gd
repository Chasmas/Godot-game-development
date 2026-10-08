extends Node
func _ready() -> void:
	var look := OS.get_environment("IDLE_REVIEW_LOOK")
	if look == "": look = "sniper"
	var source := OS.get_environment("IDLE_REVIEW_MODEL")
	if source == "": source = "res://build/sniper_smoke_fitted_isolated/sniper.glb"
	var v := CharacterVisual.new()
	add_child(v)
	v.setup(look)
	v.cast_sprite.free()
	var model := CastModel.new()
	if not model.configure(look, source):
		Game.request_quit(1)
		return
	v.cast_sprite = model
	v.rig.add_child(model)
	v.set_process(false)
	v.set_weapon(null)
	var clip := OS.get_environment("IDLE_REVIEW_CLIP")
	if clip == "": clip = "smoke"
	v.pose_override = clip
	var rows := []
	var samples := maxi(65,int(OS.get_environment("IDLE_REVIEW_SAMPLES")))
	for index in samples:
		var phase := minf(index / float(samples-1), 0.995)
		v.pose_progress = phase
		v._process_cast(0.0)
		var bones := {}
		for name in ["Hips", "Neck", "Head", "RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm", "LeftHand", "LeftFoot", "RightFoot"]:
			var bone := model._bone([name, name.to_lower()])
			assert(bone >= 0)
			var at := model._skeleton.to_global(model._skeleton.get_bone_global_pose(bone).origin)
			bones[name] = [at.x, at.y, at.z]
		rows.append({"phase": phase,"bones":bones})
	var file := FileAccess.open("res://build/" + look + "_" + clip + "_anatomy.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"approved":false,"source":source,"clip":clip,"rows":rows},"  "))
	Game.request_quit()
