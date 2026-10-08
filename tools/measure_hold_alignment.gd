extends Node
func bone_point(v: CharacterVisual, names: Array) -> Vector2:
	var model := v.cast_sprite as CastModel
	var bone := model._bone(names)
	assert(bone >= 0)
	var at := model._skeleton.to_global(model._skeleton.get_bone_global_pose(bone).origin)
	var local := ((model._camera.unproject_position(at) - model._origin) * model.world_scale).rotated(-model._facing_angle)
	return v.rig.to_global(local)
func _ready() -> void:
	var rows := []
	var looks := ["guard", "hunter", "handler", "security", "gunner", "bellhop", "heavy", "biker"]
	if OS.get_environment("HOLD_SINGLE_LOOK") != "":
		looks = [OS.get_environment("HOLD_SINGLE_LOOK")]
	for look in looks:
		for direction in 8:
			var actors := []
			for palette in ["cass", look]:
				var visual := CharacterVisual.new()
				add_child(visual)
				visual.setup(palette)
				visual.set_process(false)
				if palette == "cass":
					visual.cast_sprite.free()
					var model := CastModel.new()
					assert(model.configure("cass","res://build/cass_hold_isolated/cass.glb"))
					visual.cast_sprite = model
					visual.rig.add_child(model)
				visual.set_weapon(null)
				visual.set_aim(direction * TAU / 8.0)
				visual.position = Vector2.from_angle(direction * TAU / 8.0) * (6.0 if palette != "cass" else 0.0)
				visual.pose_override = "grab" if palette == "cass" else "held"
				actors.append(visual)
			for phase in [0.30,0.55,0.70]:
				for actor in actors:
					actor.pose_progress = phase
					actor.cast_sprite._body_init = false
					actor._process_cast(0.0)
				var neck := bone_point(actors[1],["Neck","neck"])
				var wrist := bone_point(actors[0],["RightHand"])
				var elbow := bone_point(actors[0],["RightForeArm"])
				var near := Geometry2D.get_closest_point_to_segment(neck,elbow,wrist)
				rows.append({"look":look,"direction":direction * 45,"phase":phase,"forearm_neck_gap_px":near.distance_to(neck),"wrist_neck_gap_px":wrist.distance_to(neck), "neck":[neck.x,neck.y], "wrist":[wrist.x,wrist.y], "elbow":[elbow.x,elbow.y]})
			for actor in actors:actor.free()
	var file := FileAccess.open("res://build/execution_review/" + ("compact_single_alignment.json" if OS.get_environment("HOLD_SINGLE_LOOK") != "" else "compact_alignment.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"approved":false,"scope":"Projected forearm-to-neck distance across8looks/8headings/3contact phases; no volumetric collision or art approval","rows":rows},"  "))
	file.close()
	print("HOLD ALIGNMENT: ",rows.size()," paired measurements")
	Game.request_quit()
