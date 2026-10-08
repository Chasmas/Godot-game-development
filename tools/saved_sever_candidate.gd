extends RefCounted
static var _manifest: Dictionary = {}
static func apply(model: CastModel,part: String) -> int:
 if _manifest.is_empty():
  var path := "res://build/packed_sever_mesh_candidates/manifest.json"
  if not FileAccess.file_exists(path): return 0
  _manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
 if _manifest.get("failures",1) != 0 or _manifest.get("packing",{}).get("failures",1)!=0: return 0
 for cut in _manifest.get("cuts",[]):
  if cut.look != model._look_id or cut.part != part: continue
  var prepared: Array = []
  for item in cut.meshes:
   var source := model._model.find_child(item.source,true,false) as MeshInstance3D
   var mesh := ResourceLoader.load(item.path) as ArrayMesh
   if source == null or mesh == null or not source.skin: return 0
   prepared.append([source,mesh])
  for item in prepared: item[0].mesh=item[1]
  return cut.caps
 return 0
