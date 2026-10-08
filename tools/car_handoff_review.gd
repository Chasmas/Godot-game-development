extends Node
var failures := []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _ready() -> void:
	Engine.set_meta("autoplay",true)
	Game.force_intro_calls = OS.get_environment("CAR_REVIEW_CALL") == "1"
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.start_mission("m01_checkout")
	var level: Level = null
	while level == null:
		await get_tree().process_frame
		level = get_tree().get_first_node_in_group("level") as Level
	var car := level.hero_car
	var p := get_tree().get_first_node_in_group("player") as Player
	var done := [false]
	var close_seen := false
	car.arrived.connect(func(): done[0] = true)
	if DisplayServer.get_name() == "headless": car.arrive(p)
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if Dialogue.active: Dialogue._end()
		await get_tree().process_frame
		if not done[0] and Game.force_intro_calls:
			check(get_tree().get_nodes_in_group("intro_call").is_empty(),"Intro call overlaps arrival")
		if not done[0] and is_instance_valid(car._car3d._driver_anim) and car._car3d._driver_anim.assigned_animation == "car_close":
			close_seen = true
			check(not p.visible,"Player visible during door push")
		if done[0]: break
	check(done[0],"Arrival did not finish")
	check(close_seen,"Authored closing clip never played")
	check(absf(car._door) < 0.001,"Door not closed at handoff")
	check(p.visible,"Player invisible after arrival")
	check(p.input_enabled,"Player input not restored")
	check(not is_instance_valid(car._car3d.driver),"Duplicate driver remains")
	check(p.global_position.distance_to(car._car3d.driver_screen_global(1.0)) < 1.0,"Handoff position mismatch")
	if Game.force_intro_calls:
		await get_tree().process_frame
		check(not get_tree().get_nodes_in_group("intro_call").is_empty(),"Intro call missing after arrival")
		for call in get_tree().get_nodes_in_group("intro_call"): call._hang_up()
	var departed := [false]
	car.departed.connect(func(): departed[0] = true)
	car.depart(p)
	deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if Dialogue.active: Dialogue._end()
		await get_tree().process_frame
		if departed[0]: break
	check(departed[0],"Departure did not finish")
	print("CAR HANDOFF REVIEW: ",failures.size()," failures ",failures)
	Game.request_quit(0 if failures.is_empty() else 1)
