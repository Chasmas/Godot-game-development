extends Node2D
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("181923"))
	var camera := Camera2D.new()
	camera.position = Vector2(85, 25)
	camera.zoom = Vector2(6, 6)
	add_child(camera)
	var looks := PackedStringArray(["guard", "hunter", "heavy", "biker", "bellhop"])
	if OS.get_environment("AIM_REVIEW_LOOKS") != "": looks = OS.get_environment("AIM_REVIEW_LOOKS").split(",",false)
	var manifest: Array = []
	for page in ceili(looks.size()/5.0):
		var actors: Array[Node] = []
		for i in mini(5, looks.size()-page*5):
			var look: String = looks[page*5+i]
			for row in 2:
				var cast := CastModel.new()
				var source := "res://build/stationary_aim_candidates/%s.glb" % look
				assert(cast.configure(look, source))
				cast.position = Vector2(20+i*32, 20+row*33)
				add_child(cast)
				actors.append(cast)
				cast.play_sample("aim" if row == 0 else "aim_dual", PI/4, .35)
			manifest.append({"look":look,"page":page,"phase":.35,"angle":PI/4})
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image_path := "res://build/stationary_aim_candidates/visual_review_%02d.png" % page
		get_viewport().get_texture().get_image().save_png(image_path)
		if page == 0: get_viewport().get_texture().get_image().save_png("res://build/stationary_aim_candidates/visual_review.png")
		for actor in actors: actor.queue_free()
		await get_tree().process_frame
	var output := FileAccess.open("res://build/stationary_aim_candidates/visual_manifest.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"  "))
	print("STATIONARY AIM VISUAL REVIEW: ",looks.size()*2," authored poses rendered")
	Game.request_quit(0)
