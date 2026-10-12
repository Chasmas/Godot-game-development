class_name M01NativeWindows
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/window_strip_family_v1/"

static func _frame(contract: Dictionary, window: GlassWindow) -> Dictionary:
	var orientation := "horizontal" if window.size.x >= window.size.y else "vertical"
	var span := roundi(window.size.x if orientation == "horizontal" else window.size.y)
	for candidate in contract.frames:
		if str(candidate.orientation) == orientation and int(candidate.span_px) == span:
			return candidate
	return {}

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "runtime_contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved", false)): return
	var count := 0
	for node in level.props_root.get_children():
		if not node is GlassWindow: continue
		var window := node as GlassWindow
		if window.has_node("NativeM01WindowVisual"): continue
		var frame := _frame(contract, window)
		if frame.is_empty():
			push_warning("M01 native window missing span frame at %s" % window.global_position)
			continue
		var sprite := Sprite2D.new()
		sprite.name = "NativeM01WindowVisual"
		sprite.texture = load(DIRECTORY + str(frame.file)) as Texture2D
		if sprite.texture == null:
			push_warning("M01 native window texture missing: %s" % frame.file)
			continue
		sprite.centered = false
		sprite.offset = -Vector2(frame.floor_anchor_px[0], frame.floor_anchor_px[1])
		sprite.scale = Vector2.ONE * 16.0 / float(frame.pixels_per_metre)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.light_mask = window.light_mask
		window.add_child(sprite)
		window.set_meta("native_window_visual_override", true)
		window.queue_redraw()
		count += 1
	if count != 20:
		push_warning("M01 native windows placed %d/20 reviewed visual frames" % count)
