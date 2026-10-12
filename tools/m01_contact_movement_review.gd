extends Node
## Focused live-M01 locomotion contract.  It drives the real Player and the
## preserved CastModel manually so input, stance selection, leg heading, stops
## and dodge direction remain covered without relying on mission-camera timing.

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.attempts = 2
	Game.replay_mission("m01_checkout")
	var level: Level
	for frame in 180:
		await get_tree().process_frame
		level = get_tree().get_first_node_in_group("level") as Level
		if level != null and is_instance_valid(level.player):
			break
	assert(level != null and is_instance_valid(level.player))
	Dialogue._end(false)
	get_tree().paused = false
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var player := level.player
	player.set_physics_process(false)
	player.input_enabled = true
	var model := player.visual.cast_sprite as CastModel
	assert(model != null and model._contact_native_speed.size() == 3, "Production Cass must load approved contact cycles")
	var actions := ["move_left", "move_right", "move_up", "move_down"]
	var records: Array = []
	for stance in ["walk", "sneak", "sprint"]:
		for facing in 8:
			for action in actions:
				Input.action_release(action)
			Input.action_release("sneak")
			Input.action_release("sprint")
			if stance != "walk":
				Input.action_press(stance)
			player.position = Vector2(208, 464)
			player.velocity = Vector2.ZERO
			player._travel_velocity = Vector2.ZERO
			player.stamina = Player.STAMINA_MAX
			player._winded = false
			var direction := Vector2.from_angle(facing * PI / 4.0)
			Input.action_press("move_left", maxf(-direction.x, 0.0))
			Input.action_press("move_right", maxf(direction.x, 0.0))
			Input.action_press("move_up", maxf(-direction.y, 0.0))
			Input.action_press("move_down", maxf(direction.y, 0.0))
			var moved := 0.0
			for frame in 60:
				var delta := 1.0 / 120.0
				var before := player.position
				player._movement(direction, delta)
				player.position += player.velocity * delta
				player._travel_velocity = (player.position - before) / delta
				player.visual.update_move(player._travel_velocity, delta, player.sneak_held, player.locomotion_sprinting)
				player.visual.set_aim(fposmod(float(frame) * TAU / 60.0, TAU))
				player.visual._process_cast(delta)
				moved += player.position.distance_to(before)
				if player._travel_velocity.length() >= CharacterVisual.CAST_MOVE_START_SPEED:
					var expected := "sneak" if stance == "sneak" else "run"
					var actual := model.clip.trim_prefix("armed_").trim_prefix("dual_").trim_prefix("melee_")
					assert(actual == expected, "Cass stance must select the correct contact gait")
					var expected_body := model.move_angle
					if absf(angle_difference(expected_body, model._facing_angle)) > deg_to_rad(100.0):
						expected_body += PI
					assert(absf(angle_difference(model._body_angle, expected_body)) < 0.00001, "Cass legs must follow displacement while the torso aims")
			for action in actions:
				Input.action_release(action)
			for frame in 8:
				player._movement(Vector2.ZERO, 1.0 / 120.0)
				assert(player.velocity.is_zero_approx(), "Input release must plant Cass on the first physics tick")
				player.position += player.velocity * (1.0 / 120.0)
				player.visual.update_move(Vector2.ZERO, 1.0 / 120.0)
				player.visual._process_cast(1.0 / 120.0)
			assert(not model.moving, "Stopped Cass must freeze the gait pose")
			assert(moved > 0.1)
			records.append({"stance": stance, "direction": facing, "distance_px": moved, "legs_follow_displacement": true, "release_stopped": true})
	Input.action_release("sneak")
	Input.action_release("sprint")
	player._last_move = Vector2.LEFT
	player.aim_dir = Vector2.UP
	player._dash_cd = 0.0
	player.stamina = Player.STAMINA_MAX
	player._start_dash()
	assert(player._dash_dir.is_equal_approx(Vector2.UP), "Stationary dodge follows aim")
	player._end_dash()
	Input.action_press("move_right")
	player._dash_cd = 0.0
	player._start_dash()
	assert(player._dash_dir.is_equal_approx(Vector2.RIGHT), "Dodge follows current input")
	player._end_dash()
	Input.action_release("move_right")
	var report := FileAccess.open("res://build/m01_contact_movement_review.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_promoted": true, "actual_m01_player_controller": true, "cases": records}, "\t"))
	print("M01 CONTACT MOVEMENT PASSED ", records.size(), " INPUT CASES")
	Game.request_quit(0)
