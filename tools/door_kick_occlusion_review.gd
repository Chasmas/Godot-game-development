extends Node2D

var failures := 0
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	add_child(Effects.new())
	var door := Door.new()
	door.setup(Vector2.ZERO, 32, 0, true)
	add_child(door)
	door.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(door.kick(Vector2(16, -12), Vector2.DOWN), "locked leaf receives the kick instead of occluding itself")
	check(door.locked and door.swing == 0 and door.omega == 0, "locked kick preserves the closed blocker")
	check(door._rattle > 0 and door._handle > 0, "locked kick produces feedback")
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 2)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = Vector2(16, -6)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not door.kick(Vector2(16, -12), Vector2.DOWN), "wall between foot and leaf prevents kick")
	wall.queue_free()
	door.unlock()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(door.kick(Vector2(16, -12), Vector2.DOWN) and door.omega > 0, "unlocked kick swings away from the kicker")
	print("DOOR KICK OCCLUSION REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
