extends Node
func _ready() -> void:
 var report: Array = []
 for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
  if look == "eldorado": continue
  var focus := OS.get_environment("CUT_REVIEW_LOOKS")
  if not focus.is_empty() and not look in focus.split(","): continue
  for part in ["head", "arm", "leg", "legs"]:
   var parts := OS.get_environment("CUT_REVIEW_PARTS")
   if not parts.is_empty() and not part in parts.split(","): continue
   var model := CastModel.create(look)
   add_child(model)
   var before: Dictionary = {}
   for object in model._model.find_children("*", "MeshInstance3D", true, false):
    if object.skin and object.mesh is ArrayMesh:
     before[object.get_instance_id()] = object.mesh
   if OS.get_environment("ANATOMICAL_CANDIDATE") == "1":
    preload("res://tools/anatomical_cut_candidate.gd").cut(model,part)
   else:
    model.sever_part(part)
   var regions: Array = []
   for object in model._model.find_children("*", "MeshInstance3D", true, false):
    if not before.has(object.get_instance_id()): continue
    var original: ArrayMesh = before[object.get_instance_id()]
    var original_edges := edges(original)
    var remaining_edges := edges(object.mesh)
    var boundary: Array = []
    var all_boundary: Array = []
    var multiple: Dictionary = {}
    for edge in remaining_edges:
     if remaining_edges[edge] > 2: multiple[edge] = {"before":original_edges.get(edge,0),"after":remaining_edges[edge]}
     if remaining_edges[edge] == 1: all_boundary.append(edge)
     if remaining_edges[edge] == 1 and original_edges.get(edge, 0) != 1:
      boundary.append(edge)
    if not boundary.is_empty() or not multiple.is_empty():
     regions.append({"mesh":str(object.name), "new_open_edges":boundary.size(), "edges":boundary,"all_boundary_edges":all_boundary,"nonmanifold_edges":multiple})
   report.append({"look":look,"part":part,"regions":regions})
   print(look, " ", part, " open regions=", regions.size())
   model.free()
 var output := OS.get_environment("CUT_REVIEW_OUTPUT")
 if output.is_empty(): output = "res://build/anatomical_boundary_review.json" if OS.get_environment("ANATOMICAL_CANDIDATE") == "1" else "res://build/sever_boundary_review.json"
 var f := FileAccess.open(output, FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"Welded rest-space edge audit for new cut boundaries; not wound surface approval", "cuts":report}, "  "))
 Game.request_quit()
func edges(mesh: ArrayMesh) -> Dictionary:
 var counts: Dictionary = {}
 for surface in mesh.get_surface_count():
  var arrays := mesh.surface_get_arrays(surface)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var indices := PackedInt32Array()
  if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
  if indices.is_empty():
   for i in vertices.size(): indices.append(i)
  for triangle in range(0, indices.size(), 3):
   for side in 3:
    var a := key(vertices[indices[triangle+side]])
    var b := key(vertices[indices[triangle+(side+1)%3]])
    if a == b: continue
    var edge := a+"|"+b if a < b else b+"|"+a
    counts[edge] = counts.get(edge,0)+1
 return counts
func key(v: Vector3) -> String:
 return "%d,%d,%d" % [roundi(v.x*10000),roundi(v.y*10000),roundi(v.z*10000)]
