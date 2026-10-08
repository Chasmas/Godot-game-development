extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _ready() -> void:
	var camera := SecurityCamera.new()
	camera.base_angle = 0.0
	add_child(camera)
	camera.set_physics_process(false)
	camera.set_process(false)
	for i in 2: await get_tree().physics_frame
	camera._aim = 0.0
	check(camera.can_see_point(Vector2(70,0)), "Clear central corridor is visible")
	check(not camera.can_see_point(Vector2(15,0)), "Under-lens blind zone is safe")
	check(not camera.can_see_point(Vector2(130,0)), "Beyond range is safe")
	check(not camera.can_see_point(Vector2(-70,0)), "Behind camera is safe")
	check(not camera.can_see_point(Vector2(60,60)), "Outside cone is safe")
	var wall := StaticBody2D.new()
	wall.position = Vector2(40,0)
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8,80)
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	for i in 2: await get_tree().physics_frame
	check(not camera.can_see_point(Vector2(70,0)), "Wall blocks camera detection")
	camera._rebuild_cone()
	check(camera._poly[6].x <= 36.1, "Displayed cone stops at the same wall")
	check(camera._scan_segments(70.0).is_empty(), "Moving scan highlight cannot paint beyond blocking wall")
	check(not camera._scan_segments(35.0).is_empty(), "Moving scan highlight remains visible before wall")
	wall.collision_layer = Layers.PROP
	for i in 2: await get_tree().physics_frame
	check(not camera.can_see_point(Vector2(70,0)), "Tall prop blocks camera detection")
	wall.collision_layer = Layers.LOW
	for i in 2: await get_tree().physics_frame
	check(camera.can_see_point(Vector2(70,0)), "Low furniture permits elevated camera view")
	camera._rebuild_cone()
	check(not camera._scan_segments(70.0).is_empty(), "Moving scan highlight crosses low furniture with elevated view")
	camera.power_zone = "warehouse"
	camera._meter = 0.7
	Events.lights_changed.emit(&"kennels", false)
	check(camera.powered, "Other circuit does not disable camera")
	Events.lights_changed.emit(&"warehouse", false)
	camera._rebuild_cone()
	check(not camera.can_see_point(Vector2(70,0)) and camera._poly.is_empty() and camera._meter == 0.0, "Cut circuit removes detection, cone and partial alarm")
	Events.lights_changed.emit(&"warehouse", true)
	check(camera.can_see_point(Vector2(70,0)) and camera._meter == 0.0, "Restored circuit resumes surveillance without stale alarm")
	camera._broken = true
	check(not camera.can_see_point(Vector2(70,0)), "Destroyed camera cannot see")
	print("SECURITY VISION REVIEW: ", failures, " failures")
	Audio.shutdown()
	get_tree().quit(1 if failures else 0)
