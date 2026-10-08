extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var saved := SaveManager.data.duplicate(true)
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.campaign_mode = false
	Game.replay_mission("m01_checkout")
	Game.attempts = 2
	for frame in 90: await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	player.visual.set_process(false)
	player.ability.set_process(false)
	player.input_enabled = false
	player.god_mode = true
	player.global_position = Vector2(4000,4000)
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	player.ability.active = true
	player.ability.id = &"spotlight"
	Game.set_slowmo(0.3)
	# Exercise the real controller's publication of the player's time factor.
	player._physics_process(0.0)
	var world_delta := 0.3 / 120.0
	var player_delta := world_delta * player.ability.player_time_mult()
	for attack in ["knife", "heavy_knife", "punch"]:
		player._cancel_melee()
		player._melee_cd = 0.0
		player.aim_dir = Vector2.RIGHT
		player.slots[0] = null if attack == "punch" else WeaponInstance.create(DB.weapon(&"knife"))
		player.slot = 0
		player._refresh_weapon()
		if attack == "punch": player._punch()
		else: player._melee_attack(attack == "heavy_knife")
		var expected := CharacterVisual.PUNCH_CONTACT if attack == "punch" else (0.62 if player.visual._stab else 0.58)
		var contacted := false
		for step in 160:
			player._tick_timers(player_delta)
			player.visual._process(world_delta)
			if player._pending_melee < 0.0:
				var progress := player.visual._punch_t / CharacterVisual.PUNCH_DURATION if attack == "punch" else player.visual._swing_t / player.visual._swing_dur
				print("CONTACT ", attack, " visual phase=", progress, " expected=", expected)
				check(absf(progress-expected) < 0.04, attack + " animation reaches strike when controller resolves contact")
				contacted = true
				break
		check(contacted, attack + " controller resolves contact")
	player._cancel_melee()
	player._dash_cd = 0.0
	player._dash_t = 0.0
	player.stamina = Player.ROLL_COST * 2.0
	player._last_move = Vector2.RIGHT
	player._start_dash()
	check(player._dash_t > 0.0, "real controller starts Spotlight roll")
	var half_steps := roundi(player._dash_total * 0.5 / player_delta)
	for step in half_steps:
		player._movement(Vector2.RIGHT, player_delta)
		player.visual._process(world_delta)
	var roll_phase := 1.0-player._dash_t/player._dash_total
	check(absf(player.visual._roll_t/player.visual._roll_dur-roll_phase) < 0.02, "roll pose keeps pace with roll movement during Spotlight")
	for step in 160:
		if player._dash_t <= 0.0: break
		player._movement(Vector2.RIGHT, player_delta)
		player.visual._process(world_delta)
	check(player.visual._roll_t < 0.0, "roll animation recovers when controller roll ends")
	player.visual.update_move(Vector2(100,0), 0.0)
	player.visual._process(0.0)
	var reference := CharacterVisual.new()
	add_child(reference)
	reference.setup("cass")
	reference.set_process(false)
	reference.set_weapon(null)
	player.slots[0] = null
	player._refresh_weapon()
	player.visual._process(0.0)
	reference.update_move(Vector2(100,0), 0.0)
	reference._process(0.0)
	for frame in 120:
		player.visual._process(world_delta)
		reference._process(player_delta)
	var actual := (player.visual.cast_sprite as CastModel)._player.current_animation_position
	var expected := (reference.cast_sprite as CastModel)._player.current_animation_position
	print("GAIT actual=", actual, " player-clock reference=", expected)
	check(absf(actual-expected) < 0.005, "Cass gait follows player time rather than slowed world time")
	# An ordinary NPC must retain the world clock; the multiplier is per actor.
	reference._process(world_delta)
	var world_advance := (reference.cast_sprite as CastModel)._player.current_animation_position-expected
	check(absf(world_advance-world_delta*100.0/CastModel.NATIVE_SPEED.walk) < 0.002, "ordinary actor retains world animation speed")
	player.ability.force_end()
	player._physics_process(0.0)
	player.visual.update_move(Vector2(100,0), 0.0)
	player.visual._process(world_delta)
	var recovered := (player.visual.cast_sprite as CastModel)._player.current_animation_position-actual
	check(absf(recovered-world_delta*100.0/CastModel.NATIVE_SPEED.walk) < 0.002, "animation returns to world time after Spotlight ends")
	reference.queue_free()
	# The probe starts/stops sounds in one synchronous turn. Let audio player
	# nodes flush their pending playback state before the shutdown drain.
	for frame in 2: await get_tree().process_frame
	SaveManager.data = saved
	print("SPOTLIGHT ANIMATION REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
