extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	for loaded in [false, true]:
		for heading in 8:
			var player := Player.new()
			add_child(player)
			player.setup(CharacterData.new())
			player.set_physics_process(false)
			var weapon := WeaponInstance.create(DB.weapon(&"pistol"))
			weapon.dual = true
			weapon.ammo = 3 if loaded else 0
			weapon.ammo2 = 0
			player.slots = [weapon, null]
			player.slot = 0
			player._refresh_weapon()
			player.aim_dir = Vector2.from_angle(heading * PI * .25)
			player.visual.set_aim(heading * PI * .25)
			player.visual._face_angle = heading * PI * .25
			player.visual.cast_sprite._body_init = false
			player.visual._process_cast(0)
			var offhand_tip := player.visual.muzzle_tip_global(true)
			var main_hand := player.visual.hand_global()
			player._throw_current()
			var pickups: Array[WeaponPickup] = []
			for child in get_children():
				if child is WeaponPickup: pickups.append(child)
			check(pickups.size() == (1 if loaded else 2), "correct number of tossed pistols")
			for pickup in pickups:
				var expected := main_hand if pickup.weapon == weapon else offhand_tip
				check(pickup.sprite.global_position.distance_to(expected) < .01, "pistol begins at its drawn hand/barrel")
			check(player.current() == weapon if loaded else player.current() == null, "retains loaded pistol only")
			for frame in 60: await get_tree().physics_frame
			for pickup in pickups:
				check(pickup.sprite.position.length() < .01, "pistol settles to floor")
				pickup.queue_free()
			player.queue_free()
			await get_tree().process_frame
	print("DUAL THROW REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
