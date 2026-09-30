extends Node
var failures := 0
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
		check(v.cast_sprite.frame_index == v.cast_sprite.clips[name].size() - 1, "complete clip: " + name)
	v.set_weapon(DB.weapon("pistol"))
	for angle in [0.0, PI / 2, PI, -PI / 2]:
		v.set_aim(angle)
		v.update_move(Vector2.RIGHT * 120, 0.016)
		v._process(0.016)
		check(v.cast_sprite.clip == "armed_walk", "armed locomotion")
		check(v.muzzle_global().is_finite() and v.muzzle_global().distance_to(v.global_position) < 40.0, "muzzle stays near hand")
	v.roll(Vector2.LEFT, 0.3)
	v._process(0.15)
	check(v.cast_sprite.clip == "roll" and is_equal_approx(v.rig.rotation, PI), "roll follows movement direction")
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
	check(dead._cast != null and dead._cast.frame_index == dead._cast.clips.death.size() - 1, "corpse settles at the complete death pose")
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
	check(v.cast_sprite.clip == "aim_dual" and v._hand.distance_to(v._hand2) > 4.0, "dual pistols have distinct grips")
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
	check(guard.cast_sprite == null and guard.torso.visible, "other characters keep existing renderer")
	print("CAST TEST DONE: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
