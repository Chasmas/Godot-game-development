extends Node2D
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	scale = Vector2.ONE * 2.0
	var bullet_system := BulletSystem.new()
	add_child(bullet_system)
	bullet_system.set_physics_process(false)
	for row in 2:
		for direction in 8:
			var visual := CharacterVisual.new()
			visual.position = Vector2(40 + direction * 50, 90 + row * 110)
			add_child(visual)
			visual.setup("cass")
			visual.set_weapon(DB.weapon(&"pistol"))
			visual.use_run_cycle_for_walk = true
			visual.set_process(false)
			var angle := direction * PI / 4
			visual.set_aim(angle)
			visual.update_move(Vector2.RIGHT * 50, 0.0, row == 1)
			for pose_frame in 20: visual._process_cast(1.0 / 60.0)
			var cast := visual.cast_sprite as CastModel
			assert(cast != null)
			var projected := cast.firearm_projection()
			assert(projected.is_finite() and projected.length() > 0.7)
			assert(absf(angle_difference(visual.weapon_sprite.rotation, projected.angle())) < 0.001)
			for left in [false, true]:
				visual.set_weapon(DB.weapon(&"pistol"), left)
				visual._process_cast(1.0 / 60.0)
				var floor_origin := visual.muzzle_global(left)
				var offset := visual.muzzle_lift(left)
				bullet_system.fire(floor_origin, Vector2.from_angle(angle), DB.weapon(&"pistol"), visual, 0.0, offset)
				var bullet := bullet_system.bullets.back()
				assert((bullet.pos + bullet.lift).distance_to(visual.muzzle_tip_global(left)) < .0001, "Rendered shot must start at the selected barrel tip")
				assert(bullet.vel.normalized().dot(Vector2.from_angle(angle)) > .9999)
				bullet_system.bullets.clear()
	for frame in 8: await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/cass_weapon_projection_review.png")
	print("CASS WEAPON PROJECTION: 16 facing/stance cases and 32 barrel/shot cases passed")
	Game.request_quit(0)


