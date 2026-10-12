class_name M01NativeIceMachine
extends RefCounted

## M01-only visual replacement for intact ice machines.  Each overlay mounts
## on the existing BreakableProp, so the prop's collision, hit points, sound,
## and damaged state stay in the original gameplay implementation.

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/ice_machine_v1/"

class IceMachineVisual extends Sprite2D:
	var machine: BreakableProp

	func _ready() -> void:
		set_process(true)

	func _process(_delta: float) -> void:
		if machine == null or not is_instance_valid(machine):
			queue_free()
			return
		if machine.is_broken:
			# Reveal the legacy broken drawing once damage resolves.  It is still
			# rendered by the BreakableProp that owns the original collision.
			visible = false
			machine.self_modulate.a = 1.0
			set_process(false)

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved", false)): return
	if str(contract.get("source_level_sha256", "")) != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"): return
	var texture := load(DIRECTORY + str(contract.get("file", ""))) as Texture2D
	if texture == null: return
	var placements: Array = []
	for node in level.props_root.get_children():
		if not node is BreakableProp: continue
		var machine := node as BreakableProp
		if machine.kind != "ice" or machine.has_node("NativeM01IceMachine"): continue
		var visual := IceMachineVisual.new()
		visual.name = "NativeM01IceMachine"
		visual.machine = machine
		visual.texture = texture
		# The transparent source includes a narrow crown around the metal body.
		# Fit the visible appliance, rather than that transparent padding, to the
		# unchanged legacy footprint so it stays readable at gameplay scale.
		var used := texture.get_image().get_used_rect().size
		visual.scale = machine.size / Vector2(used)
		visual.z_index = 1
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		visual.light_mask = machine.light_mask
		visual.set_meta("native_m01_ice_machine", true)
		machine.add_child(visual)
		# self_modulate deliberately hides only this legacy intact drawing;
		# children keep their own modulate and collision is never changed.
		machine.self_modulate.a = 0.0
		placements.append({"position": [machine.global_position.x, machine.global_position.y], "footprint_px": [machine.size.x, machine.size.y]})
	Engine.set_meta("m01_ice_machine_review", {"count": placements.size(), "placements": placements, "collision_preserved": true})
