class_name M01NativeRugs
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/rug_v1/"

static func build(level: Node, builder: LevelBuilder, layer: Dressing.ClutterLayer) -> void:
	if str(builder.data.get("id",""))!="m01_sunset_palms":return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"runtime_contract.json"))
	if not parsed is Dictionary:return
	var contract: Dictionary=parsed
	if not bool(contract.get("runtime_approved",false)) and not Engine.has_meta("review_m01_runtime_rugs"):return
	if str(contract.get("source_level_sha256",""))!=FileAccess.get_sha256("res://levels/m01_sunset_palms.json"):return
	var textures: Array[Texture2D]=[]
	for frame in contract.frames:
		var texture := load(DIRECTORY+str(frame.file)) as Texture2D
		if texture==null:return
		textures.append(texture)
	var remaining: Array=[];var count := 0
	for item in layer.items:
		if str(item[0])!="rug_big":remaining.append(item);continue
		var position: Vector2=item[1]
		# These room-side offsets are verified against the current grid.  They
		# keep the textile away from cabinet footprints and wall pixels without
		# changing collision or navigation (rugs remain walkable dressing).
		if position==Vector2(352,454):
			position=Vector2(378,480)
			item[2]=PI*.5
		elif position==Vector2(410,128):
			position=Vector2(409,144)
		elif position==Vector2(298,464) or position==Vector2(298,624):
			position.x-=1
		var facing := posmod(roundi(float(item[2])/(PI*.5)),2)
		var frame: Dictionary=contract.frames[facing]
		var sprite := Sprite2D.new();sprite.name="NativeWovenRug_%d" % count
		sprite.position=position;sprite.texture=textures[facing];sprite.centered=false
		sprite.offset=-Vector2(frame.floor_anchor_px[0],frame.floor_anchor_px[1])
		sprite.scale=Vector2.ONE*16/float(contract.pixels_per_metre)
		sprite.z_index=layer.z_index;sprite.light_mask=layer.light_mask
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.set_meta("rug_vertical",facing==1);sprite.set_meta("native_m01_rug",true);level.add_child(sprite);count+=1
	layer.items=remaining
	if count!=int(contract.get("expected_placements",10)):
		push_warning("M01 native rugs placed %d/%d reviewed textiles" % [count,int(contract.get("expected_placements",10))])
	Engine.set_meta("m01_native_runtime_rug_count",count)
