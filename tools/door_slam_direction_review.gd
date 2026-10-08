extends Node2D

class Target extends Node2D:
	var received: DamageInfo
	func is_alive() -> bool: return true
	func take_damage(info: DamageInfo) -> String:
		received = info
		return "hurt"

var failures := 0
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	add_child(Effects.new())
	for angle in [0.0, PI * .5, PI]:
		for direction in [-1.0, 1.0]:
			var door := Door.new()
			door.setup(Vector2.ZERO, 32, angle)
			add_child(door)
			door.set_physics_process(false)
			var target := Target.new()
			add_child(target)
			target.add_to_group("enemies")
			target.position = door.leaf_dir() * 16
			door.omega = direction * 12
			var previous := door.leaf_dir() * 16
			door.swing += direction * .01
			var motion := (door.leaf_dir() * 16 - previous).normalized()
			door._sweep_hits()
			check(target.received != null, "slam hits target at angle " + str(angle))
			if target.received:
				check(target.received.dir.dot(motion) > .99, "knockback follows leaf motion: " + str(angle) + "/" + str(direction))
				check(not target.received.lethal, "door impact remains nonlethal")
			target.queue_free()
			door.queue_free()
			await get_tree().process_frame
	for delta in [.05, .1]:
		var door := Door.new()
		door.setup(Vector2.ZERO, 32, 0)
		add_child(door)
		door.set_physics_process(false)
		var target := Target.new()
		add_child(target)
		target.add_to_group("enemies")
		target.position = Vector2.from_angle(deg_to_rad(30)) * 24
		door.omega = 19
		door._physics_process(delta)
		check(target.received != null, "fast leaf strikes an intermediate target at dt=" + str(delta))
		target.queue_free()
		door.queue_free()
		await get_tree().process_frame
	print("DOOR SLAM DIRECTION REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
