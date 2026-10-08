extends Node

var failures := 0

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1320, 660)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.size = Vector2(stage.size)
	stage.add_child(background)
	var models: Array = []
	for row in 3:
		for col in 6:
			var model := PropModel.new()
			model.id = "folding_chair"
			model.source_path = "res://build/chair_tip_review/folding_chair.glb"
			model.height_m = 0.9
			model.yaw = -PI * 0.5 - row * PI * 0.5
			model.position = Vector2(110 + col * 220, 175 + row * 220)
			stage.add_child(model)
			model.scale *= 6.0
			if not model.play_animation(&"tip"):
				push_error("Missing authored chair tip")
				get_tree().quit(1)
				return
			model._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			models.append([model, [0.0, 0.1, 0.2, 0.36, 0.45, 0.6][col]])
			var label := Label.new()
			label.position = Vector2(20 + col * 220, 195 + row * 220)
			label.text = "Tip %.2fs · %d°" % [models[-1][1], row * 90]
			stage.add_child(label)
	for frame in 10:
		for pair in models:
			var player: AnimationPlayer = pair[0]._animation_player
			player.seek(pair[1], true)
			player.advance(0.0)
		await get_tree().process_frame
	for pair in models:
		var lowest := INF
		for mesh_node in pair[0]._viewport.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh_node.mesh.get_surface_count():
				var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					lowest = minf(lowest, (mesh_node.global_transform * vertex).y)
		if absf(lowest) > 0.004:
			failures += 1
			push_error("Chair loses ground contact at " + str(pair[1]) + ": " + str(lowest))
		print("chair contact ", pair[1], " lowest=", lowest)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png("res://build/chair_tip_review/godot_review.png")
	print("CHAIR TIP REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
