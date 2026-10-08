extends Node
func _ready() -> void:
 var output := OS.get_environment("SEVER_MESH_OUTPUT")
 if output.is_empty(): output = "res://build/sever_mesh_candidates"
 var retain := OS.get_environment("SEVER_MESH_RETAIN")=="1"
 DirAccess.make_dir_recursive_absolute(output)
 var geometry: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("WOUND_GEOMETRY_PATH")))
 var records: Array = []
 var failures := 0
 for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
  if look == "eldorado": continue
  for part in ["head","arm","leg","legs"]:
   if retain and part=="legs": continue
   var model := CastModel.create(look)
   add_child(model)
   var sources: Array = []
   for instance in model._model.find_children("*","MeshInstance3D",true,false):
    if instance.skin and instance.mesh is ArrayMesh: sources.append(instance)
   preload("res://tools/wing_safe_cut_candidate.gd").cut(model,part,retain)
   var attached: int = preload("res://tools/wound_candidate_binding.gd").attach(model,look,part)
   var expected := 0
   for item in geometry:
    if item.look == look and item.part == part: expected += 1
   if attached != expected or expected == 0:
    failures += 1
    model.free()
    continue
   var meshes: Array = []
   for source in sources:
    var combined := ArrayMesh.new()
    append_surfaces(combined,source.mesh)
    for cap in model._model.find_children("*","MeshInstance3D",true,false):
     if cap.get_meta("wound_candidate",false) and cap.get_meta("source_instance_id")==source.get_instance_id():
      append_surfaces(combined,cap.mesh)
    var path := output+"/%s_%s_%d.res" % [look,part,meshes.size()]
    var error := ResourceSaver.save(combined,path,ResourceSaver.FLAG_COMPRESS)
    if error != OK: failures += 1
    meshes.append({"source":str(source.name),"path":path,"surfaces":combined.get_surface_count()})
   records.append({"look":look,"part":part,"caps":attached,"expected_caps":expected,"meshes":meshes})
   print("Saved cut mesh: ",look," ",part)
   model.free()
 var file := FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"status":"candidate_not_integrated","scope":"Precomputed source mesh with independently built wound surfaces, retaining original skin bind indices. Requires saved-resource equivalence, body binding, visual and gameplay validation.","failures":failures,"retained_detached_part":retain,"cuts":records},"  "))
 Game.request_quit(1 if failures else 0)
func append_surfaces(target: ArrayMesh,source: ArrayMesh) -> void:
 for surface in source.get_surface_count():
  var arrays := source.surface_get_arrays(surface)
  var influences: int = arrays[Mesh.ARRAY_BONES].size()/arrays[Mesh.ARRAY_VERTEX].size()
  target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if influences == 8 else 0)
  target.surface_set_material(target.get_surface_count()-1,source.surface_get_material(surface))
