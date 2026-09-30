extends Node
## Chapter I-C and arcade test (runs with autoloads):
##   godot --headless --path . res://tools/chapter3_test.tscn
## Plays every story scene start to finish, then Mission 3: the Fireman's
## flame spray and fire patches, both phases, the stage going up, the vote,
## the escape and the results. Then an arcade WAVES run (roulette, infinite
## ammo) and every weather preset.
## SHOT_DIR=<folder> also saves screenshots of the fight (needs a window).

var failures: Array[String] = []

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var ph := Node.new()
	ph.name = "Placeholder"
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	var only := OS.get_environment("CH3_ONLY")   # story | m3 | m4 | arcade | weather
	if only == "" or only == "story":
		await _story()
	if only == "" or only == "m3":
		await _mission3()
	if only == "" or only == "m4":
		await _mission4()
	if only == "" or only == "arcade":
		await _arcade()
	if only == "" or only == "weather":
		await _weather()
	print("=== CHAPTER 3 TEST DONE: %d failures ===" % failures.size())
	for f in failures:
		print("  FAIL: ", f)
	get_tree().quit(1 if not failures.is_empty() else 0)

func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		failures.append(what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _shot(name: String) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(2)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))

func _play_dialogue(pick := 0, max_steps := 80) -> int:
	var n := 0
	for i in max_steps:
		if not Dialogue.active:
			break
		if not Dialogue._choices.is_empty() and not Dialogue.is_typing():
			Dialogue._pick(pick)
		else:
			Dialogue._advance()
		n += 1
		await frames(3)
	return n

func _story() -> void:
	print("-- story scenes")
	var camp: Array = Game.campaign
	check(camp.size() >= 11, "campaign has the new chapter (%d beats)" % camp.size())
	for beat in camp:
		if str(beat.type) != "cutscene":
			continue
		var d := Dialogue.load_dialogue(str(beat.id))
		check(not d.is_empty(), "scene %s loads" % beat.id)
		# every shot a line cuts to exists (painted or pixel)
		for k in d.get("nodes", {}):
			var sid := str(d.nodes[k].get("shot", ""))
			if sid != "" and not StoryShot.has_shot(sid):
				check(false, "%s/%s: shot '%s' exists" % [beat.id, k, sid])
		Game.campaign_mode = false
		Game.current_cutscene = str(beat.id)
		Game.change_scene(Game.CUTSCENE_SCENE, false)
		await frames(280)
		check(Dialogue.active, "%s starts" % beat.id)
		var steps := await _play_dialogue(1)
		check(not Dialogue.active and steps > 0, "%s plays through (%d lines)" % [beat.id, steps])
		await frames(40)
	Game.goto_title()
	await frames(30)

func _mission3() -> void:
	print("-- mission 3")
	Game.campaign_mode = false
	Game.modifiers = {}
	Game.start_mission("m03_prime_time")
	await frames(40)
	var lvl := get_tree().get_first_node_in_group("level") as Level
	check(lvl != null, "Stage Nine loads")
	if lvl == null:
		return
	var p := lvl.player
	check(lvl.weather.preset == "santa_ana", "Santa Ana winds on the lot")
	check(lvl.boss is BossFireman, "the Fireman is the boss")
	check(lvl.enemies.size() >= 25, "a full house (%d enemies)" % lvl.enemies.size())
	var kinds := {}
	for e in lvl.enemies:
		kinds[String(e.data.id)] = true
	check(kinds.has("security") and kinds.has("stagehand"), "studio security and stagehands on the floor")
	await _shot("m03_lot")
	# fire hurts: a patch under the player kills (without god mode)
	FireZone.ignite(lvl.actors_root, p.global_position, 14.0, 3.0)
	await frames(40)
	check(not p.alive, "standing in fire kills")
	Game.restart_level()
	await frames(60)
	lvl = get_tree().get_first_node_in_group("level") as Level
	p = lvl.player
	p.god_mode = true
	var boss := lvl.boss as BossFireman
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e != boss:
			e.take_damage(DamageInfo.make(DamageInfo.Type.EXPLOSIVE, p, e.global_position, Vector2.RIGHT, &"explosion", &"explosion"))
	await frames(10)
	p.global_position = Vector2(35 * 16 + 8, 27 * 16 + 8)
	lvl.camera.snap_to_target()
	await frames(30)
	check(lvl.phase == Level.Phase.BOSS, "boss trigger fires on the stage")
	check(Dialogue.active and Dialogue._id == "m03_boss_intro", "Dutch's intro plays")
	await _play_dialogue()
	await frames(20)
	check(boss.active, "the Fireman activates")
	# let him spray: he should wind up and leave fire on the floor
	p.global_position = boss.global_position + Vector2(80, 0)
	var burned := false
	for i in 700:
		await frames(1)
		if not get_tree().get_nodes_in_group("fires").is_empty():
			burned = true
			if i % 60 == 0:
				await _shot("m03_spray")
	check(burned, "the flamethrower sets the floor alight")
	for i in 4:
		boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol"))
		await frames(12)
	check(boss.phase == 2, "phase 2 at 60%% of the bar (%.1f / %.1f)" % [boss.hp, boss.max_hp])
	check(boss.hp > 0.0 and not boss._defeated, "hits take a piece, not the whole bar")
	await frames(120)
	check(get_tree().get_nodes_in_group("fires").size() >= 8, "the stage is on fire")
	await _shot("m03_ablaze")
	check(boss.take_damage(DamageInfo.make(DamageInfo.Type.FIRE, p, boss.global_position, Vector2.RIGHT, &"fire")) == "pass", "fire doesn't hurt him")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e != boss:
			e.take_damage(DamageInfo.make(DamageInfo.Type.EXPLOSIVE, p, e.global_position, Vector2.RIGHT, &"explosion", &"explosion"))
	# the water main: the stage rains, he's soaked and open
	var valve: Interactable = null
	for it in lvl._boss_props:
		if it.kind == "valve":
			valve = it
	check(valve != null and valve.enabled, "the water main is there once the fight starts")
	if valve:
		var before_hp: float = boss.hp
		valve.interact(p)
		await frames(10)
		check(boss._blind_t > 0.0 and boss._doused_t > 0.0, "the sprinklers douse him")
		var hit := DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol")
		hit.lethal = true
		boss.take_damage(hit)
		check(boss.hp < before_hp - 2.5 and boss.hp > 0.0, "a soaked hit takes a big piece (%.1f -> %.1f)" % [before_hp, boss.hp])
	var n := 0
	while not boss._defeated and n < 30:
		var info := DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol")
		info.lethal = true
		boss.take_damage(info)
		n += 1
		await frames(4)
	check(boss._defeated, "the bar runs out")
	await frames(160)
	check(Dialogue.active and Dialogue._id == "m03_boss_down", "the vote plays")
	await _play_dialogue(1)    # cut the feed
	await frames(20)
	check(SaveManager.get_flag("dutch_spared", false), "cutting the feed spares Dutch")
	check(lvl.phase == Level.Phase.ESCAPE, "escape straight after the boss")
	check(lvl.exit_car.enabled, "the car is the way out")
	lvl.exit_car.interact(p)
	await frames(150)
	check(get_tree().current_scene != null and get_tree().current_scene.name == "Results", "results after Stage Nine")

func _mission4() -> void:
	print("-- mission 4 (the dream)")
	Game.campaign_mode = false
	Game.modifiers = {}
	Game.start_mission("m04_sweet_dreams")
	await frames(60)
	var lvl := get_tree().get_first_node_in_group("level") as Level
	check(lvl != null and lvl.nightmare != null, "Villa Estrella loads with its director")
	if lvl == null:
		return
	var p := lvl.player
	p.god_mode = true
	check(lvl.weather.preset == "nightmare" and lvl.weather.rain_color.r > 0.5, "blood rain")
	check(lvl.boss is BossBurningMan, "Tommy is the boss")
	var kinds := {}
	for e in lvl.enemies:
		kinds[String(e.data.id)] = true
	check(kinds.has("zombie") and kinds.has("ghoul") and kinds.has("demon") and kinds.has("cultist") and kinds.has("hellhound"), "the whole guest list (%s)" % ", ".join(kinds.keys()))
	# weapons on the lawn
	var guns := {}
	for pk in get_tree().get_nodes_in_group("pickups"):
		if pk.weapon:
			guns[String(pk.weapon.data.id)] = true
	check(guns.has("boomstick") and guns.has("flamethrower"), "boomstick and flamethrower placed")
	# the graves open when you cross the lawn
	var before := get_tree().get_nodes_in_group("enemies").size()
	p.global_position = Vector2(30 * 16 + 8, 43 * 16 + 8)
	await frames(90)
	check(get_tree().get_nodes_in_group("enemies").size() > before, "the dead climb out of the graves")
	# the flamethrower burns them
	p.give_weapon(&"flamethrower")
	var z := lvl.nightmare.rise(p.global_position + Vector2(40, 0), &"zombie")
	await frames(2)
	var zid := z.get_instance_id()
	p._flame_shot(p.global_position, (z.global_position - p.global_position).normalized())
	var burned := z.state == Enemy.State.DEAD
	await frames(5)
	check(burned and (not is_instance_id_valid(zid) or not (instance_from_id(zid) as Enemy).is_alive()), "the flamethrower kills a zombie (and it stays down)")
	# clear the house, then Tommy
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e != lvl.boss:
			e.take_damage(DamageInfo.make(DamageInfo.Type.EXPLOSIVE, p, e.global_position, Vector2.RIGHT, &"explosion", &"explosion"))
	await frames(20)
	var boss := lvl.boss as BossBurningMan
	p.global_position = Vector2(36 * 16 + 8, 15 * 16 + 8)
	lvl.camera.snap_to_target()
	await frames(40)
	check(Dialogue.active and Dialogue._id == "m04_boss_intro", "Tommy's scene plays")
	await _play_dialogue()
	await frames(20)
	check(boss.active, "Tommy fights")
	var foam := func() -> DamageInfo:
		var d := DamageInfo.make(DamageInfo.Type.MELEE, p, boss.global_position, Vector2.RIGHT, &"extinguisher", &"environment")
		d.from_player = true
		d.set_meta("foam", true)
		return d
	var hp0: float = boss.hp
	for i in 3:
		boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p, boss.global_position, Vector2.RIGHT, &"pistol"))
		await frames(12)
	check(boss.hp > hp0 - 2.0, "bullets barely scorch him")
	boss.take_damage(foam.call())
	await frames(12)
	check(boss.phase == 2, "phase 2 after the first extinguisher")
	await frames(900)
	check(get_tree().get_nodes_in_group("enemies").size() > 1, "he calls up the dead")
	await _shot("m04_boss")
	var tries := 0
	while not boss._defeated and tries < 10:
		boss._blind_t = 0.0
		boss.take_damage(foam.call())
		tries += 1
		await frames(6)
	check(boss._defeated and tries <= 4, "the extinguishers put him out (%d)" % tries)
	await frames(160)
	check(Dialogue.active and Dialogue._id == "m04_boss_down", "the last scene plays")
	await _play_dialogue(1)    # hold him
	await frames(20)
	check(SaveManager.get_flag("held_tommy_dream", false), "holding him is remembered")
	check(lvl.phase == Level.Phase.ESCAPE, "wake up: escape")
	lvl.exit_car.interact(p)
	await frames(150)
	check(get_tree().current_scene != null and get_tree().current_scene.name == "Results", "results after the dream")

func _arcade() -> void:
	print("-- arcade waves")
	Game.replay_mission("m02_dog_days", "cass", {"mode": "waves", "waves": 2, "roulette": true, "infinite_ammo": true, "weather": "snowfall"})
	await frames(60)
	var lvl := get_tree().get_first_node_in_group("level") as Level
	check(lvl != null and lvl.arcade != null, "arcade director runs")
	if lvl == null or lvl.arcade == null:
		return
	check(lvl.weather.preset == "snowfall", "arcade weather override")
	var p := lvl.player
	p.god_mode = true
	check(lvl.enemies.is_empty() and lvl.boss == null, "the placed cast is cleared")
	await frames(420)
	check(lvl.arcade.wave == 1 and lvl.arcade.alive.size() + lvl.arcade._queue.size() > 0, "wave 1 arrives")
	check(p.slots[p.slot] != null, "roulette deals a weapon")
	# keep clearing the floor until the director calls the run
	for i in 900:
		for e in lvl.arcade.alive.duplicate():
			if is_instance_valid(e) and e.is_alive():
				e.take_damage(DamageInfo.make(DamageInfo.Type.EXPLOSIVE, p, e.global_position, Vector2.RIGHT, &"explosion", &"explosion"))
		await frames(10)
		if lvl.arcade._over:
			break
	check(lvl.arcade._over and lvl.arcade.wave == 2, "both waves cleared")
	await frames(520)
	check(get_tree().current_scene != null and get_tree().current_scene.name == "Results", "results after the last wave")
	check(Game.last_result.get("arcade", {}).get("won", false), "run marked as won")
	check(SaveManager.data.leaderboards.has("m02_dog_days@waves"), "waves board recorded")
	Game.goto_title()
	await frames(30)

func _weather() -> void:
	print("-- weather presets")
	for preset in WeatherSystem.PRESETS:
		Game.replay_mission("m01_checkout", "cass", {"weather": preset})
		await frames(140)
		var lvl := get_tree().get_first_node_in_group("level") as Level
		check(lvl != null and lvl.weather.preset == preset, "preset %s" % preset)
		await frames(60)
	Game.goto_title()
	await frames(20)
