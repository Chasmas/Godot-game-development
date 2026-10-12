class_name M01NativeTowelCarts
extends RefCounted

## M01-only visual refresh for the existing housekeeping-cart decor anchors.
## The original Decor sprites keep their authored placement; this adds no
## gameplay body, collision, pathing change or interaction.

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/towel_cart_v1/"

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
		if str(anchor.get_meta("decor_asset_id", "")) != "motel_towel_cart": continue
		if anchor.has_node("NativeM01TowelCart"): continue
		var visual := Sprite2D.new()
		visual.name = "NativeM01TowelCart"
		visual.texture = texture
		visual.scale = Vector2.ONE * float(contract.get("scale", 1.0))
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.z_index = 1
		visual.light_mask = anchor.light_mask
		# Standing Decor anchors use their node position as the prop's foot.
		# Place the refreshed cart on that same baseline; floor anchors retain
		# their authored centre point instead.
		var standing := anchor.offset.y < -0.01
		if standing:
			visual.position.y = -texture.get_height() * visual.scale.y * .5
		visual.set_meta("native_m01_towel_cart", true)
		visual.set_meta("standing_anchor", standing)
		anchor.add_child(visual)
		# self_modulate intentionally applies only to the former source sprite,
		# so its child remains visible while the anchor's transform is retained.
		anchor.self_modulate.a = 0.0
		placements.append({"position": [anchor.global_position.x, anchor.global_position.y], "standing_anchor": standing, "legacy_scale": [anchor.scale.x, anchor.scale.y]})
	Engine.set_meta("m01_towel_cart_review", {"count": placements.size(), "placements": placements, "collision_added": false})