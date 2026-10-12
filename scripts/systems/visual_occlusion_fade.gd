extends RefCounted
## Visual-only candidate. Local bounding boxes are a conservative broadphase.
var _meshes: Array[MeshInstance3D] = []
var _originals: Dictionary = {}
var _faded: Dictionary = {}
var _faces: Dictionary = {}
var _amounts: Dictionary = {}
var _alphas: Dictionary = {}

func setup(root: Node) -> void:
	restore()
	_meshes.clear()
	_originals.clear()
	_faded.clear()
	_faces.clear()
	_amounts.clear()
	_alphas.clear()
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		_meshes.append(mesh)
		_faces[mesh] = mesh.mesh.get_faces()
		var originals: Array = []
		var faded: Array = []
		var alphas: Array = []
		for surface in mesh.mesh.get_surface_count():
			originals.append(mesh.get_surface_override_material(surface))
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null:
				alphas.append(1.0)
				faded.append(originals.back())
				continue
			var material := source.duplicate() as StandardMaterial3D
			alphas.append(source.albedo_color.a)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a *= 0.15
			faded.append(material)
		_originals[mesh] = originals
		_faded[mesh] = faded
		_alphas[mesh] = alphas
		_amounts[mesh] = 0.0

func update(camera: Camera3D, actor_position: Vector3, delta: float = 1.0/60.0) -> Array:
	var names: Array = []
	for mesh in _meshes:
		if not is_instance_valid(mesh): continue
		var blocked := false
		for height in [0.5, 0.9, 1.4]:
			var target := actor_position + Vector3(0,height,0)
			var origin := camera.project_ray_origin(camera.unproject_position(target))
			var local_start := mesh.to_local(origin)
			var local_end := mesh.to_local(target)
			if mesh.get_aabb().intersects_segment(local_start,local_end) == null: continue
			var faces: PackedVector3Array = _faces[mesh]
			for index in range(0,faces.size(),3):
				if Geometry3D.segment_intersects_triangle(local_start,local_end,faces[index],faces[index+1],faces[index+2]) != null:
					blocked = true
					break
			if blocked: break
		var amount := move_toward(float(_amounts[mesh]),1.0 if blocked else 0.0,maxf(delta,0.0)/(0.08 if blocked else 0.18))
		_amounts[mesh] = amount
		var materials: Array = _faded[mesh] if amount > 0.0 else _originals[mesh]
		if amount > 0.0:
			for surface in materials.size():
				if materials[surface] is StandardMaterial3D:
					materials[surface].albedo_color.a = float(_alphas[mesh][surface])*lerpf(1.0,0.15,amount)
		for surface in materials.size(): mesh.set_surface_override_material(surface,materials[surface])
		if blocked: names.append(str(mesh.name))
	return names

func restore() -> void:
	for mesh in _originals:
		if not is_instance_valid(mesh): continue
		var materials: Array = _originals[mesh]
		for surface in materials.size(): mesh.set_surface_override_material(surface,materials[surface])
		_amounts[mesh] = 0.0
