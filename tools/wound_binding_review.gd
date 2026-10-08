extends Node
func _ready() -> void:
 var failures := 0
 var surfaces := 0
 var max_seam_gap := 0.0
 var report: Array = []
 for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
  if look == "eldorado": continue
  var model := CastModel.create(look)
  add_child(model)
  for part in ["head","arm","leg","legs"]:
   var attached: int = preload("res://tools/wound_candidate_binding.gd").attach(model,look,part)
   var ok := attached > 0
   if not ok: failures += 1
   surfaces += attached
   report.append({"look":look,"part":part,"surfaces":attached,"available":ok})
  for cap in model._model.find_children("*","MeshInstance3D",true,false):
   if not cap.get_meta("wound_candidate",false): continue
   var arrays: Array = cap.mesh.surface_get_arrays(0)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
   var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
   var influences: int = bones.size()/vertices.size()
   for vertex in vertices.size():
    var total := 0.0
    if not vertices[vertex].is_finite(): failures += 1
    for slot in influences:
     var index := vertex*influences+slot
     total += weights[index]
     if weights[index]>0.0001 and (bones[index]<0 or bones[index]>=cap.skin.get_bind_count()): failures += 1
    if absf(total-1.0)>0.002: failures += 1
   if cap.get_node_or_null(cap.skeleton) != model._skeleton: failures += 1
  for phase in [0.0,0.15,0.5,0.8,0.995]:
   model.play_sample("death_back",1.0/60.0,phase)
   model._skeleton.force_update_all_bone_transforms()
   for cap in model._model.find_children("*","MeshInstance3D",true,false):
    if not cap.get_meta("wound_candidate",false): continue
    var arrays: Array = cap.mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var originals: PackedVector3Array = cap.get_meta("source_points")
    var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
    var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
    var influences: int = bones.size()/vertices.size()
    for vertex in vertices.size():
     var wound := Vector3.ZERO
     var body := Vector3.ZERO
     for slot in influences:
      var index := vertex*influences+slot
      if weights[index] <= 0.0: continue
      var bind := bones[index]
      var bone: int = cap.skin.get_bind_bone(bind)
      if bone < 0: bone = model._skeleton.find_bone(cap.skin.get_bind_name(bind))
      var transform: Transform3D = model._skeleton.get_bone_global_pose(bone)*cap.skin.get_bind_pose(bind)
      wound += (transform*vertices[vertex])*weights[index]
      body += (transform*originals[vertex])*weights[index]
     var gap := wound.distance_to(body)
     max_seam_gap = maxf(max_seam_gap,gap)
     if not is_finite(gap) or gap>0.0002: failures += 1
  print("Checked skin bindings: ",look)
  model.free()
 var f := FileAccess.open("res://build/wound_surface_candidates/binding_review.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"Candidate availability, finite vertices, normalized weights, skin indices and skeleton path; animation seam geometry and visuals not approved", "failures":failures,"max_seam_gap_model_units":max_seam_gap,"surfaces":surfaces,"cuts":report},"  "))
 print("WOUND BINDING REVIEW: ",failures," failures / ",surfaces," surfaces / ",report.size()," combinations; max seam gap=",max_seam_gap)
 Game.request_quit(1 if failures else 0)
