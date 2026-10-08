extends Node2D
var failures := 0
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	add_child(Effects.new())
	for delta in [1.0/120.0, .05, .1]:
		var door := Door.new()
		door.setup(Vector2.ZERO, 32, 0)
		add_child(door)
		door.set_physics_process(false)
		var wall := StaticBody2D.new()
		wall.collision_layer = Layers.WORLD
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(2, 2)
		shape.shape = rectangle
		wall.add_child(shape)
		wall.position = Vector2.from_angle(deg_to_rad(30)) * 20
		add_child(wall)
		await get_tree().physics_frame
		await get_tree().physics_frame
		door.omega = 19
		var max_angle := 0.0
		for frame in 30:
			door._integrate(delta)
			max_angle = maxf(max_angle, door.swing)
		var ok := max_angle < deg_to_rad(30)
		if not ok: failures += 1
		print("PASS " if ok else "FAIL ", "wall stop dt=", delta, " max degrees=", rad_to_deg(max_angle))
		door.queue_free()
		wall.queue_free()
		await get_tree().process_frame
	print("DOOR WALL STOP REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
