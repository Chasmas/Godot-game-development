extends Node

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("ok: ", message)

func _ready() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 200)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(80, 0)
	add_child(wall)
	var dog := Dog.new()
	add_child(dog)
	var data := EnemyData.new()
	data.palette = "shepherd"
	data.weapon_id = &""
	dog.setup(data, self, Vector2.RIGHT)
	dog.set_physics_process(false)
	for frame in 120:
		await get_tree().physics_frame
		dog.heel_follow(1.0 / 60.0, Vector2(160, 0), Vector2.RIGHT)
	check(dog.position.x > 30.0, "leashed dog approaches handler")
	check(dog.position.x < 72.0, "leashed dog cannot pass through wall")
	check(dog._speed_now < 1.5, "blocked dog stops gait cadence")
	wall.queue_free()
	for frame in 180:
		await get_tree().physics_frame
		dog.heel_follow(1.0 / 60.0, Vector2(160, 0), Vector2.RIGHT)
	check(dog.position.x > 150.0, "dog resumes following once obstacle is removed")
	check(dog._speed_now < 1.5, "dog settles beside handler")
	dog.queue_free()
	await get_tree().process_frame
	print("DOG LEASH REGRESSION: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
