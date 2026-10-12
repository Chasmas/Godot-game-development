class_name M01NativeArcadeMachines
extends RefCounted
const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/arcade_machine_v1/"
class ArcadeMachineVisual extends Sprite2D:
	var machine: BreakableProp
	func _ready() -> void: set_process(true)
	func _process(_delta: float) -> void:
		if machine == null or not is_instance_valid(machine): queue_free(); return
		if machine.is_broken:
			visible = false; machine.self_modulate.a = 1.0; set_process(false)
static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not parsed is Dictionary or not bool(parsed.get("runtime_approved", false)): return
	var contract: Dictionary = parsed
	if str(contract.get("source_level_sha256", "")) != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"): return
	var texture := load(DIRECTORY + str(contract.get("file", ""))) as Texture2D
	if texture == null: return
	var placements: Array = []
	for node in level.props_root.get_children():
		if not node is BreakableProp: continue
		var machine := node as BreakableProp
		if machine.kind != "arcade" or machine.has_node("NativeM01ArcadeMachine"): continue
		var visual := ArcadeMachineVisual.new(); visual.name = "NativeM01ArcadeMachine"; visual.machine = machine; visual.texture = texture
		var used := texture.get_image().get_used_rect().size
		visual.scale = machine.size / Vector2(used); visual.z_index = 1; visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; visual.light_mask = machine.light_mask
		visual.set_meta("native_m01_arcade_machine", true); machine.add_child(visual); machine.self_modulate.a = 0.0
		placements.append({"position": [machine.global_position.x, machine.global_position.y], "footprint_px": [machine.size.x, machine.size.y]})
	Engine.set_meta("m01_arcade_machine_review", {"count": placements.size(), "placements": placements, "collision_preserved": true})
