class_name M01NativeOfficeDesk
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/office_desk_v2/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not parsed is Dictionary: return
	var contract := parsed as Dictionary
	if not bool(contract.get("runtime_approved", false)): return
	var texture := load(DIRECTORY + str(contract.get("file", ""))) as Texture2D
	if texture == null: return
	for node in level.get_tree().get_nodes_in_group("furniture"):
		if not node is Furniture or not level.is_ancestor_of(node): continue
		var desk := node as Furniture
		if desk.kind != "desk" or desk.global_position.distance_to(Vector2(952, 344)) > 2.0: continue
		if desk.has_node("NativeM01OfficeDesk"): return
		var visual := Sprite2D.new()
		visual.name = "NativeM01OfficeDesk"
		visual.texture = texture
		var used := texture.get_image().get_used_rect().size
		visual.scale = desk.rect_size / Vector2(used)
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.light_mask = desk.light_mask
		visual.set_meta("native_m01_office_desk", true)
		visual.z_index = 1
		desk.add_child(visual)
		desk.self_modulate.a = 0.0
		Engine.set_meta("m01_office_desk_review", {"count": 1, "collision_preserved": true, "imagegen_blender": true})
		return
