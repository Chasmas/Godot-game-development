extends Node
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", text)
func _ready() -> void:
	for file in ["m01_sunset_palms", "m02_yermo_salvage", "m03_khsc_studios", "m04_villa_estrella"]:
		var level := Level.new()
		level.data = JSON.parse_string(FileAccess.get_file_as_string("res://levels/" + file + ".json"))
		for enemy_id in level.data.enemies:
			var parts: PackedStringArray = str(enemy_id).split(",")
			var spawn_tile := level.b_ch(int(parts[0]), int(parts[1]))
			check(LevelBuilder.ENEMY_CHARS.has(spawn_tile), file + " " + enemy_id + " configuration has a real spawn")
			for point in level.data.enemies[enemy_id].get("patrol", []):
				var tile := level.b_ch(int(point[0]), int(point[1]))
				check(not tile in "#TCblwkcnVtQIYFoKZj ~", file + " " + enemy_id + " patrol " + str(point) + " is off furniture/walls")
		for camera in level.data.get("cameras", []):
			var cell := Vector2i(int(camera.cell[0]), int(camera.cell[1]))
			var corner := level._camera_corner(cell)
			var mounted: Vector2 = corner.get("pos", Vector2(cell) * 16.0 + Vector2(8, 8))
			check(Vector2i(floori(mounted.x / 16.0), floori(mounted.y / 16.0)) == cell, file + " camera stays in designed cell " + str(cell))
		level.free()
	print("ENCOUNTER LAYOUT REVIEW: ", failures, " failures")
	Audio.shutdown()
	get_tree().quit(1 if failures else 0)
