extends Node2D


class KitProp extends Node2D:
	var kind := ""

	func _init(p_kind: String, p_position: Vector2) -> void:
		kind = p_kind
		position = p_position
		scale = Vector2.ONE * 5.0

	func _draw() -> void:
		RoomKits.draw(self, kind, 0)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("17131e"))

	var cage := Furniture.new()
	cage.setup("cage", Rect2(380, 190, 200, 150))
	add_child(cage)

	add_child(KitProp.new("dog_bed", Vector2(445, 265)))
	add_child(KitProp.new("bowl", Vector2(520, 260)))

	var label := Label.new()
	label.text = "PIXELLAB KENNEL KIT — RUNTIME SCALE"
	label.position = Vector2(315, 390)
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)

	for i in 8:
		await get_tree().process_frame
	var output := OS.get_environment("KENNEL_PREVIEW_OUT")
	if not output.is_empty():
		var texture := get_viewport().get_texture() if DisplayServer.get_name() != "headless" else null
		var image := texture.get_image() if texture else null
		if image:
			image.save_png(output)
		else:
			push_warning("Kennel preview capture skipped: headless renderer has no visual texture")
	get_tree().quit()
