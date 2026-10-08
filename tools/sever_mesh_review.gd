extends Node
func _ready() -> void:
 var failures:=0
 for part in ["head","arm","leg","legs"]:
  var model:=CastModel.create("guard")
  add_child(model)
  var removed: int=model.sever_part(part)
  print(part," removed triangles=",removed)
  if removed<=0: failures+=1
  model.play_sample("death",.1,.5)
  if model.clip!="death": failures+=1
  model.queue_free()
 var corpse:=Corpse.new()
 add_child(corpse)
 corpse.setup("guard",Vector2.RIGHT,false,"head")
 if not corpse._cast is CastModel or corpse.missing!="head": failures+=1
 var intact:=CastModel.create("guard")
 add_child(intact)
 var count:=0
 for object in intact._model.find_children("*","MeshInstance3D",true,false):
  for surface in object.mesh.get_surface_count():
   count+=object.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
 print("Fresh intact triangles=",count)
 if count<=14325: failures+=1
 for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
  if look=="eldorado": continue
  for part in ["head","arm","leg"]:
   var art:=Gore.part_texture(look,part)
   if art==null or art.get_width()==0: failures+=1
   if art!=Gore.part_texture(look,part): failures+=1
 var coverage:=[]
 for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
  if look=="eldorado": continue
  for part in ["head","arm","leg","legs"]:
   var actor:=CastModel.create(look)
   if not actor is CastModel:
    failures+=1
    continue
   add_child(actor)
   var triangles: int=actor.sever_part(part)
   actor.play_sample("death",.1,.5)
   var ok: bool=triangles>0 and actor.clip in ["death","death_back"]
   if not ok: failures+=1
   coverage.append({"look":look,"part":part,"removed_triangles":triangles,"passed":ok})
   actor.free()
 var file:=FileAccess.open("res://build/sever_mesh_coverage.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"visual_approved":false,"checks":coverage},"  "))
 print("Checked ",coverage.size()," character/part combinations")
 print("SEVER MESH REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)
