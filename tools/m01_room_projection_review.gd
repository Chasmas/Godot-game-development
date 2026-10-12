extends Node2D

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/staging/guest_room_gameplay_layers_v2/"

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "projection.json"))
	var probes: Dictionary = data.floor_probes_px
	var origin := Vector2(probes.origin[0], probes.origin[1])
	var x := Vector2(probes.x[0], probes.x[1]) - origin
	var y := Vector2(probes.y[0], probes.y[1]) - origin
	var floor_projection := Transform2D(x, y, origin)
	assert(absf(floor_projection.determinant()) > 0.001)
	var inverse := floor_projection.affine_inverse()
	for ix in range(-5, 6):
		for iy in range(-5, 6):
			var point := Vector2(ix * 0.5, iy * 0.5)
			assert((inverse * (floor_projection * point)).distance_to(point) < 0.00001)
	assert(data.pieces.size() == 9)
	var stage := Node2D.new()
	stage.position = Vector2(144, 0)
	stage.scale = Vector2.ONE * 0.70
	add_child(stage)
	var room := Sprite2D.new()
	room.texture = ImageTexture.create_from_image(Image.load_from_file(DIRECTORY + "complete.png"))
	room.centered = false
	stage.add_child(room)
	var cass := CastModel.new()
	assert(cass.configure("cass"))
	stage.add_child(cass)
	cass.scale *= x.length() / 16.0
	cass.position = floor_projection * Vector2(0.9, -0.65)
	cass.play_sample("idle", 0.0)
	for frame in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_room_projection_review.png")
	print("M01 ROOM PROJECTION REVIEW: 121 floor round-trips passed; nine pieces; actor capture saved")
	Game.request_quit(0)
