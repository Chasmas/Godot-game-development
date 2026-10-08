extends Node2D
const DIR := "res://assets/art/prerendered/m01_sunset_palms/staging/armchair_runtime_v2/"
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "runtime_contract.json"))
	var camera := Camera2D.new()
	camera.position = Vector2(0, -8)
	camera.zoom = Vector2(8, 8)
	add_child(camera)
	for index in contract.frames.size():
		var frame: Dictionary = contract.frames[index]
		var image := Image.load_from_file(DIR + str(frame.file))
		assert(image.get_size() == Vector2i(512, 512))
		assert(image.get_pixel(0, 0).a == 0)
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.centered = false
		sprite.offset = -Vector2(frame.floor_anchor_px[0], frame.floor_anchor_px[1])
		sprite.scale = Vector2.ONE * float(contract.sprite_scale)
		sprite.position = Vector2(index * 30 - 45, 0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		var floor_pixel := Vector2(frame.floor_anchor_px[0], frame.floor_anchor_px[1])
		assert((sprite.to_global(sprite.offset + floor_pixel) - sprite.position).length() < .001)
	var actor := CharacterVisual.new()
	actor.position = Vector2(80, 0)
	add_child(actor)
	actor.setup("guard")
	for frame in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_armchair_scale_review.png")
	print("M01 ARMCHAIR SCALE REVIEW: four transparent frames, floor anchors and 16 px/metre projection; preview only")
	Game.request_quit(0)
