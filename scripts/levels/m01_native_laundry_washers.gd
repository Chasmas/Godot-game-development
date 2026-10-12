class_name M01NativeLaundryWashers
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/laundry_washer_v2/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not parsed is Dictionary: return
	var contract := parsed as Dictionary
	if not bool(contract.get("runtime_approved", false)): return
	var texture := load(DIRECTORY + str(contract.get("file", ""))) as Texture2D
	if texture == null: return
	var count := 0
	for node in level.get_tree().get_nodes_in_group("furniture"):
		if not node is Furniture or not level.is_ancestor_of(node): continue
		var washer := node as Furniture
		if washer.kind != "washer" or not _is_service_laundry(washer): continue
		if washer.has_node("NativeM01LaundryWasher"): continue
		var visual := Sprite2D.new()
		visual.name = "NativeM01LaundryWasher"
		visual.texture = texture
		# Blender renders transparent breathing room around the appliance.  Fit
		# its actual painted bounds to the old Furniture footprint so the visual
		# has proper volume without widening the physical blocker.
		var used := texture.get_image().get_used_rect().size
		visual.scale = washer.rect_size / Vector2(used)
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.light_mask = washer.light_mask
		visual.set_meta("native_m01_laundry_washer", true)
		visual.z_index = 1
		washer.add_child(visual)
		washer.self_modulate.a = 0.0
		count += 1
	Engine.set_meta("m01_laundry_washer_review", {"count": count, "collision_preserved": true, "imagegen_blender": true})

static func _is_service_laundry(washer: Furniture) -> bool:
	var p := washer.global_position
	# Only the two washer banks in the western service room (cells x5..6, y28/30).
	return p.x >= 72.0 and p.x <= 120.0 and p.y >= 440.0 and p.y <= 504.0
