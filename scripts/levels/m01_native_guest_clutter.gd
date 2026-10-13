class_name M01NativeGuestClutter
extends RefCounted

const ROOT := "res://assets/art/prerendered/m01_sunset_palms/runtime/guest_clutter_v1/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved",false)) and not Engine.has_meta("review_guest_clutter"): return
	if str(contract.get("source_level_sha256","")) != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"): return
	var decor := level.get_node_or_null("Decor")
	if decor == null: return
	for node in decor.get_children():
		if not node is Sprite2D: continue
		var id := str(node.get_meta("decor_asset_id",""))
		if not contract.variants.has(id) or node.has_node("NativeM01GuestClutter"): continue
		var texture := load(ROOT+str(contract.variants[id])) as Texture2D
		if texture == null: continue
		var visual := Sprite2D.new()
		visual.name="NativeM01GuestClutter"
		visual.texture=texture
		# Cancel the authored Decor scale for the visual only, so each family
		# keeps a consistent footprint; the legacy node keeps its rotation.
		var used := texture.get_image().get_used_rect()
		visual.offset=texture.get_size()*0.5-Vector2(used.get_center())
		visual.scale=Vector2.ONE*float(contract.world_width_px[id])/float(used.size.x)/absf(node.global_scale.x)
		visual.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		visual.light_mask=node.light_mask
		node.add_child(visual)
		node.self_modulate.a=0.0
