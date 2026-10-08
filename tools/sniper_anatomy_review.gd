extends Node
func _ready() -> void:
	var look := OS.get_environment("HOLD_REVIEW_LOOK")
	if look == "": look = "sniper"
	var source := OS.get_environment("HOLD_REVIEW_TARGET_MODEL")
	if source == "": source = "res://build/sniper_held_pole_fixed_isolated/sniper.glb"
	var v := CharacterVisual.new()
	add_child(v)
	v.setup(look)
	v.cast_sprite.free()
	var model := CastModel.new()
	assert(model.configure(look, source))
	v.cast_sprite = model
	v.rig.add_child(model)
	v.set_process(false)
	v.set_weapon(null)
	v.pose_override = "held"
	var rows := []
	for index in 65:
		var phase := minf(index / 64.0, 0.995)
		v.pose_progress = phase
		v._process_cast(0.0)
		var bones := {}
		for name in ["Hips", "Neck", "Head", "RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm", "LeftHand"]:
			var bone := model._bone([name, name.to_lower()])
			assert(bone >= 0)
			var at := model._skeleton.to_global(model._skeleton.get_bone_global_pose(bone).origin)
			bones[name] = [at.x, at.y, at.z]
		rows.append({"phase": phase,"bones":bones})
	var file := FileAccess.open("res://build/execution_review/" + look + "_anatomy.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	Game.request_quit()
