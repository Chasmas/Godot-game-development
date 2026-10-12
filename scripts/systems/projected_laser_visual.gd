extends MeshInstance3D
## Alternate presentation of the existing 2D physical laser ray.
## Caller must supply an actual 3D barrel tip. No guessed attachment or physics.
var endpoints := PackedVector3Array()

func _init() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(1,.12,.18,.8)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test=false
	material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_from_beam(beam: Dictionary, barrel_tip_world: Vector3, pixels_per_metre: float = 16.0) -> void:
	assert(pixels_per_metre>0)
	if beam.is_empty():
		hide();endpoints=PackedVector3Array();mesh=null
		return
	var physical_delta: Vector2=beam.floor_to-beam.floor_from
	var end := barrel_tip_world+Vector3(physical_delta.x,0,physical_delta.y)/pixels_per_metre
	endpoints=PackedVector3Array([barrel_tip_world,end])
	var geometry := ImmediateMesh.new()
	geometry.surface_begin(Mesh.PRIMITIVE_LINES)
	geometry.surface_add_vertex(to_local(barrel_tip_world))
	geometry.surface_add_vertex(to_local(end))
	geometry.surface_end()
	mesh=geometry
	show()
