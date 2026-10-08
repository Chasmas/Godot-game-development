extends Node
var failures := 0
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	Engine.set_meta("autoplay", true)
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	InputSetup.using_gamepad = true
	Game.campaign_mode = false
	var look := OS.get_environment("HOLD_REVIEW_LOOK")
	if look == "": look = "sniper"
	Game.replay_mission("m02_dog_days" if look == "sniper" else "m01_checkout")
	Game.attempts = 2
	for frame in 90: await get_tree().physics_frame
	var p := get_tree().get_first_node_in_group("player") as Player
	var level := get_tree().get_first_node_in_group("level") as Level
	p.god_mode = true
	p.input_enabled = false
	var target: Enemy
	for e in level.enemies:
		if (look == "sniper" and e.enemy_id == "e_58,33") or (look != "sniper" and e.data.palette == look and e.is_alive()):
			target = e
			break
	assert(target != null)
	var source := OS.get_environment("HOLD_REVIEW_TARGET_MODEL")
	if source != "":
		target.visual.cast_sprite.free()
		var cast := CastModel.new()
		assert(cast.configure(look, source))
		target.visual.cast_sprite = cast
		target.visual.rig.add_child(cast)
	assert(target.visual.has_clip("held"))
	p.slots = [null, null]
	p.slot = 0
	p._refresh_weapon()
	p.global_position = target.global_position - target.facing * 14.0
	p.velocity = Vector2.ZERO
	var camera := get_viewport().get_camera_2d() as CameraController
	assert(camera != null)
	camera.target = p
	camera.snap_to_target()
	camera.set_process(false)
	camera.zoom = Vector2.ONE * 3.0
	for frame in 3: await get_tree().process_frame
	var owned_weapon := target.weapon
	target.begin_execution(p)
	if target.visual.weapon_sprite.visible or target.weapon != owned_weapon: failures += 1
	target.cancel_execution(p)
	if owned_weapon and not target.visual.weapon_sprite.visible: failures += 1
	p._begin_execution(target, true)
	var captured := false
	for frame in 400:
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		if p.visual.pose_override == "grab":
			if target.visual.weapon_sprite.visible or target.visual.weapon_sprite2.visible or target.visual.pose_override != "held" or absf(angle_difference(target.visual.rig.rotation, p.visual.rig.rotation)) > 0.001: failures += 1
			if not captured and p.visual.pose_progress >= 0.50:
				if DisplayServer.get_name() != "headless": get_viewport().get_texture().get_image().save_png("res://build/execution_review/" + look + "_level_contact.png")
				captured = true
		if not is_instance_valid(target) or not target.is_alive(): break
	if not captured or (is_instance_valid(target) and target.is_alive()): failures += 1
	print(look, " HOLD LEVEL REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
