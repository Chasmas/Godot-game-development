extends Node
func _ready() -> void:
 var failures := 0
 var surfaces := 0
 var max_seam_gap := 0.0
 var report: Array = []
 var jobs: Array = []
 for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
  if look != "eldorado":
   for part in ["leg","legs"]: jobs.append([look,part])
 for job in jobs:
  var look: String = job[0]
  var part: String = job[1]
  var model := CastModel.create(look)
  add_child(model)
  preload("res://tools/anatomical_cut_candidate.gd").cut(model,part)
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
    var source: MeshInstance3D = instance_from_id(cap.get_meta("source_instance_id"))
    var locations: Array = cap.get_meta("source_locations")
    var reference_surfaces: Array = []
    for surface in source.mesh.get_surface_count(): reference_surfaces.append(source.mesh.surface_get_arrays(surface))
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
     var reference: Array = reference_surfaces[locations[vertex][0]]
     var source_vertex: int = locations[vertex][1]
     for slot in influences:
      var index := source_vertex*influences+slot
      var weight: float = reference[Mesh.ARRAY_WEIGHTS][index]
      if weight <= 0.0: continue
      var bind: int = reference[Mesh.ARRAY_BONES][index]
      var bone: int = source.skin.get_bind_bone(bind)
      if bone < 0: bone = model._skeleton.find_bone(source.skin.get_bind_name(bind))
      var transform: Transform3D = model._skeleton.get_bone_global_pose(bone)*source.skin.get_bind_pose(bind)
      body += (transform*reference[Mesh.ARRAY_VERTEX][source_vertex])*weight
     var gap := wound.distance_to(body)
     max_seam_gap = maxf(max_seam_gap,gap)
     if not is_finite(gap) or gap>0.0002: failures += 1
  print("Checked skin bindings: ",look)
  model.free()
 var f := FileAccess.open("res://build/protected_limb_wound_candidates/binding_review.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"Candidate availability, finite vertices, normalized weights, valid skin indices/skeleton and cap vertices compared with actual selected cut-source vertex skinning at five poses. Does not prove all overlapping source layers share weights or visual approval.", "failures":failures,"max_seam_gap_model_units":max_seam_gap,"surfaces":surfaces,"cuts":report},"  "))
 print("WOUND BINDING REVIEW: ",failures," failures / ",surfaces," surfaces / ",report.size()," combinations; max seam gap=",max_seam_gap)
 Game.request_quit(1 if failures else 0)
