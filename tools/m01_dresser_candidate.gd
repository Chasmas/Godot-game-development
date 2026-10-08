extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/staging/tv_dresser_family_v1/"
const POSITIONS := {
	Vector2(235,72):Vector2(219,88), Vector2(411,136):Vector2(411,128),
	Vector2(1051,72):Vector2(1051,64), Vector2(360,437):Vector2(360,453),
	Vector2(824,491):Vector2(784,491), Vector2(843,632):Vector2(803,648)
}

static func place(level: Node, position: Vector2, rotation: float, contract: Dictionary, index: int) -> void:
	# Blender +90 rotates its front toward screen-right; a cabinet on the
	# east wall must use the 270 view to face the bed to its west.
	var facing := posmod(roundi(rotation/(PI*.5)),4)
	var frame: Dictionary=contract.frames[facing]
	var body := StaticBody2D.new();body.name="CandidateDresser_%d" % index
	body.position=position;body.collision_layer=Layers.LOW;body.collision_mask=0
	var footprint := Vector2(1.62,.5)*16
	if facing%2==1:footprint=Vector2(footprint.y,footprint.x)
	var rectangle := RectangleShape2D.new();rectangle.size=footprint
	var collision := CollisionShape2D.new();collision.shape=rectangle;body.add_child(collision)
	var sprite := Sprite2D.new();sprite.centered=false
	sprite.texture=load(DIRECTORY+str(frame.file)) as Texture2D
	assert(sprite.texture!=null,"Dresser render must be an imported texture")
	sprite.offset=-Vector2(frame.floor_anchor_px[0],frame.floor_anchor_px[1])
	sprite.scale=Vector2.ONE*16/float(contract.pixels_per_metre)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;body.add_child(sprite)
	# Standing cabinet belongs to the shared actor/prop Y-sort layer.
	# A negative layer would force every actor in front regardless of feet.
	body.z_index=0;level.props_root.add_child(body)
	var bounds := Rect2(position-footprint*.5,footprint)
	for y in range(floori(bounds.position.y/16),ceili(bounds.end.y/16)):
		for x in range(floori(bounds.position.x/16),ceili(bounds.end.x/16)):
			level.nav.set_point_solid(Vector2i(x,y),true)
	if not frame.screen_polygon_px.is_empty():
		var points := PackedVector2Array()
		for point in frame.screen_polygon_px:points.append(Vector2(point[0],point[1]))
		var panel := Polygon2D.new();panel.polygon=points
		panel.position=sprite.offset*sprite.scale;panel.scale=sprite.scale
		var low := points[0];var high := points[0]
		for point in points:low=low.min(point);high=high.max(point)
		var uv := PackedVector2Array()
		for point in points:uv.append((point-low)/(high-low))
		panel.uv=uv
		var material := ShaderMaterial.new();material.shader=load("res://tools/m01_crt_static.gdshader")
		material.set_shader_parameter("grain_source",load("res://assets/art/materials/m01/batch_v1/rubber_albedo.png"))
		material.set_shader_parameter("strength",1.0);panel.material=material;body.add_child(panel)

static func build(level: Node, layer: Dressing.ClutterLayer) -> void:
	var nav_helper: RefCounted=load("res://tools/m01_nightstand_candidate.gd").new()
	var before: Dictionary=nav_helper.components(level.nav)
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"contract.json"))
	var remaining: Array=[];var index := 0
	var rug_directory := "res://assets/art/prerendered/m01_sunset_palms/staging/rug_family_v1/"
	var rug_contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(rug_directory+"contract.json"))
	var rug_textures: Array[Texture2D]=[]
	for frame in rug_contract.frames:
		var texture := load(rug_directory+str(frame.file)) as Texture2D
		assert(texture!=null,"Rug render must be an imported texture")
		rug_textures.append(texture)
	var rug_count := 0
	for item in layer.items:
		if str(item[0])=="rug_big":
			# Register soft dressing to the revised bedroom composition.
			# Keep rugs clear of the tall cabinet footprints and at bed side.
			if item[1]==Vector2(352,454):
				item[1]=Vector2(378,480);item[2]=PI*.5
			elif item[1]==Vector2(410,128):item[1]=Vector2(409,144)
			elif item[1]==Vector2(298,464) or item[1]==Vector2(298,624):item[1].x-=1
			var facing := posmod(roundi(float(item[2])/(PI*.5)),2)
			var frame: Dictionary=rug_contract.frames[facing]
			var sprite := Sprite2D.new();sprite.name="CandidateWovenRug_%d" % rug_count
			sprite.set_meta("rug_vertical",facing==1)
			sprite.position=item[1];sprite.centered=false;sprite.texture=rug_textures[facing]
			sprite.offset=-Vector2(frame.floor_anchor_px[0],frame.floor_anchor_px[1])
			sprite.scale=Vector2.ONE*16/float(rug_contract.pixels_per_metre)
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.z_index=layer.z_index
			level.add_child(sprite);rug_count+=1
			continue
		if str(item[0])!="dresser_tv":remaining.append(item);continue
		var original: Vector2=item[1]
		assert(POSITIONS.has(original),"Unknown dresser placement needs review")
		var rotation := PI if original==Vector2(843,632) else float(item[2])
		if original==Vector2(360,437):rotation=0.0
		place(level,POSITIONS[original],rotation,contract,index);index+=1
	layer.items=remaining
	for child in level.get_node("Decor").get_children():
		if child is Sprite2D and child.get_meta("decor_asset_id","")=="hq_motel_dresser":
			assert(child.position.distance_to(Vector2(552,48.64))<.01)
			place(level,Vector2(552,56.64),0.0,contract,index);index+=1;child.hide()
	assert(index==7)
	assert(rug_count==10)
	Engine.set_meta("m01_native_rug_candidate_count",rug_count)
	var after: Dictionary=nav_helper.components(level.nav)
	var mapped: Dictionary={};var removed := 0
	for cell in before:
		if not after.has(cell):removed+=1;continue
		if not mapped.has(before[cell]):mapped[before[cell]]={}
		mapped[before[cell]][after[cell]]=true
	var splits: Array=[]
	for component in mapped:
		if mapped[component].size()>1:splits.append(component)
	Engine.set_meta("m01_dresser_navigation_review",{"passed":splits.is_empty(),"split_components":splits,"newly_reserved_cells":removed})
	assert(splits.is_empty(),"Assembled dresser footprints split an existing route")
