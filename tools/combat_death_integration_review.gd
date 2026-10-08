extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var old_gore = SaveManager.settings.get("gore", 2)
	var old_stats = SaveManager.data.stats.duplicate(true)
	var fx := Effects.new()
	add_child(fx)
	for mode in [2, 1, 0]:
		SaveManager.settings["gore"] = mode
		preload("res://scripts/player/sever_meshes.gd").prefetch(["guard"])
		var guard := Enemy.new()
		guard.idle_action = "watch"
		add_child(guard)
		guard.setup(DB.enemy(&"guard"), self, Vector2.RIGHT)
		guard.set_physics_process(false)
		guard.weapon = WeaponInstance.create(DB.weapon(&"pistol"))
		guard.visual.swing()
		guard._windup_t = 0.1
		guard._reload_t = 1.0
		var serial := guard.visual.attack_serial
		var carried := guard.weapon
		var info := DamageInfo.make(DamageInfo.Type.MELEE, null, guard.position, Vector2.RIGHT, &"chainsaw", &"melee")
		info.heavy = true
		check(guard.take_damage(info) == "killed", "chainsaw kills through damage receiver mode=" + str(mode))
		check(guard._windup_t < 0.0 and guard._reload_t == 0.0 and guard.visual._swing_t < 0.0 and guard.visual.attack_serial > serial, "death interrupts actions before corpse/drop mode=" + str(mode))
		guard.take_damage(info)
		var corpses: Array = []
		var drops: Array = []
		for child in get_children():
			if child is Corpse: corpses.append(child)
			if child is WeaponPickup and child.weapon == carried: drops.append(child)
		check(corpses.size() == 1, "one corpse after duplicate damage mode=" + str(mode))
		check(drops.size() == 1, "exact carried weapon drops once mode=" + str(mode))
		if corpses.size() == 1:
			var body: Corpse = corpses[0]
			check((body.missing in ["arm", "leg"]) if mode == 2 else body.missing == "", "cut obeys gore mode=" + str(mode))
			if mode == 2:
				check(body._cast != null and body._cast.get_meta("authored_sever_part", "") == body.missing, "death uses matching authored wound mesh")
		for child in get_children():
			if child != fx: child.queue_free()
		await get_tree().process_frame
		for gib in get_tree().get_nodes_in_group("gibs"): gib.queue_free()
		await get_tree().process_frame
	# Cover armed ordinary archetypes and the sniper subclass as well as guard.
	SaveManager.settings["gore"] = 0
	for identity in [&"guard", &"gunner", &"hunter", &"heavy", &"security", &"bellhop", &"biker", &"welder", &"sniper", &"handler"]:
		var data := DB.enemy(identity)
		if data == null or data.weapon_id == &"":
			continue
		var enemy: Enemy = Handler.new() if identity == &"handler" else Sniper.new() if identity == &"sniper" else Enemy.new()
		enemy.idle_action = "watch"
		add_child(enemy)
		enemy.setup(data, self, Vector2.RIGHT)
		enemy.set_physics_process(false)
		var carried := enemy.weapon
		check(carried != null, "armed archetype carries its configured weapon: " + str(identity))
		var info := DamageInfo.make(DamageInfo.Type.MELEE, null, enemy.position, Vector2.RIGHT, &"chainsaw", &"melee")
		info.heavy = true
		enemy.take_damage(info)
		enemy.take_damage(info)
		var drop_count := 0
		for child in get_children():
			if child is WeaponPickup and child.weapon == carried:
				drop_count += 1
		check(drop_count == 1 and enemy.weapon == null, "configured weapon drops exactly once: " + str(identity))
		if enemy is Handler:
			check(enemy._released and is_instance_valid(enemy.dog) and enemy.dog.is_physics_processing(), "handler death immediately releases the surviving dog")
		for child in get_children():
			if child != fx:
				child.queue_free()
		await get_tree().process_frame
	SaveManager.settings["gore"] = old_gore
	SaveManager.data.stats = old_stats
	print("COMBAT DEATH INTEGRATION: ", failures, " failures")
	Game.request_quit(1 if failures else 0)


