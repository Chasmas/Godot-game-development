extends Node2D

const IMAGE_PATH := "res://assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/ground_layer_candidate_v3.png"
const MAP_SIZE := Vector2(1088, 976)
const SCALE := 0.25

func _ready() -> void:
	var image := Image.load_from_file(IMAGE_PATH)
	assert(image != null and image.get_size() == Vector2i(4352, 3904), "M01 v3 ground source must retain authored map extent")
	var compressed := image.duplicate() as Image
	assert(compressed.compress(Image.COMPRESS_S3TC) == OK, "Ground v3 must compress to the runtime S3TC format")
	assert(compressed.get_data_size() < image.get_data_size(), "Runtime texture must be smaller than the raw image")
	var decoded := compressed.duplicate() as Image
	assert(decoded.decompress() == OK, "Runtime S3TC ground must decode for alpha verification")
	decoded.save_png("res://build/m01_ground_v3_s3tc_decoded.png")
	var texture := ImageTexture.create_from_image(compressed)
	assert(texture != null and texture.get_size() == Vector2(image.get_size()), "Compressed runtime texture must match source dimensions")
	var ground := Sprite2D.new()
	ground.name = "GroundLayerV3"
	ground.texture = texture
	ground.centered = false
	ground.scale = Vector2.ONE * SCALE
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.z_index = -9
	add_child(ground)
	assert(ground.get_rect().size * ground.scale == MAP_SIZE, "Ground v3 must map one-to-one to the M01 world")
	var camera := Camera2D.new()
	camera.position = Vector2(470, 260)
	camera.enabled = true
	add_child(camera)
	await get_tree().process_frame
	camera.make_current()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_ground_v3_standalone_exterior.png")
	camera.position = Vector2(248, 464)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_ground_v3_standalone_room101.png")
	ground.hide()
	var baseline := await _measure_frames()
	ground.show()
	var with_ground := await _measure_frames()
	assert(with_ground.median_ms <= baseline.median_ms * 1.10, "Compressed v3 ground must stay within 10% of this renderer baseline")
	var report := {
		"candidate": IMAGE_PATH,
		"source_size_px": [image.get_width(), image.get_height()],
		"world_size_px": [MAP_SIZE.x, MAP_SIZE.y],
		"scale": SCALE,
		"source_bytes": image.get_data_size(),
		"texture_bytes": compressed.get_data_size(),
		"baseline": baseline,
		"with_ground": with_ground,
		"captures": ["res://build/m01_ground_v3_standalone_exterior.png", "res://build/m01_ground_v3_standalone_room101.png"],
		"scope": "isolated Godot renderer review of v3 full-resolution nearest-neighbour ground layer; map alpha coverage is proven separately by audit_m01_ground_projection.py"
	}
	var output := FileAccess.open("res://build/m01_ground_v3_standalone_review.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("M01 GROUND V3 STANDALONE REVIEW PASSED")
	get_tree().quit(0)


func _measure_frames() -> Dictionary:
	var samples: Array[float] = []
	for frame in 60:
		var start := Time.get_ticks_usec()
		await get_tree().process_frame
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	return {"median_ms": samples[30], "p95_ms": samples[57], "samples": samples.size()}
