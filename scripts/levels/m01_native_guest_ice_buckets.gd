class_name M01NativeGuestIceBuckets
extends RefCounted

const ROOT := "res://assets/art/prerendered/m01_sunset_palms/runtime/guest_ice_buckets_v1/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved",false)) and not Engine.has_meta("review_guest_ice_buckets"): return
	if str(contract.get("source_level_sha256","")) != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"): return
	var decor := level.get_node_or_null("Decor")
	if decor == null: return
	for node in decor.get_children():
		if not node is Sprite2D: continue
		var id := str(node.get_meta("decor_asset_id",""))
		if not contract.variants.has(id) or node.has_node("NativeM01GuestIceBucket"): continue
		var texture := load(ROOT+str(contract.variants[id])) as Texture2D
		if texture == null: continue
		var visual := Sprite2D.new()
		visual.name="NativeM01GuestIceBucket"
		visual.texture=texture
		# Parent Decor has an authored scale. Cancel it only for the visual so
		# both source variants occupy the same proportionate hospitality footprint.
		var used := texture.get_image().get_used_rect()
		visual.scale=Vector2.ONE*float(contract.world_width_px)/float(used.size.x)/absf(node.global_scale.x)
		visual.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		visual.light_mask=node.light_mask
		node.add_child(visual)
		node.self_modulate.a=0.0
