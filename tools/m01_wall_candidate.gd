extends RefCounted

static func attach(level: Level, version := "v6") -> void:
	assert(version in ["v3","v4","v5","v6"])
	var directory := "res://assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/"
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"wall_layer_contract_%s.json" % version))
	assert(str(contract.source_level_sha256)==FileAccess.get_sha256("res://levels/m01_sunset_palms.json"),"Wall render must match the current map")
	if version=="v6":
		var audit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"wall_projection_audit_v6.json"))
		assert(bool(audit.passed) and int(audit.opaque_pixels_outside_wall_cells)==0,"Wall projection audit must pass")
		assert(str(audit.source_sha256)==str(contract.source_level_sha256))
	var texture := load(directory+str(contract.image)) as Texture2D
	assert(texture!=null,"Wall plate must be an imported texture")
	var image := texture.get_image()
	assert(image!=null and image.get_size()==Vector2i(2176,1952))
	var root := Node2D.new();root.name="CandidateNativeM01Walls"
	var light_mask := int(OS.get_environment("M01_NATIVE_WALL_LIGHT_MASK"))
	if light_mask==0:light_mask=2
	var count := 0
	for y in range(0,image.get_height(),128):
		for x in range(0,image.get_width(),128):
			var region := Rect2i(x,y,mini(128,image.get_width()-x),mini(128,image.get_height()-y))
			if image.get_region(region).is_invisible():continue
			var tile := Sprite2D.new();tile.texture=texture;tile.region_enabled=true;tile.region_rect=Rect2(region)
			tile.centered=false;tile.position=Vector2(x,y)*.5;tile.scale=Vector2.ONE*.5
			tile.z_index=6;tile.light_mask=light_mask;tile.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			root.add_child(tile);count+=1
	var hidden := 0
	for child in level.walls_root.get_children():
		if child is LevelBuilder.WallChunk:child.hide();hidden+=1
	assert(hidden>0 and count>0)
	level.walls_root.add_child(root)
	Engine.set_meta("m01_combined_wall_review",{"version":version,"tiles":count,"original_chunks_hidden":hidden,"physics_retained":true})
