class_name M01NativeBeds
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/bed_family_v1/"

static func build(level: Level) -> void:
	if level.mission==null or level.mission.id!=&"m01_checkout":return
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"runtime_contract.json"))
	if not contract.get("runtime_approved",false):return
	var frame: Dictionary=contract.frames[1]
	var texture := load(DIRECTORY+str(frame.file)) as Texture2D
	if texture==null:return
	for object in level.get_tree().get_nodes_in_group("furniture"):
		if not object is Furniture or object.kind!="bed" or not level.is_ancestor_of(object):continue
		var body := object as Furniture
		if body.has_node("NativeBlenderBed"):continue
		var footprint := Vector2(2.16,1.72)
		var physical_scale := minf((body.rect_size.x-2)/footprint.x,(body.rect_size.y-2)/footprint.y)
		var sprite := Sprite2D.new();sprite.name="NativeBlenderBed"
		sprite.texture=texture;sprite.centered=false
		sprite.offset=-Vector2(frame.floor_anchor_px[0],frame.floor_anchor_px[1])
		sprite.scale=Vector2.ONE*physical_scale/float(contract.pixels_per_metre)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.light_mask=body.light_mask
		var brightness := clampf(float(contract.get("display_brightness",1.0)),.25,1.0)
		sprite.modulate=Color(brightness,brightness,brightness,1.0)
		body.add_child(sprite)
		# Self modulation suppresses the old drawing without hiding children.
		# The original body, collision layers and navigation remain unchanged.
		body.self_modulate.a=0
