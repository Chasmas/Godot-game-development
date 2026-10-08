extends Node
const Candidate = preload("res://tools/measured_melee_trail_candidate.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	InputSetup.using_gamepad = true
	Game.campaign_mode = false
	Game.start_mission("m01_checkout")
	Game.attempts = 2
	for frame in 90:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	if not player:
		Game.request_quit(1)
		return
	player.god_mode = true
	player.input_enabled = false
	player.slots = [WeaponInstance.create(DB.weapon(&"bat")), null]
	player.slot = 0
	player._refresh_weapon()
	player.aim_dir = Vector2.from_angle(deg_to_rad(33.75))
	player._melee_cd = 0.0
	player.visual.set_aim(player.aim_dir.angle())
	var trail := Candidate.new()
	Effects.get_fx().add_child(trail)
	trail.configure(player.visual, player.aim_dir.angle())
	trail.set_process(false)
	print("Candidate texture prewarm ms=", trail.prewarm_ms)
	for frame in 3:
		await get_tree().process_frame
	player._melee_attack(false)
	check(absf(angle_difference(player.visual._attack_angle, deg_to_rad(33.75))) < 0.001, "prewarmed heading matches committed strike")
	trail.serial = player.visual.attack_serial
	trail.set_process(true)
	for effect in Effects.get_fx().get_children():
		if effect != trail and (effect is Effects.SlashFX or effect.get_script() == Effects.MeasuredTrail) and effect.driver == player.visual:
			effect.queue_free()
	var captured := false
	for frame in 90:
		await get_tree().process_frame
		if is_instance_valid(trail) and trail.visible and player.visual._swing_t / player.visual._swing_dur >= 0.50 and not captured and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/melee_trail_review/measured_dense/level_playback.png")
			captured = true
	check(captured or DisplayServer.get_name() == "headless", "level strike reaches visible contact capture")
	check(not is_instance_valid(trail), "settled strike cleans up its effect")
	player._dash_cd = 0.0
	player._melee_cd = 0.0
	player._melee_attack(false)
	var cancel_trail := Candidate.new()
	Effects.get_fx().add_child(cancel_trail)
	cancel_trail.configure(player.visual)
	player._start_dash()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(cancel_trail), "roll cancels candidate")
	Game.request_quit(1 if failures else 0)
