extends Node2D
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	var ids := ["guard", "security", "biker", "cass"]
	for row in ids.size():
		for col in 8:
			var corpse := Corpse.new()
			corpse.position = Vector2(80 + col * 100, 90 + row * 125)
			corpse.setup(ids[row], Vector2.from_angle(col * TAU / 8), ids[row] == "cass", "", col * TAU / 8)
			add_child(corpse)
			corpse.set_process(false)
			if corpse._cast:
				corpse._cast.play_sample(corpse._death_clip, 0.0, 0.5)
			var label := Label.new()
			label.text = ids[row] + " " + str(col)
			label.position = corpse.position + Vector2(-30, 40)
			add_child(label)
	for frame in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/corpse_midfall_review.png")
	Game.request_quit(0)

