extends Node2D
var failures := 0
class Target extends Node2D:
	var hits := 0
	var last_weapon: StringName
	func _ready() -> void: add_to_group("damageable")
	func take_damage(info: DamageInfo) -> String:
		hits += 1
		last_weapon = info.weapon_id
		return "killed"
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _ready() -> void:
	var fx := Effects.new()
	add_child(fx)
	var previous_gore: int = Gore.level()
	SaveManager.settings["gore"] = 2
	var wd := DB.weapon(&"chainsaw")
	check(wd != null and wd.is_melee() and not wd.throw_lethal, "Chainsaw registered as non-lethal thrown tool")
	check(SpriteLib.weapon_density("chainsaw") == 4.0, "Blender world art loads at correct density")
	var rare := 0
	for i in 10000:
		var cell := Vector2i(i % 100, i / 100)
		if Smashable.chainsaw_stash("crate", cell, "test_motel"): rare += 1
		assert(Smashable.chainsaw_stash("crate", cell, "test_motel") == Smashable.chainsaw_stash("crate", cell, "test_motel"))
	check(rare > 30 and rare < 130, "Rare crate rate below 1.3%%: %d/10000" % rare)
	for kind in ["chair", "coffin", "vase", "box", "drum"]:
		check(not Smashable.chainsaw_stash(kind, Vector2i.ZERO, "test"), "No saw from " + kind)
	seed(721)
	var cuts := 0
	for i in 100:
		var damage := DamageInfo.make(DamageInfo.Type.MELEE, null, Vector2.ZERO, Vector2.RIGHT, &"chainsaw")
		if Gore.on_kill(Vector2.ZERO, damage, "guard", Vector2.ZERO) in ["arm", "leg"]: cuts += 1
	check(cuts == 100, "Every chainsaw kill severs a limb at full gore")
	cuts = 0
	for i in 200:
		var damage := DamageInfo.make(DamageInfo.Type.MELEE, null, Vector2.ZERO, Vector2.RIGHT, &"machete")
		if not Gore.on_kill(Vector2.ZERO, damage, "guard", Vector2.ZERO).is_empty(): cuts += 1
	check(cuts > 145 and cuts < 190, "Machete high severing probability: %d/200" % cuts)
	SaveManager.settings["gore"] = 1
	var reduced := DamageInfo.make(DamageInfo.Type.MELEE, null, Vector2.ZERO, Vector2.RIGHT, &"chainsaw")
	check(Gore.on_kill(Vector2.ZERO, reduced, "guard", Vector2.ZERO).is_empty(), "Reduced gore suppresses severing")
	var player := Player.new()
	add_child(player)
	player.setup(CharacterData.new())
	player.set_physics_process(false)
	player.slots[0] = WeaponInstance.create(wd)
	player._refresh_weapon()
	check(player.visual._chain_frames.size() == 4, "Four Blender chain phases load")
	player.visual.set_powered_cutting(true)
	player.visual._animate_chain(1.0 / 32.0)
	check(player.visual.weapon_sprite.texture == player.visual._chain_frames[1], "Chain advances while cutting")
	player.visual.set_powered_cutting(false)
	player.visual._animate_chain(1.0 / 32.0)
	check(player.visual.weapon_sprite.texture == player.visual._chain_frames[0], "Chain stops immediately after release")
	player.visual.set_aim(0.0)
	player.visual.update_move(Vector2(0, 118), 0.1)
	player.visual.set_powered_cutting(true)
	player.visual._process_cast(0.1)
	check(absf(player.visual.rig.rotation) < 0.02, "Strafing cut body stays aligned to aim")
	player.visual.set_weapon(DB.weapon(&"pistol"))
	check(not player.visual.powered_cutting, "Swap stops powered cutting")
	player.visual.set_weapon(wd)
	var front := Target.new()
	front.position = Vector2(18, 0)
	add_child(front)
	var side := Target.new()
	side.position = Vector2(0, 18)
	add_child(side)
	await get_tree().physics_frame
	Input.action_press("fire")
	player._chainsaw_attack(player.current())
	check(player.visual._swing_t < 0.0, "Cutting preserves two-hand hold instead of bat swing")
	player._melee_hit(false)
	check(front.hits == 1 and front.last_weapon == &"chainsaw" and side.hits == 0, "Cutting only hits narrow forward contact")
	Input.action_release("fire")
	player._melee_hit(false)
	check(front.hits == 1, "Releasing attack cancels pending saw contact")
	var body := Corpse.new()
	add_child(body)
	body.set_process(false)
	for i in 200: body._process(0.016)
	check(body._bleed_left == 0.0 and not body.is_processing(), "Corpse bleeding ends and processing sleeps")
	SaveManager.settings["gore"] = previous_gore
	print("CHAINSAW REVIEW: ", failures, " failures")
	Audio.shutdown()
	get_tree().quit(1 if failures else 0)
