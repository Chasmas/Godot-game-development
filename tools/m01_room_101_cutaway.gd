extends RefCounted

static func apply(room: Node) -> int:
	var cutaway_surfaces := 0
	for mesh in room.find_children("*","MeshInstance3D",true,false):
		var mesh_name := str(mesh.name).to_lower().replace("_"," ")
		if not (mesh_name.begins_with("101 south wall") or mesh_name.begins_with("101 wall above window") or mesh_name.begins_with("101 entrance lintel")): continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			assert(original != null)
			var material := ShaderMaterial.new()
			material.shader=preload("res://shaders/room_wall_cutaway.gdshader")
			material.set_shader_parameter("albedo_color",original.albedo_color)
			material.set_shader_parameter("roughness",original.roughness)
			material.set_shader_parameter("has_texture",original.albedo_texture!=null)
			if original.albedo_texture:material.set_shader_parameter("albedo_texture",original.albedo_texture)
			mesh.set_surface_override_material(surface,material)
			cutaway_surfaces+=1
	return cutaway_surfaces

## Staging-only material comparison; no collision/destruction changes.
static func fade_front_window(room: Node, opacity: float = .35) -> int:
	var count := 0
	for mesh in room.find_children("*","MeshInstance3D",true,false):
		var label := str(mesh.name).to_lower().replace("_"," ")
		if not (label.begins_with("101 window vertical frame") or label.begins_with("101 window horizontal frame") or label.begins_with("101 window meeting stile") or label.begins_with("101 left gathered curtain") or label.begins_with("101 right gathered curtain") or label.begins_with("101 curtain rail") or label.begins_with("101 curtain brass ring")):continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null:continue
			var faded := original.duplicate() as StandardMaterial3D
			faded.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			faded.albedo_color.a=opacity
			mesh.set_surface_override_material(surface,faded)
			count+=1
	return count
