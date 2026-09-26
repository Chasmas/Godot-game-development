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
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	# detach from "current scene" so scene changes don't free the test runner
	var ph := Node.new()
	ph.name = "Placeholder"
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
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
	get_tree().quit(1 if not failures.is_empty() else 0)

func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures.append(what)

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
		if not Dialogue._choices.is_empty() and Dialogue.text_label.visible_characters >= Dialogue._full.length():
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
	if lvl == null or p == null:
		return
	check(lvl.enemies.size() >= 20, "enemies spawned (%d)" % lvl.enemies.size())
	if lvl.enemies.size() < 20:
		print("DBG ck=", Game.checkpoint_state.keys(), " ids=", lvl.killed_ids.keys(), " attempts=", Game.attempts, " grp=", get_tree().get_nodes_in_group("enemies").size(), " corpses=", get_tree().get_nodes_in_group("corpses").size(), " lvls=", get_tree().get_nodes_in_group("level").size(), " scene=", get_tree().current_scene.name)
	check(lvl.nav != null, "nav grid built")
	check(get_tree().get_nodes_in_group("door").size() > 10, "doors built")
	check(get_tree().get_nodes_in_group("pickups").size() > 8, "weapon pickups placed")
	# movement
	var start := p.global_position
	Input.action_press("move_right")
	await frames(40)
	Input.action_release("move_right")
	check(p.global_position.x > start.x + 20.0, "player moves right")
	# dash
	var before := p.global_position
	await press("dash")
	await frames(20)
	check(p.global_position.distance_to(before) > 10.0, "dash moves the player")
	# fists: punch the tutorial guard from behind and execute him
	var guard: Enemy = null
	for e in lvl.enemies:
		if e.enemy_id == "e_3,43":
			guard = e
	check(guard != null, "tutorial guard exists")
	if guard:
		p.global_position = guard.global_position + Vector2(12, 0)
		p.aim_dir = Vector2.LEFT
		await frames(2)
		p._punch()
		await frames(10)
		check(guard.is_downed(), "punch knocks guard down")
		await frames(2)
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
		p.global_position = Vector2(58 * 16, 34 * 16)
		p.god_mode = true
		await frames(30)
		check(lvl.phase == Level.Phase.BOSS, "boss trigger fires")
		# skip intro dialogue
		for i in 20:
			if not Dialogue.active:
				break
			Dialogue._advance()
			await frames(3)
		await frames(10)
		check(boss.active, "boss activated")
		for i in 3:
			boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol"))
			await frames(10)
		check(boss.phase == 2, "boss enters phase 2 after 3 armour hits")
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and not e is BossNightManager:
				e.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, e.global_position, Vector2.RIGHT, &"pistol"))
		boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol"))
		await frames(160)
		check(Dialogue.active, "boss-down dialogue plays")
		for i in 30:
			if not Dialogue.active:
				break
			if not Dialogue._choices.is_empty() and Dialogue.text_label.visible_characters >= Dialogue._full.length():
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
			if not Dialogue._choices.is_empty() and Dialogue.text_label.visible_characters >= Dialogue._full.length():
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
	SaveManager.data = SaveManager._merge(SaveManager.DEFAULT_SAVE.duplicate(true), SaveManager._load_json(SaveManager.SAVE_PATH))
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
		var first = p.lock_target
		Input.action_press("lock_on")
		await frames(2)
		Input.action_release("lock_on")
		await frames(2)
		check(p.lock_target != null and (p.lock_target != first or p._lock_candidates().size() < 2), "tap switches lock target")
		Input.action_press("lock_on")
		await frames(70)
		Input.action_release("lock_on")
		await frames(2)
		check(p.lock_target == null, "hold releases lock")
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
		p._execute_or_kick()
		await frames(220)
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
	# --- clear the yard -> escape
	for k in 3:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive():
				e.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, e.global_position, Vector2.RIGHT, &"shotgun"))
		await frames(10)
	await frames(200)
	check(lvl.phase == Level.Phase.ESCAPE, "clearing the yard opens the escape (%d)" % lvl.phase)
	check(lvl.exit_car != null and lvl.exit_car.enabled, "m02 car exit enabled")
	if lvl.exit_car:
		lvl.exit_car.interact(p)
		await frames(150)
		check(get_tree().current_scene != null and get_tree().current_scene.name == "Results", "m02 results screen")

