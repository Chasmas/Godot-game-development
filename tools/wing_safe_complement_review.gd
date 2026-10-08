extends Node
func _ready() -> void:
 var failures := 0
 var report: Array = []
 for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
  if look != "demon": continue
  for part in ["head","arm","leg","legs"]:
   var body := CastModel.create(look)
   var detached := CastModel.create(look)
   add_child(body);add_child(detached)
   var original := area(body)
   preload("res://tools/wing_safe_cut_candidate.gd").cut(body,part)
   preload("res://tools/wing_safe_cut_candidate.gd").cut(detached,part,true)
   var remaining := area(body)
   var removed := area(detached)
   var relative_error := absf(original-remaining-removed)/maxf(original,0.000001)
   var valid := relative_error < 0.00001 and removed > 0.0 and remaining > 0.0
   if not valid: failures += 1
   report.append({"look":look,"part":part,"original_area":original,"body_area":remaining,"detached_area":removed,"relative_error":relative_error,"valid":valid})
   print(look," ",part," complement error=",relative_error," valid=",valid)
   body.free();detached.free()
 var f := FileAccess.open("res://build/wing_safe_complement_review.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"Uncapped source surface area equals body plus complementary detached part across 24 looks and four cuts. Does not prove cap appearance, all animated seams, disconnected fragments or runtime performance.","failures":failures,"cuts":report},"  "))
 Game.request_quit(1 if failures else 0)
func area(model: CastModel) -> float:
 var total := 0.0
 for instance in model._model.find_children("*","MeshInstance3D",true,false):
  if not instance.skin or not instance.mesh is ArrayMesh: continue
  for surface in instance.mesh.get_surface_count():
   var arrays: Array = instance.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var indices := PackedInt32Array()
   if arrays[Mesh.ARRAY_INDEX] != null: indices=arrays[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for i in vertices.size(): indices.append(i)
   for i in range(0,indices.size(),3):
    total += (vertices[indices[i+1]]-vertices[indices[i]]).cross(vertices[indices[i+2]]-vertices[indices[i]]).length()*0.5
 return total
