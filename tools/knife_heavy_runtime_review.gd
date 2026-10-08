extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
		push_error(message)
func current_trail(player: Player) -> Node2D:
	for effect in Effects.get_fx().get_children():
		if effect.get_script() == Effects.MeasuredHeavyKnifeTrail and effect.driver == player.visual and effect.serial == player.visual.attack_serial:
			return effect
	return null
func _ready() -> void:
	Engine.set_meta("skip_tasks",true)
	Engine.set_meta("autoplay",true)
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
	player.god_mode = true
	player.input_enabled = false
	player.slots = [WeaponInstance.create(DB.weapon(&"knife")), WeaponInstance.create(DB.weapon(&"bat"))]
	player.slot = 0
	player._refresh_weapon()
	check(Effects.MeasuredHeavyKnifeTrail.packed_atlas != null, "atlas prewarmed before gameplay")
	for heavy in [true]:
		for heading in [11.25,101.25,191.25,281.25]:
			player.aim_dir = Vector2.from_angle(deg_to_rad(heading))
			player._melee_cd = 0.0
			player._melee_attack(heavy)
			var trail := current_trail(player)
			check(trail != null, "actual controller creates Blender trail")
			var visible_contact := false
			var saved_contact := false
			for frame in 45:
				await get_tree().process_frame
				if is_instance_valid(trail) and trail.visible and player.visual._swing_t / player.visual._swing_dur > 0.5:
					visible_contact = true
					if heading == 101.25 and not saved_contact and DisplayServer.get_name() != "headless":
						saved_contact = true
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png("res://build/melee_trail_review/measured_dense/packed/knife_heavy_runtime_level_contact.png")
			check(visible_contact, "heavy knife strike reaches visible contact")
			check(not is_instance_valid(trail), "actual strike cleans up on recovery")
	player._melee_cd = 0.0
	player._melee_attack(false)
	check(current_trail(player) == null, "light knife does not borrow heavy artwork")
	player._cancel_melee()
	player._melee_cd = 0.0
	player._melee_attack(true)
	var cancelled := current_trail(player)
	player._swap()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(cancelled), "weapon swap cancels runtime trail")
	player._melee_cd = 0.0
	player._melee_attack(true)
	check(current_trail(player) == null, "bat does not borrow knife artwork")
	player._cancel_melee()
	player._swap()
	player._melee_cd = 0.0
	player._dash_cd = 0.0
	player._melee_attack(true)
	cancelled = current_trail(player)
	player._start_dash()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(cancelled), "roll cancels runtime trail")
	print("RUNTIME BLENDER HEAVY KNIFE: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
