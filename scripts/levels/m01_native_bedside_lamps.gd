class_name M01NativeBedsideLamps
extends RefCounted

## Replaces only the M01 lamp artwork. Existing Decor anchors and their
## LightFixture nodes remain the source of placement and illumination.

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/bedside_lamp_v2/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved", false)): return
	if str(contract.get("source_level_sha256", "")) != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"): return
	var texture := load(DIRECTORY + str(contract.get("file", ""))) as Texture2D
	if texture == null: return
	var decor := level.get_node_or_null("Decor") as Node2D
	if decor == null: return
	var placements: Array = []
	for node in decor.get_children():
		if not node is Sprite2D: continue
		var anchor := node as Sprite2D
		if str(anchor.get_meta("decor_asset_id", "")) != "motel_bedside_lamp": continue
		if anchor.has_node("NativeM01BedsideLamp"): continue
		var visual := Sprite2D.new()
		visual.name = "NativeM01BedsideLamp"
		visual.texture = texture
		visual.scale = Vector2.ONE * float(contract.get("scale", 1.0))
		# Existing standing anchors hold their origin at the lamp's floor/base.
		visual.position.y = -texture.get_height() * visual.scale.y * .5
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.z_index = 1
		visual.light_mask = anchor.light_mask
		visual.set_meta("native_m01_bedside_lamp", true)
		anchor.add_child(visual)
		anchor.self_modulate.a = 0.0
		placements.append({"position": [anchor.global_position.x, anchor.global_position.y], "existing_light_anchor_retained": true})
	Engine.set_meta("m01_bedside_lamp_review", {"count": placements.size(), "placements": placements, "collision_added": false})