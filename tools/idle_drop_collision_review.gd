extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	for mask in [Layers.WORLD, Layers.PROP]:
		var wall := StaticBody2D.new()
		wall.collision_layer = mask
		wall.position = Vector2(110, 100)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(2, 60)
		shape.shape = box
		wall.add_child(shape)
		add_child(wall)
		for frame in 2: await get_tree().physics_frame
		for kind in [IdleActivity.Kind.SMOKE, IdleActivity.Kind.DRINK, IdleActivity.Kind.EAT]:
			var prop := IdleActivity.DroppedProp.new()
			prop.kind = kind
			prop.start_pos = Vector2(100,100)
			prop.vel = Vector2(200,0)
			add_child(prop)
			prop.set_process(false)
			prop._process(0.1)
			check(prop.global_position.x < 109, "dropped prop stays before thin blocker mask=%d kind=%d" % [mask,kind])
			check(prop.vel.x <= 0, "dropped prop loses forward motion on impact mask=%d kind=%d" % [mask,kind])
			prop.free()
		wall.free()
		for frame in 2: await get_tree().physics_frame
	var free_prop := IdleActivity.DroppedProp.new()
	free_prop.start_pos = Vector2(100,100)
	free_prop.vel = Vector2(30,0)
	add_child(free_prop)
	free_prop.set_process(false)
	free_prop._process(0.1)
	check(free_prop.global_position.is_equal_approx(Vector2(103,100)), "unobstructed dropped prop keeps its settling travel")
	free_prop.free()
	for frame in 2: await get_tree().process_frame
	print("IDLE DROP COLLISION REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
