extends RefCounted
static func attach(model: CastModel, look: String, part: String) -> int:
 var geometry_path := OS.get_environment("WOUND_GEOMETRY_PATH")
 if geometry_path.is_empty(): geometry_path = "res://build/wound_surface_candidates/geometry.json"
 var geometry: Array = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
 var count := 0
 for item in geometry:
  if item.look != look or item.part != part: continue
  var source := model._model.find_child(item.mesh, true, false) as MeshInstance3D
  if not source or not source.skin: continue
  var positions := PackedVector3Array()
  var normals := PackedVector3Array()
  var bones := PackedInt32Array()
  var weights := PackedFloat32Array()
  var source_points := PackedVector3Array()
  var source_locations: Array = []
  var influence_count := 4
  var source_arrays: Array = []
  var vertex_lookup: Dictionary = {}
  for surface in source.mesh.get_surface_count():
   var original := source.mesh.surface_get_arrays(surface)
   source_arrays.append(original)
   var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
   for i in vertices.size():
    var key := Vector3i(roundi(vertices[i].x*10000),roundi(vertices[i].y*10000),roundi(vertices[i].z*10000))
    if not vertex_lookup.has(key): vertex_lookup[key] = [surface,i]
  for face in item.faces:
   var points: Array[Vector3] = []
   for id in face:
    var v: Array = item.vertices[int(id)]
    points.append(Vector3(v[0],v[1],v[2]))
   var normal := (points[1]-points[0]).cross(points[2]-points[0]).normalized()
   for point in points:
    var key := Vector3i(roundi(point.x*10000),roundi(point.y*10000),roundi(point.z*10000))
    if not vertex_lookup.has(key):
     push_error("Wound contour vertex missing from source mesh: " + str(key))
     return count
    var location: Array = vertex_lookup[key]
    var best_arrays: Array = source_arrays[location[0]]
    var best_vertex: int = location[1]
    if best_arrays.is_empty(): return count
    influence_count = best_arrays[Mesh.ARRAY_BONES].size()/best_arrays[Mesh.ARRAY_VERTEX].size()
    positions.append(best_arrays[Mesh.ARRAY_VERTEX][best_vertex])
    source_points.append(best_arrays[Mesh.ARRAY_VERTEX][best_vertex])
    source_locations.append(location.duplicate())
    normals.append(normal)
    for slot in influence_count:
     bones.append(best_arrays[Mesh.ARRAY_BONES][best_vertex*influence_count+slot])
     weights.append(best_arrays[Mesh.ARRAY_WEIGHTS][best_vertex*influence_count+slot])
  var arrays: Array = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = positions
  arrays[Mesh.ARRAY_NORMAL] = normals
  var uvs := PackedVector2Array()
  var normal := Vector3.ZERO
  for n in normals: normal += n
  normal = normal.normalized()
  var tangent := normal.cross(Vector3.UP).normalized()
  if tangent.length_squared() < 0.1: tangent = Vector3.RIGHT
  var bitangent := normal.cross(tangent).normalized()
  var lo := Vector2(INF,INF)
  var hi := Vector2(-INF,-INF)
  for point in positions:
   var uv := Vector2(point.dot(tangent),point.dot(bitangent))
   uvs.append(uv)
   lo = lo.min(uv)
   hi = hi.max(uv)
  var extent := (hi-lo).max(Vector2(0.0001,0.0001))
  for i in uvs.size(): uvs[i] = (uvs[i]-lo)/extent
  arrays[Mesh.ARRAY_TEX_UV] = uvs
  arrays[Mesh.ARRAY_BONES] = bones
  arrays[Mesh.ARRAY_WEIGHTS] = weights
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if influence_count == 8 else 0)
  var material := StandardMaterial3D.new()
  material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file("res://build/wound_surface_candidates/wound_fibres.png"))
  material.roughness = 0.31
  material.cull_mode = BaseMaterial3D.CULL_DISABLED
  mesh.surface_set_material(0,material)
  var cap := MeshInstance3D.new()
  cap.name = "WoundCandidate"
  cap.set_meta("wound_candidate",true)
  cap.set_meta("source_points",source_points)
  cap.set_meta("source_locations",source_locations)
  cap.set_meta("source_instance_id",source.get_instance_id())
  cap.mesh = mesh
  cap.skin = source.skin
  cap.skeleton = source.skeleton
  cap.transform = source.transform
  source.get_parent().add_child(cap)
  count += 1
 return count
