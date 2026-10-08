extends Node
func _ready() -> void:
 var path := "res://build/sever_mesh_candidates/manifest.json"
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
 DirAccess.make_dir_recursive_absolute("res://build/packed_sever_mesh_candidates")
 if manifest.get("failures",1)!=0:
  push_error("Native mesh bake is incomplete or invalid")
  Game.request_quit(1)
  return
 var failures := 0
 var before_surfaces := 0
 var after_surfaces := 0
 for cut in manifest.cuts:
  if cut.meshes.size()!=1:
   failures += 1
   continue
  var item: Dictionary = cut.meshes[0]
  var mesh := ResourceLoader.load(item.path) as ArrayMesh
  var body_count: int = mesh.get_surface_count()-int(cut.caps)
  if body_count < 1: failures += 1;continue
  var result := ArrayMesh.new()
  before_surfaces += mesh.get_surface_count()
  for surface in body_count:
   add_surface(result,mesh.surface_get_arrays(surface),mesh.surface_get_material(surface))
  var merged: Array = mesh.surface_get_arrays(body_count)
  var material := mesh.surface_get_material(body_count)
  for surface in range(body_count+1,mesh.get_surface_count()):
   var arrays := mesh.surface_get_arrays(surface)
   for channel in Mesh.ARRAY_MAX:
    if channel != Mesh.ARRAY_INDEX and merged[channel] != null and arrays[channel] != null:
     merged[channel].append_array(arrays[channel])
  add_surface(result,merged,material)
  if result.get_surface_count()!=body_count+1:
   failures += 1
   continue
  var packed_path: String = "res://build/packed_sever_mesh_candidates/"+str(item.path).get_file()
  var error := ResourceSaver.save(result,packed_path,ResourceSaver.FLAG_COMPRESS)
  item["path"]=packed_path
  if error != OK: failures += 1
  item["body_surfaces"]=body_count
  item["wound_surfaces_before_batch"]=cut.caps
  item["surfaces"]=result.get_surface_count()
  after_surfaces += result.get_surface_count()
 manifest["packing"]={"failures":failures,"surfaces_before":before_surfaces,"surfaces_after":after_surfaces,"scope":"Wound triangles batched per source mesh and binary resource compressed. Not runtime performance or visual equivalence approval."}
 var file := FileAccess.open("res://build/packed_sever_mesh_candidates/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  "))
 print("PACKED CUT MESHES: ",failures," failures; surfaces ",before_surfaces," -> ",after_surfaces)
 Game.request_quit(1 if failures else 0)
func add_surface(target: ArrayMesh,arrays: Array,material: Material) -> void:
 var influences: int = arrays[Mesh.ARRAY_BONES].size()/arrays[Mesh.ARRAY_VERTEX].size()
 target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if influences==8 else 0)
 target.surface_set_material(target.get_surface_count()-1,material)
