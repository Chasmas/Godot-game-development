extends Node
func _ready() -> void:
	var level := Level.new()
	level.nav = AStarGrid2D.new()
	level.nav.region = Rect2i(0, 0, 8, 5)
	level.nav.cell_size = Vector2(16,16)
	level.nav.offset = Vector2(8,8)
	level.nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	level.nav.update()
	for y in 5: level.nav.set_point_solid(Vector2i(4,y), true)
	var enemy := Enemy.new()
	enemy.level = level
	enemy.position = Vector2(24,40)
	var target := Vector2(104,40)
	var blocked := level.get_nav_path(enemy.position, target)
	var velocity := enemy._go_to(target, 60.0)
	var ok := blocked.is_empty() and velocity == Vector2.ZERO
	level.nav.set_point_solid(Vector2i(4,2), false)
	enemy._repath_t = 0.0
	var reopened := level.get_nav_path(enemy.position, target)
	ok = ok and not reopened.is_empty() and enemy._go_to(target,60.0).length() > 0.0
	print("BLOCKED ROUTE REVIEW: ", "0 failures" if ok else "1 failure")
	enemy.free()
	level.free()
	Audio.shutdown()
	get_tree().quit(0 if ok else 1)
