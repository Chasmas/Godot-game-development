extends Node
func _ready() -> void:
 var failures := 0
 var checked := 0
 var report: Array = []
 for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
  if look == "eldorado": continue
  for part in ["leg","legs"]:
   var model := CastModel.create(look)
   add_child(model)
   var protected: Dictionary = {}
   var protected_geometry: Dictionary = {}
   var selected: Array[int] = []
   for bone in model._skeleton.get_bone_count():
    var ancestor: int = bone
    while ancestor >= 0:
     var name: String = model._skeleton.get_bone_name(ancestor)
     if name == "RightUpLeg" or (part == "legs" and name == "LeftUpLeg"):
      selected.append(bone);break
     ancestor = model._skeleton.get_bone_parent(ancestor)
   for mesh in model._model.find_children("*","MeshInstance3D",true,false):
    if not mesh.skin or not mesh.mesh is ArrayMesh: continue
    for surface in mesh.mesh.get_surface_count():
     var arrays: Array = mesh.mesh.surface_get_arrays(surface)
     var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
     var indices := indices_for(arrays)
     var slots: int = arrays[Mesh.ARRAY_BONES].size()/vertices.size()
     for triangle in range(0,indices.size(),3):
      var outside := true
      for corner in 3:
       var vertex := indices[triangle+corner]
       var amount := 0.0
       for slot in slots:
        var bind: int = arrays[Mesh.ARRAY_BONES][vertex*slots+slot]
        var bone: int = mesh.skin.get_bind_bone(bind)
        if bone < 0: bone = model._skeleton.find_bone(mesh.skin.get_bind_name(bind))
        if bone in selected: amount += arrays[Mesh.ARRAY_WEIGHTS][vertex*slots+slot]
       if amount>0.15: outside=false
      if outside:
       protected[face_key(arrays,indices,triangle)] = true
       protected_geometry[geometry_key(arrays,indices,triangle)] = true
   preload("res://tools/anatomical_cut_candidate.gd").cut(model,part)
   var remaining: Dictionary = {}
   var remaining_geometry: Dictionary = {}
   for mesh in model._model.find_children("*","MeshInstance3D",true,false):
    if not mesh.skin or not mesh.mesh is ArrayMesh: continue
    for surface in mesh.mesh.get_surface_count():
     var arrays: Array = mesh.mesh.surface_get_arrays(surface)
     var indices := indices_for(arrays)
     for triangle in range(0,indices.size(),3):
      remaining[face_key(arrays,indices,triangle)] = true
      remaining_geometry[geometry_key(arrays,indices,triangle)] = true
   var missing := 0
   for face in protected:
    if not remaining.has(face): missing += 1
   var geometry_missing := 0
   for face in protected_geometry:
    if not remaining_geometry.has(face): geometry_missing += 1
   failures += missing
   checked += protected.size()
   report.append({"look":look,"part":part,"protected_triangles":protected.size(),"missing":missing,"geometry_missing":geometry_missing})
   print(look," ",part," preserved=",protected.size()-missing," missing=",missing," geometry_missing=",geometry_missing)
   model.free()
 var f := FileAccess.open("res://build/limb_uv_preservation_review.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"Source triangles with limb weight <=0.15 retained with original rest position/UV. Not cap, animated seam or gameplay approval.","failures":failures,"triangles_checked":checked,"cuts":report},"  "))
 print("LIMB PRESERVATION REVIEW: ",failures," failures / ",checked," protected triangles")
 Game.request_quit(1 if failures else 0)
func indices_for(arrays: Array) -> PackedInt32Array:
 var indices := PackedInt32Array()
 if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
 if indices.is_empty():
  for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(i)
 return indices
func face_key(arrays: Array,indices: PackedInt32Array,start: int) -> String:
 var corners: Array[String] = []
 for corner in 3:
  var i := indices[start+corner]
  var p: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
  var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
  var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][i] if arrays[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO
  corners.append("%.6f,%.6f,%.6f/%.6f,%.6f" % [p.x,p.y,p.z,uv.x,uv.y])
 corners.sort()
 return "|".join(corners)

func geometry_key(arrays: Array,indices: PackedInt32Array,start: int) -> String:
 var corners: Array[String] = []
 for corner in 3:
  var p: Vector3 = arrays[Mesh.ARRAY_VERTEX][indices[start+corner]]
  corners.append("%.6f,%.6f,%.6f" % [p.x,p.y,p.z])
 corners.sort()
 return "|".join(corners)
