extends Node2D

func _ready() -> void:
	PostFX.rect.hide()
	var extent := get_viewport_rect().size
	var panel_bounds := Rect2()
	var directory := "res://assets/art/prerendered/m01_sunset_palms/staging/tv_dresser_family_v1/"
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"contract.json"))
	var index := 0
	for frame in contract.frames:
		var image := Image.load_from_file(directory+str(frame.file))
		assert(image!=null)
		var root := Node2D.new();root.position=extent*Vector2(.25+.5*(index%2),.25+.5*floorf(index/2.0))
		root.scale=Vector2.ONE*minf(extent.x/1024,extent.y/1024)*.9;add_child(root)
		var sprite := Sprite2D.new();sprite.texture=ImageTexture.create_from_image(image)
		sprite.centered=false;sprite.position=Vector2(-256,-256);root.add_child(sprite)
		var points := PackedVector2Array()
		for point in frame.screen_polygon_px:
			points.append(Vector2(point[0],point[1]))
		if not points.is_empty():
			assert(index==0 and points.size()==8)
			var panel := Polygon2D.new();panel.polygon=points;panel.position=sprite.position
			var uv := PackedVector2Array()
			var low := points[0];var high := points[0]
			for point in points:low=low.min(point);high=high.max(point)
			for point in points:uv.append((point-low)/(high-low))
			panel_bounds=Rect2(root.position+(low+sprite.position)*root.scale,(high-low)*root.scale)
			panel.uv=uv
			var shader := ShaderMaterial.new();shader.shader=load("res://tools/m01_crt_static.gdshader")
			var source := load("res://assets/art/materials/m01/batch_v1/rubber_albedo.png") as Texture2D
			assert(source!=null)
			shader.set_shader_parameter("grain_source",source)
			shader.set_shader_parameter("strength",1.0)
			panel.material=shader;root.add_child(panel)
		index+=1
	for frame in 12:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var before := get_viewport().get_texture().get_image()
	before.save_png("res://build/m01_crt_layer_review.png")
	for frame in 24:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var after := get_viewport().get_texture().get_image()
	var changed := 0
	var ratio := Vector2(before.get_size())/extent
	var pixel_bounds := Rect2(panel_bounds.position*ratio,panel_bounds.size*ratio).grow(-2)
	for y in range(ceili(pixel_bounds.position.y),floori(pixel_bounds.end.y)):
		for x in range(ceili(pixel_bounds.position.x),floori(pixel_bounds.end.x)):
			var difference := before.get_pixel(x,y)-after.get_pixel(x,y)
			if absf(difference.r)+absf(difference.g)+absf(difference.b)>.001:changed+=1
	assert(changed>10,"CRT overlay must visibly animate")
	print("M01 CRT LAYER REVIEW: four Blender views, visible front panel animates; %d sampled changes" % changed)
	get_tree().quit(0)
