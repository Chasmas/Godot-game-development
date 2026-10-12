extends Node
## Captures the complete title composition at a requested display resolution.
## Example: godot --headless --resolution 3440x1440 --path . res://tools/title_layout_review.tscn

func _ready() -> void:
	await get_tree().process_frame
	var title := preload("res://scenes/ui/title_screen.tscn").instantiate() as Control
	add_child(title)
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var art: Control = title.get("key_art") as Control
	var viewport_size := get_viewport().get_visible_rect().size
	var failures := 0
	if art == null:
		failures += 1
		push_error("Title key art was not created")
	elif art.get_global_rect().get_center().distance_to(viewport_size * 0.5) > 1.0:
		failures += 1
		push_error("Title key art is not centered: %s in %s" % [art.get_global_rect(), viewport_size])
	else:
		print("TITLE LAYOUT: centered art %s in %s" % [art.get_global_rect(), viewport_size])
	var image := get_viewport().get_texture().get_image()
	var output := "res://build/title_layout_%dx%d.png" % [int(viewport_size.x), int(viewport_size.y)]
	image.save_png(output)
	print("TITLE LAYOUT REVIEW: %d failures; %s" % [failures, output])
	Music.stop(0.0)
	get_tree().quit(1 if failures else 0)
