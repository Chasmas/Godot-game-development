extends Node2D

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	print("PASS " if ok else "FAIL ", message)

func _ready() -> void:
	var effects := Effects.new()
	add_child(effects)
	var look := OS.get_environment("IDLE_REVIEW_LOOK")
	if look == "":
		look = "guard"
	var visual := CharacterVisual.new()
	add_child(visual)
	visual.setup(look)
	var source := OS.get_environment("IDLE_REVIEW_MODEL")
	if source != "":
		visual.cast_sprite.free()
		var candidate := CastModel.new()
		if not candidate.configure(look, source):
			get_tree().quit(1)
			return
		visual.cast_sprite = candidate
		visual.rig.add_child(candidate)
	visual.set_weapon(DB.weapon(&"pistol"))
	var smoker := IdleActivity.new()
	visual.rig.add_child(smoker)
	smoker.setup(visual, IdleActivity.Kind.SMOKE, "regression")
	smoker._t = smoker._cycle * 0.3
	smoker._process(0.0)
	visual._process_cast(0.0)
	check(visual.cast_sprite.clip == "smoke", "smoker plays authored standing activity")
	check(visual._cig == null, "NPC smoking does not spawn a duplicate player cigarette")
	check(smoker.to_global(smoker._prop_local(0.3)).distance_to(visual.rig.to_global(visual.cast_sprite.grip())) < 0.01, "cigarette follows the actual hand socket")
	smoker.drop()
	check(visual.idle_activity_pose == "" and visual.weapon_sprite.visible, "alert releases activity and restores the equipped weapon")
	await get_tree().process_frame
	visual.set_weapon(null)
	var sleeper := IdleActivity.new()
	visual.rig.add_child(sleeper)
	sleeper.setup(visual, IdleActivity.Kind.SNOOZE, "regression")
	var model := visual.cast_sprite as CastModel
	model.play_sample("idle", 0.0, 0.0)
	var standing_y := model._skeleton.to_global(model._skeleton.get_bone_global_pose(model._hips).origin).y
	sleeper._t = sleeper._cycle * 0.5
	sleeper._process(0.0)
	visual._process_cast(0.0)
	var seated_y := model._skeleton.to_global(model._skeleton.get_bone_global_pose(model._hips).origin).y
	check(model.clip == "doze" and standing_y - seated_y > 0.2, "sleeper has lowered hips in the authored seated pose")
	print("Standing hips=", standing_y, " seated hips=", seated_y)
	if OS.get_environment("IDLE_GROUND_CHECK") == "1":
		for name in ["LeftFoot","RightFoot"]:
			var bone := model._skeleton.find_bone(name)
			check(bone >= 0,"Seated ankle exists: " + name)
			if bone >= 0:
				var height := model._skeleton.to_global(model._skeleton.get_bone_global_pose(bone).origin).y
				print(name," seated ankle height=",height)
				check(absf(height-0.10) < 0.025,"Seated ankle support height: " + name)
	await get_tree().process_frame
	var chair := sleeper._chair
	var chair_position := chair.global_position
	sleeper.drop()
	check(not visual.weapon_sprite.visible, "waking an unarmed guard does not reveal a stale weapon")
	check(not visual.legs.visible, "waking a Blender guard does not reveal fallback legs")
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_instance_valid(chair) and chair.is_inside_tree() and chair.tipped, "alert reparents and tips the occupied chair")
	check(chair.global_position.is_equal_approx(chair_position), "chair remains at the seated position after alert")
	var chair_model := chair.get_child(0) as PropModel
	check(chair_model._animation_player.current_animation == "tip", "alert plays the runtime Blender chair animation")
	await get_tree().create_timer(0.75).timeout
	check(not chair_model._animation_player.is_playing(), "chair fall ends instead of looping")
	check(chair_model._viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "settled chair stops continuous rendering")
	check(chair_model._animation_player.current_animation_position >= 0.59, "settled chair preserves the final fallen pose")
	for activity_kind in [IdleActivity.Kind.SMOKE, IdleActivity.Kind.SNOOZE]:
		visual.set_weapon(DB.weapon(&"pistol"), true)
		check(visual.weapon_sprite.visible and visual.weapon_sprite2.visible, "dual weapons visible before activity")
		var dual_activity := IdleActivity.new()
		visual.rig.add_child(dual_activity)
		dual_activity.setup(visual, activity_kind, "dual_regression")
		await get_tree().process_frame
		check(not visual.weapon_sprite.visible and not visual.weapon_sprite2.visible, "activity puts away both pistols")
		dual_activity.drop()
		check(visual.weapon_sprite.visible and visual.weapon_sprite2.visible, "alert restores both equipped pistols")
		await get_tree().process_frame
	visual.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("IDLE ACTIVITY REGRESSION: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
