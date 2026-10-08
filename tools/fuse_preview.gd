extends Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("17131e"))
	var on_box := BreakableProp.new()
	on_box.setup("fuse", Vector2(360, 270), "preview")
	on_box.scale = Vector2.ONE * 6.0
	add_child(on_box)

	var off_box := BreakableProp.new()
	off_box.setup("fuse", Vector2(600, 270), "preview")
	off_box.is_broken = true
	off_box.scale = Vector2.ONE * 6.0
	add_child(off_box)

	for spec in [["POWER ON", Vector2(305, 350)], ["DESTROYED", Vector2(535, 350)]]:
		var label := Label.new()
		label.text = spec[0]
		label.position = spec[1]
		label.add_theme_font_size_override("font_size", 20)
		add_child(label)

	for i in 8:
		await get_tree().process_frame
	var output := OS.get_environment("FUSE_PREVIEW_OUT")
	if not output.is_empty():
		var viewport_texture := get_viewport().get_texture() if DisplayServer.get_name() != "headless" else null
		var image := viewport_texture.get_image() if viewport_texture else null
		if image:
			image.save_png(output)
		else:
			push_warning("Fuse preview capture skipped: headless renderer has no visual texture")
	get_tree().quit()
