extends Node
var failures := 0
var report: Array = []
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var saved_path := SaveManager.save_path
	SaveManager.save_path = "user://security_coverage_review_save.json"
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	for mission in ["m01_checkout", "m02_dog_days", "m03_prime_time"]:
		Game.replay_mission(mission)
		for i in 90: await get_tree().physics_frame
		var level := get_tree().get_first_node_in_group("level") as Level
		level.player.god_mode = true
		for enemy in level.enemies: enemy.set_physics_process(false)
		for camera in get_tree().get_nodes_in_group("security_cameras"):
			camera.set_physics_process(false)
			if mission == "m03_prime_time" and camera.position.distance_to(Vector2(338,18)) < 1.0:
				if OS.get_environment("SECURITY_FIT_LEGACY_CONTROL") == "1":
					# Actual previous runtime values: this narrow arc was rejected,
					# leaving the authored corner aim and default sweep untouched.
					camera.base_angle = deg_to_rad(45.0)
					camera.sweep = SecurityCamera.SWEEP
				camera._aim = camera.base_angle
				# The north edge has a real furniture collider at (392,24).
				# Watch the open walking lane below it, not a ray through it.
				var corridor_lane: Vector2 = camera.global_position + Vector2(70.0,22.0)
				if not camera.can_see_point(corridor_lane):
					failures += 1
					print("FAIL studio entry camera does not watch its open corridor lane at centre sweep")
			if mission == "m01_checkout" and camera.position.distance_to(Vector2(296,516)) < 1.0:
				if camera.sweep <= deg_to_rad(5.0):
					failures += 1
					print("FAIL narrow motel corridor camera remains frozen")
			var visible := 0
			if mission == "m02_dog_days" and camera.position.distance_to(Vector2(492,119)) < 2.0:
				# The entry itself is deliberately in the under-lens blind zone.
				# The open walking lane three tiles inside must be watched.
				for lane in [Vector2(440,136),Vector2(440,152)]:
					var lane_seen := false
					for phase in 17:
						camera._aim = camera.base_angle + lerpf(-camera.sweep,camera.sweep,phase/16.0)
						lane_seen = lane_seen or camera.can_see_point(lane)
					if not lane_seen:
						failures += 1
						print("FAIL relocated warehouse lens misses entry walking lane ",lane)
					else: print("PASS warehouse entry walking lane ",lane)
			var maximum := 0.0
			for phase in 9:
				camera._aim = camera.base_angle + lerpf(-camera.sweep, camera.sweep, phase / 8.0)
				for offset in [-0.9, 0.0, 0.9]:
					var direction := Vector2.from_angle(camera._aim + offset * SecurityCamera.HALF_FOV)
					for distance in range(34, 112, 8):
						if camera.can_see_point(camera.global_position + direction * distance):
							visible += 1
							maximum = maxf(maximum, distance)
			var ok := visible > 0
			if not ok: failures += 1
			level.set_zone_lights(camera.power_zone, false)
			for frame in 2: await get_tree().physics_frame
			if camera.powered:
				failures += 1
				print("FAIL camera still powered after real zone outage")
			level.set_zone_lights(camera.power_zone, true)
			for frame in 2: await get_tree().physics_frame
			if not camera.powered:
				failures += 1
				print("FAIL camera did not recover real zone power")
			var approach_samples: Array = []
			var rows: Array = level.data.get("map", [])
			# Probe the actual floor next to authored doors, with real occluders.
			# Closed doors remain closed: we measure their approach, not see through them.
			var seen_cells := {}
			for y in rows.size():
				for x in str(rows[y]).length():
					if str(rows[y])[x] != "D": continue
					for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var cell: Vector2i = Vector2i(x,y) + step
						if level.b_ch(cell.x,cell.y) in ["#","D","W","L"," "]: continue
						var point := Vector2(cell)*16.0+Vector2(8,8)
						if camera.global_position.distance_to(point) > SecurityCamera.RANGE: continue
						if seen_cells.has(cell): continue
						seen_cells[cell] = true
						var phases_visible := 0
						for phase in 17:
							camera._aim = camera.base_angle + lerpf(-camera.sweep,camera.sweep,phase/16.0)
							if camera.can_see_point(point): phases_visible += 1
						approach_samples.append({"cell":[cell.x,cell.y],"visible_sweep_samples":phases_visible})
			camera._aim = camera.base_angle
			report.append({"mission":mission,"power_zone":camera.power_zone,"position":[camera.position.x,camera.position.y],"angle_degrees":rad_to_deg(camera.base_angle),"sweep_degrees":rad_to_deg(camera.sweep),"visible_samples":visible,"max_visible_distance":maximum,"nearby_door_approaches":approach_samples})
			print("PASS " if ok else "FAIL ", mission, " camera ", camera.position, " visible=", visible, " max=", maximum)
	var report_path := OS.get_environment("SECURITY_COVERAGE_REPORT")
	if report_path.is_empty(): report_path = "res://build/security_coverage_review.json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Initial real-level lens coverage samples; encounter purpose, counterplay and visual polish not approved", "cameras":report}, "  "))
	print("SECURITY COVERAGE REVIEW: ", failures, " failures / ", report.size(), " cameras")
	SaveManager.data = saved
	SaveManager.save_path = saved_path
	Game.request_quit(1 if failures else 0)
