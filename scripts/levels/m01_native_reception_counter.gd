class_name M01NativeReceptionCounter
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/reception_counter_v2/"

## Replaces just the M01 lobby desk drawing.  The original counter furniture
## is intentionally kept as the authoritative collision and navigation shape.

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not parsed is Dictionary: return
	var contract := parsed as Dictionary
	if not bool(contract.get("runtime_approved", false)): return
	var files: Array = contract.get("files", [])
	if files.is_empty(): return
	var count := 0
	for node in level.get_tree().get_nodes_in_group("furniture"):
		if not node is Furniture or not level.is_ancestor_of(node): continue
		var counter := node as Furniture
		if counter.kind != "counter" or not _is_lobby_counter(counter): continue
		if counter.has_node("NativeM01ReceptionCounter"): continue
		var texture := load(DIRECTORY + str(files[count % files.size()])) as Texture2D
		if texture == null: continue
		var visual := Sprite2D.new()
		visual.name = "NativeM01ReceptionCounter"
		visual.texture = texture
		var used := texture.get_image().get_used_rect().size
		visual.scale = counter.rect_size / Vector2(used)
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# The reception's wide cyan lobby light was blowing out the compact
		# Blender render to solid white. Its baked practical light stays legible
		# and the counter keeps the same collision independently of scene lights.
		visual.light_mask = 0
		visual.set_meta("native_m01_reception_counter", true)
		visual.z_index = 1
		counter.add_child(visual)
		# self_modulate does not affect children.  This hides only the former
		# procedural counter drawing and leaves the StaticBody2D untouched.
		counter.self_modulate.a = 0.0
		count += 1
	Engine.set_meta("m01_reception_counter_review", {"count": count, "collision_preserved": true, "imagegen_blender": true})

static func _is_lobby_counter(counter: Furniture) -> bool:
	# The M01 reception desk is the fixed L at cells x55..61, y28..30.
	# Restricting by both axes prevents unrelated service counters from changing.
	var p := counter.global_position
	return p.x >= 880.0 and p.x <= 1000.0 and p.y >= 440.0 and p.y <= 500.0
