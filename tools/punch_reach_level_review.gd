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
	if "--candidate" in OS.get_cmdline_user_args():
		p.visual.cast_sprite.free()
		var candidate := CastModel.new()
		if not candidate.configure("cass", "res://build/cass_punch_isolated/cass.glb"):
			Game.request_quit(1)
			return
		p.visual.cast_sprite = candidate
		p.visual.rig.add_child(candidate)
	print("PUNCH LEVEL SOURCE: ", "isolated candidate" if "--candidate" in OS.get_cmdline_user_args() else "current production Cass")
	p.slots = [null,null]
	p.slot = 0
	p._refresh_weapon()
	for angle in [0.0,45.0,90.0,135.0,180.0,225.0,270.0,315.0]:
		p.aim_dir = Vector2.from_angle(deg_to_rad(angle))
		p._melee_cd = 0.0
		p.visual._punch_left = OS.get_environment("PUNCH_LEFT") != "1"
		p._punch()
		var captured := false
		for frame in 45:
			await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
			if p.visual._punch_t > 0.0:
				if p.visual._arm.visible or p.visual.cast_sprite.clip != ("punch_left" if p.visual._punch_left else "punch"):
					print("Pose failure angle=",angle," frame=",frame," phase=",p.visual._punch_t," clip=",p.visual.cast_sprite.clip," overlay=",p.visual._arm.visible)
					failures += 1
				if not captured and p.visual._punch_t / CharacterVisual.PUNCH_DURATION >= 0.50 and DisplayServer.get_name() != "headless":
					get_viewport().get_texture().get_image().save_png("res://build/cass_punch_isolated/" + ("left_" if p.visual._punch_left else "right_") + "level_%03d.png" % int(angle))
					var camera := get_viewport().get_camera_2d()
					if camera != null:
						var review_zoom := camera.zoom
						var review_position := camera.global_position
						var review_paused := get_tree().paused
						var review_fx := PostFX.visible
						get_tree().paused = true
						camera.zoom = review_zoom * 3.0
						camera.global_position = p.global_position
						camera.force_update_scroll()
						await RenderingServer.frame_post_draw
						var review_prefix := "res://build/cass_punch_isolated/" + ("left_" if p.visual._punch_left else "right_")
						get_viewport().get_texture().get_image().save_png(review_prefix + "detail_%03d.png" % int(angle))
						PostFX.hide()
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png(review_prefix + "neutral_%03d.png" % int(angle))
						PostFX.visible = review_fx
						camera.zoom = review_zoom
						camera.global_position = review_position
						camera.force_update_scroll()
						get_tree().paused = review_paused
					captured = true
		if p.visual._punch_t >= 0.0 or p._pending_melee >= 0.0 or (not captured and DisplayServer.get_name() != "headless"):
			print("Completion failure angle=",angle," capture=",captured," swing=",p.visual._punch_t," pending=",p._pending_melee)
			failures += 1
	print("PUNCH LEVEL REVIEW: ",failures," failures")
	Game.request_quit(1 if failures else 0)


