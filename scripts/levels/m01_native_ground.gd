class_name M01NativeGround
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/ground_v1/"

static func build(level: Level) -> void:
	if Engine.has_meta("skip_native_m01_ground"): return
	if level.mission == null or level.mission.id != &"m01_checkout": return
	if not FileAccess.file_exists(DIRECTORY+"runtime_contract.json"): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"runtime_contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved",false)): return
	if contract.get("source_level_sha256","") != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"):
		push_warning("M01 ground layout changed; retaining native floor fallback")
		return
	var texture := load(DIRECTORY+str(contract.image)) as Texture2D
	if texture == null or texture.get_size() != Vector2(4352,3904): return
	var root := Node2D.new()
	root.name = "NativeM01Ground"
	var regions: Array = contract.get("tile_regions_px",[[0,0,4352,3904]])
	for region in regions:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(region[0],region[1],region[2],region[3])
		sprite.centered = false
		sprite.position = Vector2(region[0],region[1])*.25
		sprite.scale = Vector2.ONE*.25
		sprite.z_index = -9
		sprite.light_mask = 1
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(sprite)
	level.floor_root.add_child(root)
	for child in level.floor_root.get_children():
		if not child is LevelBuilder.FloorChunk: continue
		var rectangle: Rect2i = child.rect
		for entry in contract.get("fully_covered_legacy_chunks",[]):
			var covered := Rect2i(int(entry[0]),int(entry[1]),int(entry[2]),int(entry[3]))
			if rectangle==covered:
				child.set_meta("native_floor_fully_covered",true)
				child.hide()
				break
