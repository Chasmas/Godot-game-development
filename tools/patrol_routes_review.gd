extends Node
var failures := 0
var report: Array = []
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	for mission in ["m01_checkout", "m02_dog_days", "m03_prime_time", "m04_sweet_dreams"]:
		Game.replay_mission(mission)
		for i in 90: await get_tree().physics_frame
		var level := get_tree().get_first_node_in_group("level") as Level
		if not level:
			failures += 1
			continue
		level.player.god_mode = true
		for enemy in level.enemies:
			enemy.set_physics_process(false)
			if enemy.patrol_points.is_empty(): continue
			for i in enemy.patrol_points.size():
				var a := Vector2i(enemy.patrol_points[i] / 16.0)
				var b := Vector2i(enemy.patrol_points[(i + 1) % enemy.patrol_points.size()] / 16.0)
				var path := level.nav.get_id_path(a, b, false)
				var runtime_path := level.get_nav_path(enemy.patrol_points[i],enemy.patrol_points[(i+1)%enemy.patrol_points.size()])
				var ok := not level.nav.is_point_solid(a) and not level.nav.is_point_solid(b) and not path.is_empty() and not runtime_path.is_empty()
				if not ok: failures += 1
				var item := {"mission":mission, "enemy":enemy.enemy_id, "from":[a.x,a.y], "to":[b.x,b.y], "reachable":ok, "path_cells":path.size()}
				report.append(item)
				print("PASS " if ok else "FAIL ", mission, " ", enemy.enemy_id, " ", a, " -> ", b)
	var file := FileAccess.open("res://build/patrol_routes_review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual initial mission navigation connectivity, not live patrol or encounter balance approval", "routes":report}, "  "))
	print("PATROL ROUTES REVIEW: ", failures, " failures / ", report.size(), " legs")
	SaveManager.data = saved
	Game.request_quit(1 if failures else 0)
