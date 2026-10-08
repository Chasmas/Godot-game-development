extends Node
## Automated smoke test (runs with autoloads):
##   godot --headless --path . res://tools/smoke_test.tscn
## 1) force-compiles every script/resource
## 2) boots mission 1, simulates play: movement, shooting, melee, throwing,
##    pickups, doors, dashing through a window, executions, death + restart,
##    checkpoints, boss, phone, escape, results, save/load round trip.

var failures: Array[String] = []
var step := 0

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	SaveManager.settings["difficulty"] = 1   # normal: one bullet kills
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# detach from "current scene" so scene changes don't free the test runner
	var ph := Node.new()
	ph.name = "Placeholder"
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	if OS.has_environment("SMOKE_MOVEMENT_ONLY"):
		InputSetup.using_gamepad = true
		Game.campaign_mode = false
		Game.start_mission("m01_checkout")
		await frames(60)
		await _movement_collision_regression(_player())
		await _reload_transition_regression(_player())
		await _attack_transition_regression(_player())
		await _shoot_aim_regression(_player())
		print("MOVEMENT COLLISION REGRESSION: ", failures.size(), " failures")
		Game.request_quit(1 if not failures.is_empty() else 0)
		return
	if OS.has_environment("SMOKE_M02_ONLY"):
		InputSetup.using_gamepad = true
		Game.campaign_mode = false
		await _run_m02()
	else:
		_compile_all()
		await _run()
	print("=== SMOKE TEST DONE: %d failures ===" % failures.size())
	for f in failures:
		print("  FAIL: ", f)
	Game.request_quit(1 if not failures.is_empty() else 0)

func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures.append(what)

func _movement_collision_regression(p: Player) -> void:
	var restore := p.global_position
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 200)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(-900, -1000)
	get_tree().current_scene.add_child(wall)
	p.global_position = Vector2(-960, -1000)
	p.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await frames(90)
	check(p.global_position.x < -910, "solid wall stops player")
	check(p.visual._cast_velocity.length() < 1.5, "blocked player animation stops stepping")
	check(p.velocity.length() < 1.5, "wall collision clears blocked movement momentum")
	check(p.is_quiet(), "blocked player produces no walking detection noise")
	var step_clock := p._step_t
	await frames(12)
	check(is_equal_approx(step_clock, p._step_t), "blocked player footstep clock stops")
	p.stamina = Player.STAMINA_MAX
	Input.action_press("sprint")
	await frames(60)
	check(p.stamina > Player.STAMINA_MAX - 0.1, "blocked sprint does not waste stamina")
	Input.action_release("sprint")
	var wall_y := p.global_position.y
	Input.action_press("move_up")
	await frames(24)
	check(p.global_position.y < wall_y - 8.0 and p.velocity.y < -20.0, "wall contact preserves movement along the surface")
	check(absf(p.velocity.x) < 1.5, "diagonal wall movement clears only blocked momentum")
	Input.action_release("move_up")
	await frames(12)
	p._dash_cd = 0.0
	p._pending_melee = 0.1
	p.visual.swing(false, true)
	p._start_dash()
	check(p.visual.is_rolling(), "dodge starts its visual roll")
	check(p._pending_melee < 0.0 and not p.visual.is_swinging(), "dodge cancels an unlanded strike and its pose")
	await frames(12)
	check(not p.is_dashing() and not p.visual.is_rolling(), "wall contact ends motion and visual roll together")
	Input.action_release("move_right")
	p._last_move = Vector2.ZERO
	p._end_dash()
	check(p.velocity == Vector2.ZERO, "roll recovery stops when movement is released")
	p._last_move = Vector2.LEFT
	Input.action_press("sneak")
	p._end_dash()
	check(p.velocity.x < 0.0 and p.velocity.length() <= p.data.move_speed * (p.persona.move_mult if p.persona else 1.0) * 0.45, "roll recovery follows direction and crouch speed")
	Input.action_release("sneak")
	p._last_move = Vector2.ZERO
	wall.queue_free()
	p.global_position = restore
	p.velocity = Vector2.ZERO
	p._dash_cd = 0.0
	p.stamina = Player.STAMINA_MAX
	p._iframes = 0.0
	p.visual.pose_override = "grab"
	p.visual.pose_progress = 0.5
	p._exec_target = null
	p._locked_t = 0.1
	p._process_execution(1.0 / 60.0)
	check(p.visual.pose_override == "" and p._locked_t == 0.0, "interrupted execution releases pose and input")
	await frames(2)

func _attack_transition_regression(p: Player) -> void:
	var saved_slots := p.slots.duplicate()
	var saved_slot := p.slot
	var saved_position := p.global_position
	p.global_position = Vector2(-1300, -1300)
	var bat := WeaponInstance.create(DB.weapon(&"bat"))
	p.slots = [bat, WeaponInstance.create(DB.weapon(&"knife"))]
	p.slot = 0
	p._refresh_weapon()
	p._melee_cd = 0.0
	p._melee_attack(false)
	var serial := p.visual.attack_serial
	p._heavy_ready = true
	p._swap()
	p._swap()
	check(p.current() == bat and p._pending_melee < 0.0, "swapping away and back cannot resurrect a queued strike")
	check(not p.visual.is_swinging() and p.visual.attack_serial > serial and not p._heavy_ready, "weapon swap cancels attack pose, effects and charge")
	p._melee_cd = 0.0
	p._melee_attack(false)
	p._throw_current()
	check(p._pending_melee < 0.0 and not p.visual.is_swinging(), "throwing during windup cancels the old strike")
	check(p.visual._punch_t >= 0.0, "throw gesture is not masked by the old swing")
	p.slots = [null, null]
	p.slot = 0
	p._refresh_weapon()
	p._melee_cd = 0.0
	p._punch()
	var pickup := WeaponPickup.spawn(p.get_parent(), WeaponInstance.create(DB.weapon(&"knife")), p.global_position)
	p._pick_up(pickup)
	check(p._pending_melee < 0.0 and p.visual._punch_t < 0.0, "picking up a weapon cancels an unfinished punch")
	p._cancel_melee()
	p.slots = saved_slots
	p.slot = saved_slot
	p.global_position = saved_position
	p.velocity = Vector2.ZERO
	p._melee_cd = 0.0
	p._refresh_weapon()
	await frames(2)

func _shoot_aim_regression(p: Player) -> void:
	var saved_slots := p.slots.duplicate()
	var saved_slot := p.slot
	var saved_position := p.global_position
	var saved_aim := p.aim_dir
	p.global_position = Vector2(-1400, -1400)
	p.velocity = Vector2.ZERO
	p.slots = [WeaponInstance.create(DB.weapon(&"pistol")), null]
	p.slot = 0
	p._refresh_weapon()
	for heading in [0.0, 90.0, 180.0, 270.0]:
		p.visual.set_aim(deg_to_rad(heading + 90.0))
		p.aim_dir = Vector2.from_angle(deg_to_rad(heading))
		p._fire_cd = 0.0
		var before: int = p.current().ammo
		p._try_shoot(p.current())
		check(p.current().ammo == before - 1, "rapid aim change fires normally")
		check(absf(angle_difference(p.visual.aim_angle, p.aim_dir.angle())) < 0.001, "shot synchronizes visual aim in the firing tick")
	p.slots = saved_slots
	p.slot = saved_slot
	p.global_position = saved_position
	p.aim_dir = saved_aim
	p._fire_cd = 0.0
	p._bloom = 0.0
	p._refresh_weapon()
	await frames(2)

func _reload_transition_regression(p: Player) -> void:
	var saved_slots := p.slots.duplicate()
	var saved_slot := p.slot
	var saved_position := p.global_position
	p.global_position = Vector2(-1200, -1200)
	var gun := WeaponInstance.create(DB.weapon(&"pistol"), false)
	gun.ammo = 2
	gun.reserve = 8
	p.slots = [gun, WeaponInstance.create(DB.weapon(&"knife"))]
	p.slot = 0
	p._refresh_weapon()
	p._start_reload()
	check(p.is_reloading() and p.visual._reload_k >= 0.0, "reload starts with matching visual")
	p._dash_cd = 0.0
	p.stamina = Player.STAMINA_MAX
	p._start_dash()
	check(not p.is_reloading() and p.visual._reload_k < 0.0 and p._reload_weapon == null, "dodge cancels reload and held magazine")
	await frames(int(ceil(gun.data.reload_time * Engine.physics_ticks_per_second)) + 30)
	check(gun.ammo == 2 and gun.reserve == 8, "cancelled reload does not grant ammunition")
	p._start_reload()
	check(p.is_reloading(), "reload restarts after dodge")
	await frames(int(ceil(p._reload_t * Engine.physics_ticks_per_second)) + 15)
	check(gun.ammo == 10 and gun.reserve == 0, "reload can finish normally after dodge")
	gun.ammo = 2
	gun.reserve = 8
	p._start_reload()
	p._swap()
	await frames(int(ceil(gun.data.reload_time * Engine.physics_ticks_per_second)) + 30)
	check(gun.ammo == 2 and gun.reserve == 8 and not p.is_reloading() and p.visual._reload_k < 0.0, "weapon swap cancels reload without ammunition transfer")
	p.slots = saved_slots
	p.slot = saved_slot
	p.global_position = saved_position
	p.velocity = Vector2.ZERO
	p._dash_cd = 0.0
	p.stamina = Player.STAMINA_MAX
	p._reload_weapon = null
	p._refresh_weapon()
	await frames(30)

func _compile_all() -> void:
	print("-- compile")
	for path in _walk("res://scripts") + _walk("res://data"):
		if path.ends_with(".gd") or path.ends_with(".tres"):
			var r: Resource = load(path)
			if r == null or (r is GDScript and not (r as GDScript).can_instantiate()):
				failures.append("compile " + path)
				print("  FAIL compile ", path)

func _walk(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir + "/" + f.trim_suffix(".remap"))
	for sub in d.get_directories():
		out += _walk(dir + "/" + sub)
	return out

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _level() -> Level:
	return get_tree().get_first_node_in_group("level") as Level

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func press(action: String, hold_frames := 2) -> void:
	Input.action_press(action)
	await frames(hold_frames)
	Input.action_release(action)
	await frames(1)

func _run() -> void:
	print("-- title")
	Game.goto_title()
	await frames(40)
	check(get_tree().current_scene != null and get_tree().current_scene.name == "TitleScreen", "title screen loads")
	print("-- cutscene")
	Game.current_cutscene = "apartment_1988"
	Game.change_scene(Game.CUTSCENE_SCENE)
	await frames(260)
	check(Dialogue.active, "dialogue starts in cutscene")
	for i in 40:
		if not Dialogue.active:
			break
		if not Dialogue._choices.is_empty() and not Dialogue.is_typing():
			Dialogue._pick(1)
		else:
			Dialogue._advance()
		await frames(3)
	await frames(30)
	print("-- mission")
	Game.campaign_mode = false
	InputSetup.using_gamepad = true   # headless has no mouse: aim stays where the test puts it
	Game.start_mission("m01_checkout")
	await frames(60)
	var lvl := _level()
	var p := _player()
	check(lvl != null, "level scene built")
	check(p != null and p.alive, "player spawned")
	check(lvl != null and lvl.get_node_or_null("ApprovedM01GroundPlate") != null, "approved M01 ground plate integrated")
	if lvl == null or p == null:
		return
	check(lvl.enemies.size() >= 20, "enemies spawned (%d)" % lvl.enemies.size())
	if lvl.enemies.size() < 20:
		print("DBG ck=", Game.checkpoint_state.keys(), " ids=", lvl.killed_ids.keys(), " attempts=", Game.attempts, " grp=", get_tree().get_nodes_in_group("enemies").size(), " corpses=", get_tree().get_nodes_in_group("corpses").size(), " lvls=", get_tree().get_nodes_in_group("level").size(), " scene=", get_tree().current_scene.name)
	check(lvl.nav != null, "nav grid built")
	check(get_tree().get_nodes_in_group("door").size() > 10, "doors built")
	check(get_tree().get_nodes_in_group("pickups").size() > 8, "weapon pickups placed")
	# Ambient pool props are visual-only, but must still animate in the live
	# scene so the Blender/runtime mood survives the gameplay build.
	var animated_props := lvl.find_children("*", "AnimatedProp", true, false)
	check(animated_props.size() > 0, "animated ambient props built")
	if not animated_props.is_empty():
		var ambient_prop := animated_props[0] as Node2D
		var ambient_start := ambient_prop.position
		await frames(24)
		check(ambient_prop.position.distance_to(ambient_start) > 0.01, "ambient prop bobs in runtime")
	# movement
	var start := p.global_position
	Input.action_press("move_right")
	await frames(40)
	Input.action_release("move_right")
	check(p.global_position.x > start.x + 20.0, "player moves right")
	await _movement_collision_regression(p)
	await _attack_transition_regression(p)
	await _shoot_aim_regression(p)
	# dash
	var before := p.global_position
	await press("dash")
	await frames(20)
	check(p.global_position.distance_to(before) > 10.0, "dash moves the player")
	await frames(60)
	check(not p.is_dashing(), "roll finishes before the next interaction")
	# fists: punch the tutorial guard from behind and execute him
	var guard: Enemy = null
	for e in lvl.enemies:
		if e.enemy_id == "e_3,43":
			guard = e
	check(guard != null, "tutorial guard exists")
	if guard:
		p.global_position = guard.global_position + Vector2(12, 0)
		p.velocity = Vector2.ZERO
		p.aim_dir = Vector2.LEFT
		await frames(2)
		p._punch()
		await frames(24)
		if is_instance_valid(guard):
			print("    punch contact: player alive=", p.alive, " guard=", guard.state_name(), " distance=", p.global_position.distance_to(guard.global_position), " pending=", p._pending_melee, " aim=", p._pending_aim)
		check(not is_instance_valid(guard) or guard.is_downed() or not guard.is_alive(), "punch knocks guard down")
		await frames(2)
		# Follow the knocked-back body before attempting the close interaction.
		if is_instance_valid(guard) and guard.is_downed():
			p.global_position = guard.global_position + Vector2(12, 0)
			p.velocity = Vector2.ZERO
			check(p._find_downed() == guard, "downed guard is reachable for execution")
		p._execute_or_kick()
		await frames(200)
		check(not is_instance_valid(guard) or not guard.is_alive(), "execution kills guard")
		check(Score.score > 0, "score awarded (%d)" % Score.score)
	# pick up a weapon and shoot an enemy
	var gun := DB.weapon(&"pistol")
	p.give_weapon(&"pistol")
	check(p.current() != null and p.current().data.id == &"pistol", "weapon given")
	var target: Enemy = null
	for e in lvl.enemies:
		if is_instance_valid(e) and e.is_alive() and e.data.id == &"guard" and e.enemy_id != "e_3,43":
			target = e
			break
	if target:
		var tgt_pos := target.global_position
		p.global_position = tgt_pos + Vector2(-30, 0)
		await frames(2)
		p.aim_dir = (tgt_pos - p.global_position).normalized()
		var ammo_before := p.current().ammo
		p._try_shoot(p.current())
		await frames(20)
		check(p.current().ammo == ammo_before - 1, "shooting uses ammo")
		check(not is_instance_valid(target) or not target.is_alive(), "bullet kills guard")
	# throw the gun
	var picks_before := get_tree().get_nodes_in_group("pickups").size()
	p._throw_current()
	await frames(5)
	check(get_tree().get_nodes_in_group("pickups").size() == picks_before + 1, "throw spawns a flying pickup")
	check(p.current() == null, "throw empties hands")
	await frames(60)
	var pk := WeaponPickup.nearest(p.global_position, get_tree(), 400.0)
	if pk:
		p.global_position = pk.global_position
		await frames(3)
		p._interact()
		await frames(3)
		check(p.current() != null, "pick up weapon with interact")
	# melee
	p.give_weapon(&"bat")
	var victim: Enemy = null
	for e in lvl.enemies:
		if is_instance_valid(e) and e.is_alive() and e.data.id == &"hunter":
			victim = e
			break
	if victim:
		p.global_position = victim.global_position + Vector2(-14, 0)
		p.aim_dir = Vector2.RIGHT
		await frames(2)
		print("    hunter state before swing: ", victim.state_name(), " dist ", p.global_position.distance_to(victim.global_position))
		p._melee_attack(false)
		await frames(20)
		if is_instance_valid(victim):
			print("    hunter after: ", victim.state_name(), " dist ", p.global_position.distance_to(victim.global_position))
		check(not is_instance_valid(victim) or not victim.is_alive(), "bat kills hunter")
	# door kick
	var door: Door = null
	for d in get_tree().get_nodes_in_group("door"):
		if d is Door and not d.locked:
			door = d
			break
	if door:
		p.global_position = door.global_position + door.leaf_dir().orthogonal() * 12.0 + door.leaf_dir() * 10.0
		await frames(2)
		var ok := door.kick(p.global_position, -door.leaf_dir().orthogonal())
		await frames(20)
		check(ok and absf(door.swing) > 0.3, "kicked door swings (%.2f)" % door.swing)
	# glass
	var glass: GlassWindow = null
	for g in get_tree().get_nodes_in_group("glass"):
		glass = g
		break
	if glass:
		var info := DamageInfo.make(DamageInfo.Type.BALLISTIC, p, glass.global_position, Vector2.UP)
		glass.take_damage(info)
		check(glass.broken, "window breaks when shot")
	# environmental props: authored TVs/arcades/vending machines must react to
	# ballistic damage without changing the level footprint or navigation.
	for prop_kind in ["tv", "arcade", "vending", "plant"]:
		var breakable_prop: BreakableProp = null
		for prop in get_tree().get_nodes_in_group("props"):
			if prop is BreakableProp and prop.kind == prop_kind and not prop.is_broken:
				breakable_prop = prop
				break
		if breakable_prop:
			var pi := DamageInfo.make(DamageInfo.Type.BALLISTIC, p, breakable_prop.global_position, Vector2.UP)
			for _hit in range(5):
				if breakable_prop.is_broken:
					break
				breakable_prop.take_damage(pi)
			check(breakable_prop.is_broken, "%s breaks when shot" % prop_kind)
	# from here the level is live (cameras, snipers, handlers): keep the
	# player alive through the environment checks and the AI run below
	p.god_mode = true
	# explosive
	var tank: ExplosiveTank = null
	for n in get_tree().get_nodes_in_group("damageable"):
		if n is ExplosiveTank:
			tank = n
			break
	if tank:
		var ti := DamageInfo.make(DamageInfo.Type.BALLISTIC, p, tank.global_position, Vector2.UP)
		tank.take_damage(ti)
		await frames(90)
		check(not is_instance_valid(tank), "propane tank explodes")
	# AI reacts to noise
	var listener: Enemy = null
	for e in lvl.enemies:
		if is_instance_valid(e) and e.is_alive() and not e is BossNightManager and not e.is_aware():
			listener = e
			break
	if listener:
		Events.noise.emit(listener.global_position + Vector2(40, 0), 400.0, &"gunshot", p)
		await frames(5)
		check(listener.state in [Enemy.State.INVESTIGATE, Enemy.State.SUSPICIOUS, Enemy.State.SEARCH, Enemy.State.COMBAT], "enemy investigates gunshot (%s)" % listener.state_name())
	# let the AI run a while with the player standing in the corridor
	p.global_position = Vector2(30 * 16, 33 * 16)
	p.god_mode = true
	await frames(360)
	check(p.alive, "god mode survives AI fire")
	p.god_mode = false
	# checkpoint + death + instant restart
	check(not Game.checkpoint_state.is_empty(), "checkpoint saved on entering the motel")
	var killed_before: int = Game.checkpoint_state.get("killed", []).size()
	var dmg := DamageInfo.make(DamageInfo.Type.BALLISTIC, null, p.global_position, Vector2.RIGHT)
	p._iframes = 0.0
	p.take_damage(dmg)
	await frames(5)
	check(not p.alive, "player dies to one bullet")
	await frames(70)
	var t0 := Time.get_ticks_msec()
	Game.restart_level()
	await frames(20)
	lvl = _level()
	p = _player()
	check(lvl != null and p != null and p.alive, "restart rebuilds level (%d ms)" % (Time.get_ticks_msec() - t0))
	check(lvl.killed_ids.size() >= killed_before, "checkpoint keeps dead enemies dead")
	# kill everything except the boss via damage
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and not e is BossNightManager:
			e.take_damage(DamageInfo.make(DamageInfo.Type.EXPLOSIVE, p, e.global_position, Vector2.RIGHT, &"explosion", &"explosion"))
	await frames(10)
	check(lvl.remaining_enemies().is_empty(), "all regular enemies can be killed")
	# boss
	var boss := lvl.boss
	check(boss != null, "boss exists")
	if boss:
		# the lobby is sealed: find the charges, plant them, blow the doors
		check(lvl.breach != null and not lvl.breach.done, "lobby sealed until the breach")
		p.god_mode = true
		p.global_position = lvl.breach._charge_it.global_position
		lvl.breach._charge_it.interact(p)
		await frames(5)
		check(lvl.breach.has_charge and lvl.breach._plant_it.enabled, "picked up the pyro charges")
		p.global_position = lvl.breach._plant_it.global_position + Vector2(0, 120)
		lvl.breach._plant_it.interact(p)
		await frames(5)
		check(lvl.breach.planted or lvl.breach.planting, "charge planted on the lobby doors")
		for i in 900:
			await frames(1)
			if lvl.breach.done:
				break
		check(lvl.breach.done, "the doors blow")
		var all_broken := true
		for d in lvl.breach.doors:
			all_broken = all_broken and d.broken
		check(all_broken and lvl.breach.doors.size() >= 1, "the lobby doors are destroyed")
		await frames(200)
		check(lvl.phase == Level.Phase.BOSS, "the breach starts Harcourt's scene")
		p.global_position = Vector2(58 * 16, 34 * 16)
		# skip intro dialogue
		for i in 20:
			if not Dialogue.active:
				break
			Dialogue._advance()
			await frames(3)
		await frames(10)
		check(boss.active, "boss activated")
		for i in 4:
			boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol"))
			await frames(10)
		check(boss.phase == 2, "boss enters phase 2 at 60%% of his bar (%.1f)" % boss.hp)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and not e is BossNightManager:
				e.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, e.global_position, Vector2.RIGHT, &"pistol"))
		boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol"))
		await frames(10)
		check(boss.is_alive() and not boss._defeated, "Harcourt takes a hit in the dark and keeps coming")
		# the breaker: lights on, he's dazzled, and the next hit takes a big piece
		await frames(220)
		for it in lvl._boss_props:
			if it.kind == "breaker" and it.enabled:
				var hp0: float = boss.hp
				it.interact(p)
				await frames(4)
				check(boss._blind_t > 0.0, "the breaker blinds him")
				boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol"))
				check(boss.hp <= hp0 - 3.0, "a hit while he's blind takes a big piece")
		var n := 0
		while not boss._defeated and n < 20:
			boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol"))
			n += 1
			await frames(4)
		await frames(160)
		check(Dialogue.active, "boss-down dialogue plays")
		for i in 30:
			if not Dialogue.active:
				break
			if not Dialogue._choices.is_empty() and not Dialogue.is_typing():
				Dialogue._pick(1)   # walk away
			else:
				Dialogue._advance()
			await frames(3)
		await frames(20)
		check(SaveManager.get_flag("harcourt_spared", false), "sparing Harcourt sets story flag")
		check(lvl.phase == Level.Phase.PHONE, "phone phase")
		check(lvl.phone.enabled and lvl.phone.ringing, "phone rings when floor is clear")
		lvl.phone.interact(p)
		for i in 30:
			if not Dialogue.active:
				break
			if not Dialogue._choices.is_empty() and not Dialogue.is_typing():
				Dialogue._pick(1)
			else:
				Dialogue._advance()
			await frames(3)
		await frames(10)
		check(lvl.phase == Level.Phase.ESCAPE, "escape phase after phone")
		check(lvl.exit_car.enabled, "car exit enabled")
		lvl.exit_car.interact(p)
		await frames(150)
		check(get_tree().current_scene != null and get_tree().current_scene.name == "Results", "results screen after driving away")
		check(not Game.last_result.is_empty() and Game.last_result.has("rank"), "rank computed: %s" % Game.last_result.get("rank", "?"))
	# save round trip
	SaveManager.save_game()
	var copy: Dictionary = SaveManager.data.duplicate(true)
	SaveManager.data = SaveManager._merge(SaveManager.DEFAULT_SAVE.duplicate(true), SaveManager._load_json(SaveManager.save_path))
	check(SaveManager.data.missions.has("m01_checkout"), "save/load keeps mission result")
	check(SaveManager.data.story.flags.get("harcourt_spared", false) == copy.story.flags.get("harcourt_spared", false), "save/load keeps flags")
	await frames(30)
	await _run_m02()

func _run_m02() -> void:
	print("-- mission 2: dogs, stealth, power, upgrades, gore")
	Game.replay_mission("m02_dog_days")
	await frames(90)
	var lvl := _level()
	var p := _player()
	check(lvl != null and lvl.mission.id == &"m02_dog_days", "mission 2 loads")
	check(lvl == null or lvl.get_node_or_null("ApprovedM01GroundPlate") == null, "M01 ground plate stays out of mission 2")
	if lvl == null or p == null:
		return
	p.god_mode = true
	var dogs: Array = []
	for e in lvl.enemies:
		if e is Dog:
			dogs.append(e)
	check(lvl.enemies.size() >= 15, "m02 enemies spawned (%d)" % lvl.enemies.size())
	check(dogs.size() >= 4, "dogs spawned (%d)" % dogs.size())
	check(lvl.switches.size() >= 3, "light switches built (%d)" % lvl.switches.size())
	var ups := 0
	for u in lvl.upgrade_pickups:
		if is_instance_valid(u) and u.upgrade_id != &"":
			ups += 1
	check(ups >= 3, "upgrade briefcases rolled (%d)" % ups)
	# --- upgrade pickup
	var up0: Node2D = null
	for u in lvl.upgrade_pickups:
		if is_instance_valid(u):
			up0 = u
	if up0 and not "u" in OS.get_environment("SKIP"):
		var uid: StringName = up0.upgrade_id
		up0.interact(p)
		await frames(5)
		check(p.has_upgrade(uid), "picked up upgrade %s" % uid)
	# --- armour soaks a bullet
	if not "k" in OS.get_environment("SKIP"):
		p.god_mode = false
		p.add_upgrade(&"armor", true)
		var shot := DamageInfo.make(DamageInfo.Type.BALLISTIC, lvl.enemies[0], p.global_position, Vector2.RIGHT, &"pistol")
		check(p.take_damage(shot) == "absorbed" and p.alive, "kevlar vest survives a bullet")
		check(p.armor_hits == 0, "vest is used up")
		p.god_mode = true
	# --- lock-on
	var near: Enemy = null
	for e in lvl.enemies:
		if e.enemy_id == "e_20,31":
			near = e
	if near and not "l" in OS.get_environment("SKIP"):
		p.global_position = near.global_position + Vector2(-70, -40)
		await frames(3)
		Input.action_press("lock_on")
		await frames(2)
		Input.action_release("lock_on")
		await frames(2)
		check(p.lock_target != null, "lock-on grabs a target")
		Input.action_press("lock_on")
		await frames(2)
		Input.action_release("lock_on")
		await frames(2)
		check(p.lock_target == null, "tap releases lock")
		Input.action_press("lock_on")
		await frames(70)
		Input.action_release("lock_on")
		await frames(2)
		check(p.lock_target != null, "held acquisition does not toggle off repeatedly")
		Input.action_press("lock_on")
		await frames(2)
		Input.action_release("lock_on")
		await frames(2)
		check(p.lock_target == null, "tap releases reacquired lock")
	# --- stealth takedown from behind
	var victim: Enemy = null
	for e in lvl.enemies:
		if e.enemy_id == "e_58,33":
			victim = e
	if victim and not "t" in OS.get_environment("SKIP"):
		var kills_before: int = Score.stats.silent_kills
		p.global_position = victim.global_position - victim.facing * 14.0
		p.velocity = Vector2.ZERO
		await frames(2)
		check(p._find_takedown() == victim, "unaware guard can be taken down from behind")
		p._melee_cd = 0.0
		p._punch()
		check(p._pending_melee >= 0.0, "strike queued before execution transition")
		p.visual._face_angle = victim.facing.angle() + PI
		victim.visual._face_angle = victim.facing.angle() + PI
		var held_weapon := victim.weapon
		p._execute_or_kick()
		check(not victim.visual.weapon_sprite.visible and not victim.visual.weapon_sprite2.visible and victim.weapon == held_weapon, "paired hold hides weapon while preserving its death drop")
		check(p._pending_melee < 0.0 and p.visual._punch_t < 0.0, "execution cancels unfinished strike")
		check(p.velocity.length() < 0.01, "execution stops inherited attack momentum immediately")
		check(p.prompt == "" and p.prompt_target == null, "execution clears stale interaction prompt")
		var held_at := victim.global_position
		victim._sep = Vector2(120, 40)
		await frames(6)
		check(victim.global_position.distance_to(held_at) < 0.1, "held target stays aligned despite crowd pressure")
		if str(p._exec_move.get("anim", "")) == "grab":
			check(p.visual.pose_override == "grab" and p.visual.pose_progress > 0.0, "rear hold plays authored grab pose")
			check(absf(angle_difference(p.visual.rig.rotation, p.visual.aim_angle)) < 0.001, "Cass immediately faces the paired hold direction")
			if victim.visual.has_clip("held"):
				check(absf(angle_difference(victim.visual.rig.rotation, victim.visual.aim_angle)) < 0.001, "held guard immediately faces the paired hold direction")
		await frames(214)
		check(not is_instance_valid(victim) or not victim.is_alive(), "takedown kills")
		check(Score.stats.silent_kills > kills_before, "takedown counts as silent")
	# --- sleeping dog
	var sleeper: Dog = null
	for d in dogs:
		if is_instance_valid(d) and d.is_asleep():
			sleeper = d
	check(sleeper != null, "a dog is asleep")
	if sleeper:
		p.global_position = sleeper.global_position + Vector2(16, 0)
		p.velocity = Vector2.ZERO
		await frames(10)
		check(sleeper.is_asleep(), "sneaking up doesn't wake the dog")
		p._execute_or_kick()
		await frames(220)
		check(not is_instance_valid(sleeper) or not sleeper.is_alive(), "sleeping dog put down")
	# --- dog attacks and dies to a bullet
	var active_dog: Dog = null
	for d in dogs:
		if is_instance_valid(d) and d.is_alive():
			active_dog = d
	if active_dog:
		p.global_position = active_dog.global_position + Vector2(30, 0)
		await frames(90)
		check(active_dog.is_aware() or not active_dog.is_alive(), "dog notices a player next to it (%s)" % active_dog.state_name())
		active_dog.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, active_dog.global_position, Vector2.RIGHT, &"pistol"))
		await frames(5)
		check(not is_instance_valid(active_dog) or not active_dog.is_alive(), "dog dies to a bullet")
	# --- light switch + darkness
	var sw: Node2D = null
	for s2 in lvl.switches:
		if s2.zone == "warehouse":
			sw = s2
	check(sw != null, "warehouse switch exists")
	if sw:
		p.global_position = sw.global_position + Vector2(0, -8)
		await frames(3)
		sw.interact(p)
		p.global_position = Vector2(8 * 16, 46 * 16)   # wait out on the road
		await frames(5)
		check(lvl.is_zone_dark("warehouse"), "switch kills the warehouse lights")
		check(lvl.light_level_at(Vector2(16 * 16, 7 * 16)) < 0.35, "warehouse is dark")
		check(lvl.darkness.active.has("warehouse"), "darkness overlay active")
		var fixer := false
		for i in 12:
			await frames(120)
			if not lvl.is_zone_dark("warehouse"):
				fixer = true
				break
		check(fixer, "a guard walks over and turns the lights back on")
	# --- fuse box: permanent blackout
	var fuse: Node2D = null
	for pr in get_tree().get_nodes_in_group("props"):
		if pr is BreakableProp and pr.kind == "fuse" and pr.zone == "kennels":
			fuse = pr
	if fuse:
		fuse.interact(p)
		await frames(5)
		check(lvl.dead_zones.has("kennels"), "fuse box kills kennel power for good")
		lvl.set_zone_lights("kennels", true, "enemy")
		check(lvl.is_zone_dark("kennels"), "dead zone can't be switched back on")
	# --- gore: decapitation leaves a head
	var gore_target: Enemy = null
	for e in lvl.enemies:
		if is_instance_valid(e) and e.is_alive() and not e is Dog:
			gore_target = e
	if gore_target:
		var gibs_before := get_tree().get_nodes_in_group("gibs").size()
		gore_target.finish_execution(p, &"machete", "decap")
		await frames(30)
		check(get_tree().get_nodes_in_group("gibs").size() > gibs_before, "decapitation throws a head")
		check(lvl.fx.pools.pools.size() > 0, "blood pools spread")
	# --- clear the yard, then Buck in the kennels -> escape
	for k in 3:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and not e is BossNightManager:
				e.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, e.global_position, Vector2.RIGHT, &"shotgun"))
		await frames(10)
	var buck := lvl.boss as BossKennel
	check(buck != null, "Buck is in the kennels")
	if buck:
		p.global_position = Vector2(40 * 16 + 8, 11 * 16 + 8)
		await frames(40)
		for i in 20:
			if not Dialogue.active:
				break
			Dialogue._advance()
			await frames(3)
		await frames(10)
		check(buck.active, "Buck fights")
		var dogs_before := get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Dog and e.is_alive()).size()
		buck.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, buck.global_position, Vector2.RIGHT, &"pistol"))
		await frames(5)
		check(get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Dog and e.is_alive()).size() > dogs_before, "a hit opens a cage")
		for it in lvl._boss_props:
			if it.kind == "dinner_bell":
				it.interact(p)
				await frames(4)
				check(buck._blind_t > 0.0, "the dinner bell leaves him alone")
		var n2 := 0
		while not buck._defeated and n2 < 20:
			buck.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, buck.global_position, Vector2.RIGHT, &"pistol"))
			n2 += 1
			await frames(4)
		await frames(160)
		check(Dialogue.active and Dialogue._id == "m02_boss_down", "Buck's last scene plays")
		for i in 20:
			if not Dialogue.active:
				break
			if not Dialogue._choices.is_empty():
				Dialogue._pick(1)
			else:
				Dialogue._advance()
			await frames(3)
	await frames(200)
	check(lvl.phase == Level.Phase.ESCAPE, "clearing the yard opens the escape (%d)" % lvl.phase)
	check(lvl.exit_car != null and lvl.exit_car.enabled, "m02 car exit enabled")
	if lvl.exit_car:
		lvl.exit_car.interact(p)
		await frames(150)
		check(get_tree().current_scene != null and get_tree().current_scene.name == "Results", "m02 results screen")

