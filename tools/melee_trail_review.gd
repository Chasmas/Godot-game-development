extends Node
func _ready() -> void:
	print("TRAIL REVIEW: setup")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1120, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	for row in 4:
		var kind := "swing" if row < 2 else "thrust"
		for frame in 8:
			var sprite := Sprite2D.new()
			sprite.texture = load("res://build/melee_trail_review/%s/%03d.png" % [kind, frame])
			sprite.position = Vector2(70 + frame * 140, 70 + row * 150)
			# First row of each kind approximates a 24 px attack radius.
			sprite.scale = Vector2.ONE * (72.0 if row % 2 == 0 else 128.0) / 256.0
			viewport.add_child(sprite)
			var label := Label.new()
			label.position = Vector2(12 + frame * 140, 115 + row * 150)
			label.text = "%s %d · %s" % [kind, frame, "game" if row % 2 == 0 else "zoom"]
			viewport.add_child(label)
	print("TRAIL REVIEW: assets loaded")
	for frame in 10:
		await get_tree().process_frame
	print("TRAIL REVIEW: rendered frames")
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://build/melee_trail_review/godot_review.png")
	Game.request_quit()
