extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	for action in ["down", "stun", "execution"]:
		var guard := Enemy.new()
		guard.idle_action = "watch"
		add_child(guard)
		guard.setup(DB.enemy(&"guard"), self, Vector2.RIGHT)
		guard.set_physics_process(false)
		guard.visual.set_process(false)
		guard.visual.swing()
		guard._windup_t = 0.1
		guard._reload_t = 1.0
		var serial := guard.visual.attack_serial
		if action == "down":
			guard.knock_down(DamageInfo.make(DamageInfo.Type.PUNCH, null, guard.position, Vector2.RIGHT, &"fists", &"punch"))
		elif action == "stun": guard._stun(0.4, Vector2.RIGHT)
		else: guard.begin_execution(self)
		check(guard._windup_t < 0.0 and guard._reload_t == 0.0, action+" clears controller attack/reload")
		check(guard.visual._swing_t < 0.0 and guard.visual.attack_serial > serial, action+" cancels authored attack and attached effects")
		if action == "down":
			guard.visual._process_cast(0.0)
			check(guard.visual.cast_sprite.clip == "knocked", "downed body owns pose immediately instead of finishing swing")
			guard.begin_execution(self)
			check(guard._held, "ground execution freezes target physics like standing execution")
			guard.cancel_execution(self)
			check(not guard._held and guard.state == Enemy.State.DOWNED and guard._down_t <= Enemy.DOWN_TIME, "cancelled ground execution releases target without standing it up")
		elif action == "execution":
			check(guard._held, "standing execution freezes target physics")
			guard.cancel_execution(self)
			check(not guard._held and guard._stun_t == 0.35, "cancelled standing execution releases target with recovery grace")
		guard.queue_free()
		await get_tree().process_frame
	for frame in 2: await get_tree().process_frame
	print("ENEMY INTERRUPT REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
