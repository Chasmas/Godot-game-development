extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
		push_error(message)
func current_trail(player: Player) -> Node2D:
	for effect in Effects.get_fx().get_children():
		if effect.get_script() == Effects.MeasuredKnifeTrail and effect.driver == player.visual and effect.serial == player.visual.attack_serial:
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
	print("KNIFE REVIEW RENDERER: ", player.visual.cast_sprite.get_script().resource_path if player.visual.cast_sprite != null else "fallback 2D")
	if player.visual.cast_sprite is CastModel:
		var review_cast := player.visual.cast_sprite as CastModel
		print("KNIFE REVIEW LOOK: ", review_cast._look_id, " actor tint: ", review_cast.modulate, " visual tint: ", player.visual.modulate)
		for review_mesh in review_cast._model.find_children("*", "MeshInstance3D", true, false):
			for review_surface in review_mesh.mesh.get_surface_count():
				var review_material := review_mesh.get_active_material(review_surface) as StandardMaterial3D
				if review_material != null:
					if "--review-no-emission" in OS.get_cmdline_user_args() and review_material.emission_enabled:
						var review_clean := review_material.duplicate() as StandardMaterial3D
						review_clean.emission_enabled = false
						review_mesh.set_surface_override_material(review_surface, review_clean)
					print("KNIFE REVIEW MATERIAL: ", review_mesh.name, " shading: ", review_material.shading_mode, " albedo: ", review_material.albedo_color, " emission: ", review_material.emission_enabled)
	player.god_mode = true
	player.input_enabled = false
	player.slots = [WeaponInstance.create(DB.weapon(&"knife")), WeaponInstance.create(DB.weapon(&"bat"))]
	player.slot = 0
	player._refresh_weapon()
	check(Effects.MeasuredKnifeTrail.packed_atlas != null, "atlas prewarmed before gameplay")
	for heavy in [false]:
		for heading in [11.25,101.25,191.25,281.25]:
			player.aim_dir = Vector2.from_angle(deg_to_rad(heading))
			player._melee_cd = 0.0
			player._melee_attack(heavy)
			var attack_serial := player.visual.attack_serial
			var contact_before := player._pending_melee
			var cooldown_before := player._melee_cd
			player._melee_cd = 0.0
			player._melee_attack(heavy)
			check(player.visual.attack_serial == attack_serial and player._pending_melee == contact_before, "repeated input preserves the pending strike and pose")
			player._melee_cd = cooldown_before
			check(player._melee_cd >= player.visual._swing_dur, "cooldown preserves authored recovery")
			var trail := current_trail(player)
			check(trail != null, "actual controller creates Blender trail")
			var visible_contact := false
			var saved_contact := false
			var recovery_checked := false
			var grip_samples := 0
			var maximum_grip_error := 0.0
			var overlays_hidden := true
			for frame in 45:
				await get_tree().process_frame
				# process_frame resumes before the first visual update; sample posed frames only.
				if player.visual._swing_t > 0.0 and player.visual.cast_sprite is CastModel:
					var native_grip := player.visual.rig.to_global(player.visual.cast_sprite.grip())
					var held_grip := player.visual.weapon_sprite.global_position
					maximum_grip_error = maxf(maximum_grip_error, native_grip.distance_to(held_grip))
					if native_grip.distance_to(held_grip) >= 0.1:
						print("GRIP DIFFERENCE frame= ", frame, " phase= ", player.visual._swing_t / player.visual._swing_dur, " recoil= ", player.visual._gun_kick, " hand= ", native_grip, " weapon= ", held_grip)
					grip_samples += 1
					overlays_hidden = overlays_hidden and not player.visual._arm.visible
				if not recovery_checked and player.visual._swing_t >= 0.0 and player.visual._swing_t / player.visual._swing_dur >= 0.75:
					recovery_checked = true
					var recovery_serial := player.visual.attack_serial
					var recovery_cooldown := player._melee_cd
					player._melee_cd = 0.0
					player._melee_attack(heavy)
					check(player.visual.attack_serial == recovery_serial, "repeated input cannot truncate post-contact recovery")
					player._melee_cd = recovery_cooldown
				if frame % 4 == 0 and frame <= 32 and DisplayServer.get_name() != "headless":
					var review_camera := get_viewport().get_camera_2d()
					if review_camera != null:
						var review_zoom := review_camera.zoom
						var review_position := review_camera.global_position
						var review_paused := get_tree().paused
						var review_fx := PostFX.visible
						get_tree().paused = true
						PostFX.hide()
						review_camera.zoom = review_zoom * 3.0
						review_camera.global_position = player.global_position
						review_camera.force_update_scroll()
						await RenderingServer.frame_post_draw
						var review_dir := "res://build/melee_trail_review/runtime_sequence"
						DirAccess.make_dir_recursive_absolute(review_dir)
						get_viewport().get_texture().get_image().save_png("%s/heading_%03d_frame_%02d.png" % [review_dir, int(heading), frame])
						review_camera.zoom = review_zoom
						review_camera.global_position = review_position
						review_camera.force_update_scroll()
						PostFX.visible = review_fx
						get_tree().paused = review_paused
				if is_instance_valid(trail) and trail.visible and player.visual._swing_t / player.visual._swing_dur > 0.5:
					visible_contact = true
					if heading == 101.25 and not saved_contact and DisplayServer.get_name() != "headless":
						saved_contact = true
						var paused_before := get_tree().paused
						get_tree().paused = true
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png("res://build/melee_trail_review/measured_dense/packed/knife_runtime_level_contact.png")
						var camera := get_viewport().get_camera_2d()
						if camera != null:
							var zoom_before := camera.zoom
							var position_before := camera.global_position
							camera.zoom = zoom_before * 3.0
							camera.global_position = player.global_position
							camera.force_update_scroll()
							await RenderingServer.frame_post_draw
							get_viewport().get_texture().get_image().save_png("res://build/melee_trail_review/measured_dense/packed/knife_runtime_contact_detail.png")
							var postfx_visible := PostFX.visible
							PostFX.hide()
							await RenderingServer.frame_post_draw
							get_viewport().get_texture().get_image().save_png("res://build/melee_trail_review/measured_dense/packed/knife_runtime_contact_no_postfx.png")
							PostFX.visible = postfx_visible
							camera.zoom = zoom_before
							camera.global_position = position_before
							camera.force_update_scroll()
						get_tree().paused = paused_before
			check(grip_samples >= 3 and maximum_grip_error < 0.1, "weapon grip follows native hand throughout strike")
			check(overlays_hidden, "native strike never adds a fallback arm overlay")
			print("KNIFE GRIP AUDIT heading= ", heading, " samples= ", grip_samples, " max_error_px= ", maximum_grip_error)
			check(recovery_checked, "post-contact recovery was exercised")
			check(visible_contact, "light knife strike reaches visible contact")
			check(not is_instance_valid(trail), "actual strike cleans up on recovery")
	player._melee_cd = 0.0
	player._melee_attack(true)
	check(current_trail(player) == null, "heavy knife does not borrow stab artwork")
	player._cancel_melee()
	player._melee_cd = 0.0
	player._melee_attack(false)
	var cancelled := current_trail(player)
	player._swap()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(cancelled), "weapon swap cancels runtime trail")
	player._melee_cd = 0.0
	player._melee_attack(false)
	check(current_trail(player) == null, "bat does not borrow knife artwork")
	player._cancel_melee()
	player._swap()
	player._melee_cd = 0.0
	player._dash_cd = 0.0
	player._melee_attack(false)
	cancelled = current_trail(player)
	player._start_dash()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(cancelled), "roll cancels runtime trail")
	print("RUNTIME BLENDER KNIFE: ", failures, " failures")
	Game.request_quit(1 if failures else 0)









