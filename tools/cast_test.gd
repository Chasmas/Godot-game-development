extends Node
var failures := 0
func complete_pose(cast: CastSprite) -> bool:
	if cast is CastModel:
		var model := cast as CastModel
		var animation := model._player.get_animation(model.clip)
		return absf(model._player.current_animation_position - animation.length * .995) < .002
	return cast.frame_index == cast.clips[cast.clip].size() - 1
func check(ok: bool, label: String) -> void:
	print("  ", "ok " if ok else "FAIL ", label)
	if not ok:
		failures += 1
func _ready() -> void:
	await get_tree().process_frame
	var v := CharacterVisual.new()
	add_child(v)
	v.setup("cass")
	v.set_process(false)
	check(v.cast_sprite != null, "Cass loads rendered clips")
	if v.cast_sprite == null:
		get_tree().quit(1)
		return
	for name in ["idle", "walk", "run", "sneak", "aim", "armed_walk", "armed_run", "armed_sneak", "roll", "punch", "melee", "kick", "death", "smoke"]:
		check(v.cast_sprite.clips.has(name), "clip exists: " + name)
		v.cast_sprite.play_sample(name, 0.0, 1.0)
		check(complete_pose(v.cast_sprite), "complete clip: " + name)
	v.set_weapon(DB.weapon("pistol"))
	for angle in [0.0, PI / 2, PI, -PI / 2]:
		v.set_aim(angle)
		v.update_move(Vector2.RIGHT * 120, 0.016)
		v._process(0.016)
		check(v.cast_sprite.clip == "armed_walk", "armed locomotion")
		check(v.muzzle_global().is_finite() and v.muzzle_global().distance_to(v.global_position) < 40.0, "muzzle stays near hand")
	v.roll(Vector2.LEFT, 0.3)
	v._process(0.15)
	var roll_offset := absf(angle_difference(v.aim_angle, Vector2.LEFT.angle()))
	var expected_roll_facing := Vector2.LEFT.angle() if roll_offset < deg_to_rad(55.0) else v.aim_angle
	check(v.cast_sprite.clip == "roll" and absf(angle_difference(v.rig.rotation, expected_roll_facing)) < .001, "roll preserves direction-dependent facing")
	v._process(0.2)
	v._process(0.016)
	check(not v.is_rolling() and v.weapon_sprite.modulate.a == 1.0, "roll restores weapon")
	v.kick_leg()
	v._process(0.1)
	check(v.cast_sprite.clip == "kick", "kick clip")
	v._process(0.3)
	v.swing()
	v._process(0.05)
	check(v.cast_sprite.clip == "melee", "melee clip")
	v._process(0.3)
	v.punch()
	v._process(0.05)
	check(v.cast_sprite.clip in ["punch", "punch_left"], "punch clip")
	var dead := Corpse.new()
	dead.setup("cass", Vector2.RIGHT, true, "", PI / 2)
	add_child(dead)
	dead._process(1.0)
	check(dead._cast != null and complete_pose(dead._cast), "corpse settles at the complete death pose")
	for w in DB.all_weapons():
		v.set_weapon(w)
		v.update_move(Vector2.ZERO, 0.016)
		for kind in ["mag", "shell", "dual"]:
			v.reload_anim(1.0, kind)
			for i in 70:
				v._process(1.0 / 60.0)
			check(v._reload_k < 0.0 and v.weapon_sprite.position.is_finite(), str(w.id) + " reload " + kind)
	v.set_weapon(DB.weapon("pistol"), true)
	v._process(0.1)
	for angle in [0.0, PI / 2, PI, -PI / 2]:
		v.set_aim(angle)
		v._process(.1)
		var distinct := v._hand.distance_to(v._hand2) > 4.0
		if v.cast_sprite is CastModel:
			var cast := v.cast_sprite as CastModel
			var right: int = cast._hand_bones[0]
			var left: int = cast._hand_bones[1]
			var a := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(right).origin)
			var b := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(left).origin)
			# Distinct hands can overlap in the oblique 2D projection when viewed
			# edge-on. Validate separate bones and actual 3D positions instead.
			distinct = right != left and a.is_finite() and b.is_finite() and a.distance_to(b) > .01
		check(v.cast_sprite.clip == "aim_dual" and distinct and v._hand.is_finite() and v._hand2.is_finite(), "dual pistols have distinct grips at angle " + str(angle))
	v.set_weapon(null)
	v.idle_fidgets = true
	v._still_t = 10.0
	v._process(0.1)
	check(v.cast_sprite.clip == "smoke" and v._cig != null, "idle smoking starts with attached cigarette")
	v.update_move(Vector2.RIGHT * 120, 0.1)
	v._process(0.1)
	check(v.cast_sprite.clip == "walk" and v._cig == null, "movement interrupts smoking")
	v._still_t = 10.0
	v.update_move(Vector2.ZERO, 0.1)
	v._process(0.1)
	v.set_weapon(DB.weapon("pistol"))
	v._process(0.1)
	check(v._cig == null and v.cast_sprite.clip == "aim", "equipping a gun interrupts smoking")
	var guard := CharacterVisual.new()
	add_child(guard)
	guard.setup("guard")
	check(guard.cast_sprite is CastModel, "guard uses the current 3D renderer")
	for identity in ["zombie", "ghoul", "demon"]:
		var creature := CharacterVisual.new()
		add_child(creature)
		creature.setup(identity)
		creature.set_process(false)
		creature.idle_fidgets = true
		creature._still_t = 12.0
		creature._process(.1)
		check(creature.cast_sprite != null and creature.cast_sprite.clip != "smoke" and creature._cig == null, identity + " cannot smoke through idle fidgets")
		var activity := IdleActivity.new()
		creature.rig.add_child(activity)
		activity.setup(creature, IdleActivity.Kind.SMOKE, identity)
		check(activity.is_queued_for_deletion() and creature.idle_activity_pose == "", identity + " rejects scripted human activity")
	print("CAST TEST DONE: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
