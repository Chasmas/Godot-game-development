class_name M01NativeSunsetPalmsSign
extends RefCounted

## Replaces just the M01 main sign drawing with a Blender plate. The source
## NeonSign remains in place to retain its mounted position, light and flicker.
const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/sunset_palms_sign_v1/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var contract_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not contract_data is Dictionary or not bool(contract_data.get("runtime_approved", false)): return
	var texture := load(DIRECTORY + str(contract_data.get("file", ""))) as Texture2D
	var decor := level.get_node_or_null("Decor") as Node2D
	if texture == null or decor == null: return
	var installed := 0
	for node in decor.get_children():
		if not node is Node2D or str(node.get("text")) != str(contract_data.get("target_text", "SUNSET PALMS")): continue
		if node.has_node("NativeM01SunsetPalmsSign"): continue
		var sign := node as Node2D
		var board_size: Vector2 = sign.call("board_size")
		var mount := str(sign.get("mount"))
		var local_c := Vector2.ZERO
		if mount == "wall_s": local_c = Vector2(0, -board_size.y * .5 - 1.0)
		elif mount == "wall_n": local_c = Vector2(0, board_size.y * .5 + 1.0)
		elif mount == "pylon": local_c = Vector2(0, -12)
		var visual := Sprite2D.new()
		visual.name = "NativeM01SunsetPalmsSign"
		visual.texture = texture
		visual.position = local_c
		visual.scale = Vector2.ONE * (board_size.x / float(texture.get_width()))
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.light_mask = sign.light_mask
		visual.set_meta("native_m01_sunset_palms_sign", true)
		if mount == "pylon":
			_add_pylon_posts(sign, local_c, board_size)
		sign.add_child(visual)
		sign.set("native_visual_override", true)
		sign.queue_redraw()
		installed += 1
	Engine.set_meta("m01_sunset_palms_sign_review", {"count": installed, "collision_added": false})

static func _add_pylon_posts(parent: Node2D, board_center: Vector2, board_size: Vector2) -> void:
	# A roadside sign cannot float. These are only paint lines; the original
	# anchor remains non-solid and the lot stays completely traversable.
	for index in 2:
		var x := lerpf(-board_size.x * .30, board_size.x * .30, float(index))
		var dark := Line2D.new()
		dark.name = "NativeM01SunsetPalmsPylon_%d" % index
		dark.points = PackedVector2Array([board_center + Vector2(x, board_size.y * .43), board_center + Vector2(x, board_size.y * .43 + 38.0)])
		dark.width = 4.0
		dark.default_color = Color("171724")
		dark.z_index = -1
		dark.set_meta("native_m01_sunset_palms_pylon", true)
		parent.add_child(dark)
		var highlight := Line2D.new()
		highlight.name = "NativeM01SunsetPalmsPylonGlow_%d" % index
		highlight.points = PackedVector2Array([board_center + Vector2(x - .65, board_size.y * .43 + 2.0), board_center + Vector2(x - .65, board_size.y * .43 + 35.0)])
		highlight.width = 1.0
		highlight.default_color = Color("58d7ff") if index == 0 else Color("ff4d93")
		highlight.z_index = -1
		parent.add_child(highlight)
