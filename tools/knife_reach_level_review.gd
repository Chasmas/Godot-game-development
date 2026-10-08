extends Node
var failures := 0
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
	var p := get_tree().get_first_node_in_group("player") as Player
	p.god_mode = true
	p.input_enabled = false
	p.visual.cast_sprite.free()
	var candidate := CastModel.new()
	if not candidate.configure("cass","res://build/cass_stab_reach/cass.glb"):
		Game.request_quit(1)
		return
	p.visual.cast_sprite = candidate
	p.visual.rig.add_child(candidate)
	p.slots = [WeaponInstance.create(DB.weapon(&"knife")),null]
	p.slot = 0
	p._refresh_weapon()
	for angle in [0.0,45.0,90.0,135.0,180.0,225.0,270.0,315.0]:
		p.aim_dir = Vector2.from_angle(deg_to_rad(angle))
		p._melee_cd = 0.0
		p._melee_attack(false)
		var captured := false
		for frame in 45:
			await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
			if p.visual._swing_t >= 0.0:
				if p.visual._arm.visible or p.visual.cast_sprite.clip != "stab":
					print("Pose failure angle=",angle," frame=",frame," phase=",p.visual._swing_t," clip=",p.visual.cast_sprite.clip," overlay=",p.visual._arm.visible)
					failures += 1
				if not captured and p.visual._swing_t / p.visual._swing_dur >= 0.50 and DisplayServer.get_name() != "headless":
					get_viewport().get_texture().get_image().save_png("res://build/cass_stab_reach/level_%03d.png" % int(angle))
					captured = true
		if p.visual.is_swinging() or p._pending_melee >= 0.0 or (not captured and DisplayServer.get_name() != "headless"):
			print("Completion failure angle=",angle," capture=",captured," swing=",p.visual._swing_t," pending=",p._pending_melee)
			failures += 1
	print("CANDIDATE KNIFE LEVEL REVIEW: ",failures," failures")
	Game.request_quit(1 if failures else 0)
