extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var old_data := SaveManager.data.duplicate(true)
	var old_gore = SaveManager.settings.get("gore", 2)
	SaveManager.settings["gore"] = 2
	add_child(Effects.new())
	preload("res://scripts/player/sever_meshes.gd").prefetch(["guard"])
	var player := Player.new()
	add_child(player)
	player.setup(CharacterData.new())
	player.set_physics_process(false)
	player.slots = [WeaponInstance.create(DB.weapon(&"chainsaw")), null]
	player.slot = 0
	player._refresh_weapon()
	player.aim_dir = Vector2.RIGHT
	for scenario in ["held", "release", "side"]:
		var enemy := Enemy.new()
		enemy.idle_action = "watch"
		add_child(enemy)
		enemy.setup(DB.enemy(&"guard"), self, Vector2.LEFT)
		enemy.armor_left = 0
		enemy.position = Vector2(20, 0) if scenario != "side" else Vector2(0, 20)
		enemy.set_physics_process(false)
		await get_tree().physics_frame
		await get_tree().physics_frame
		player._melee_cd = 0
		player.input_enabled = true
		Input.action_press("fire")
		player._chainsaw_attack(player.current())
		check(enemy.is_alive(), scenario + " has no windup damage")
		player._tick_timers(player.current().data.melee_windup * 0.5)
		check(enemy.is_alive(), scenario + " stays alive before contact")
		if scenario == "release": Input.action_release("fire")
		player._tick_timers(player.current().data.melee_windup)
		check(not enemy.is_alive() if scenario == "held" else enemy.is_alive(), scenario + " contact obeys held trigger and forward arc")
		Input.action_release("fire")
		if is_instance_valid(enemy): enemy.queue_free()
		await get_tree().process_frame
	SaveManager.data = old_data
	SaveManager.settings["gore"] = old_gore
	print("CHAINSAW CONTACT REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
