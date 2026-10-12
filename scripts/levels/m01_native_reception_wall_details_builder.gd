class_name M01NativeReceptionWallDetailsBuilder
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/reception_wall_details_v2/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var decor := level.get_node_or_null("Decor")
	if decor == null or decor.has_node("NativeM01ReceptionWallDetails"): return
	var contract_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not contract_value is Dictionary: return
	var contract := contract_value as Dictionary
	if not bool(contract.get("runtime_approved", false)): return
	var texture := load(DIRECTORY + str(contract.get("file", ""))) as Texture2D
	if texture == null: return
	var details := Sprite2D.new()
	details.name = "NativeM01ReceptionWallDetails"
	details.texture = texture
	details.scale = Vector2.ONE * .40
	details.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	details.light_mask = 0
	details.set_meta("native_m01_reception_wall_details", true)
	# The north lobby wall at cells x54..58, y26; it faces the reception floor.
	details.position = Vector2(904, 425)
	details.z_index = 1
	decor.add_child(details)
