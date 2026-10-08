extends Node
func _ready() -> void:
 var failures := 0
 var checked := 0
 var bad: Array = []
 for key in preload("res://scripts/player/sever_meshes.gd").CUTS:
  for item in preload("res://scripts/player/sever_meshes.gd").CUTS[key]:
   checked += 1
   for dependency in ResourceLoader.get_dependencies(item[1]):
    if str(dependency).contains("res://build/") or str(dependency).contains("res://tools/"):
     failures += 1
     bad.append({"mesh":item[1],"dependency":str(dependency)})
 var file := FileAccess.open("res://build/runtime_sever_review/dependencies.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Direct saved runtime mesh resource dependencies; no build/tools asset dependencies allowed.","checked":checked,"failures":failures,"bad":bad},"  "))
 print("SEVER ASSET DEPENDENCIES: ",failures," failures / ",checked," meshes")
 Game.request_quit(1 if failures else 0)
