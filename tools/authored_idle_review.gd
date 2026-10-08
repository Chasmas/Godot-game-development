extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _ready() -> void:
	add_child(Effects.new())
	for role in ["watch", "smoke"]:
		var e := Enemy.new()
		e.enemy_id = "authored_" + role
		e.idle_action = role
		add_child(e)
		e.set_physics_process(false)
		e.setup(DB.enemy(&"guard"), self, Vector2.RIGHT)
		if role == "watch":
			check(e.idle_activity == null and e.visual.weapon_sprite.visible, "Watch post keeps weapon and no human distraction")
		else:
			check(e.idle_activity != null and e.idle_activity.kind == IdleActivity.Kind.SMOKE, "Authored smoke overrides random activity")
			e._set_state(Enemy.State.SUSPICIOUS)
			check(e.idle_activity == null and e.visual.weapon_sprite.visible, "Alert drops cigarette and restores weapon")
		e.queue_free()
		await get_tree().process_frame
	for id in [&"sniper", &"zombie", &"ghoul", &"demon"]:
		var e: Enemy = Sniper.new() if id == &"sniper" else Enemy.new()
		e.idle_action = "snooze"
		add_child(e)
		e.set_physics_process(false)
		e.setup(DB.enemy(id), self, Vector2.RIGHT)
		check(e.idle_activity == null, str(id) + " cannot receive human rest activity")
		e.queue_free()
		await get_tree().process_frame
	print("AUTHORED IDLE REVIEW: ", failures, " failures")
	Audio.shutdown()
	get_tree().quit(1 if failures else 0)
