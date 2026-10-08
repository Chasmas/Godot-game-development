extends Node2D

class CrowdedGuard extends Enemy:
	func _separation() -> Vector2:
		return Vector2(24, 0)

var failures := 0

func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	add_child(Effects.new())
	for activity in ["watch", "smoke", "drink", "eat", "snooze"]:
		var guard := CrowdedGuard.new()
		guard.idle_action = activity
		add_child(guard)
		guard.setup(DB.enemy(&"guard"), self, Vector2.RIGHT)
		guard.set_physics_process(false)
		await get_tree().physics_frame
		var start := guard.global_position
		for frame in 360:
			guard._physics_process(1.0 / 120.0)
		check(guard.global_position.distance_to(start) < .01, activity + " holds its post under crowd pressure")
		check(guard.visual._cast_velocity.length() < .01, activity + " feeds stationary motion to the animation")
		guard._last_known = guard.global_position + Vector2(100, 0)
		guard._set_state(Enemy.State.SUSPICIOUS)
		guard._physics_process(1.0 / 120.0)
		check(guard.idle_activity == null and guard.visual.idle_activity_pose == "", activity + " releases the activity on alert")
		check(guard.velocity.x > 0, activity + " restores crowd steering on alert")
		guard._set_state(Enemy.State.IDLE)
		guard._move_vel = Vector2.ZERO
		guard._knock = Vector2(80, 0)
		guard._physics_process(1.0 / 120.0)
		check(guard.velocity.x > 0, activity + " still responds to physical knockback")
		guard.queue_free()
		await get_tree().process_frame
	print("IDLE STATIONARY REVIEW: ", failures, " failures")
	Audio.shutdown()
	get_tree().quit(1 if failures else 0)
