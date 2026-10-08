extends RefCounted
static func cut(model: CastModel, part: String, retain_part := false) -> int:
 var roots: Array = {"head":["Head","Head1"],"arm":["RightArm"],"leg":["RightUpLeg"],"legs":["RightUpLeg","LeftUpLeg"]}.get(part,[])
 if part == "head" and model._look_id == "heavy": roots.append("neck")
 var selected: Array[int] = []
 for bone in model._skeleton.get_bone_count():
  var ancestor := bone
  while ancestor >= 0:
   if model._skeleton.get_bone_name(ancestor) in roots:
    selected.append(bone)
    break
   ancestor = model._skeleton.get_bone_parent(ancestor)
 var changed := 0
 for object in model._model.find_children("*","MeshInstance3D",true,false):
  var instance := object as MeshInstance3D
  if not instance.mesh is ArrayMesh or not instance.skin: continue
  var joints: Dictionary = {}
  for bind in instance.skin.get_bind_count():
   var bone := instance.skin.get_bind_bone(bind)
   if bone < 0: bone = model._skeleton.find_bone(instance.skin.get_bind_name(bind))
   joints[str(model._skeleton.get_bone_name(bone))] = instance.skin.get_bind_pose(bind).affine_inverse().origin
  var replacement := ArrayMesh.new()
  for surface in instance.mesh.get_surface_count():
   var original := instance.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
   var indices := PackedInt32Array()
   if original[Mesh.ARRAY_INDEX] != null: indices = original[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for i in vertices.size(): indices.append(i)
   var influence_count: int = original[Mesh.ARRAY_BONES].size()/vertices.size()
   var output: Array[Dictionary] = []
   for triangle in range(0,indices.size(),3):
    var polygon: Array[Dictionary] = []
    for corner in 3:
     var index := indices[triangle+corner]
     var weights: Dictionary = {}
     var amount := 0.0
     for slot in influence_count:
      var bind: int = original[Mesh.ARRAY_BONES][index*influence_count+slot]
      var weight: float = original[Mesh.ARRAY_WEIGHTS][index*influence_count+slot]
      if weight <= 0: continue
      weights[bind] = weights.get(bind,0.0)+weight
      var bone := instance.skin.get_bind_bone(bind)
      if bone < 0: bone = model._skeleton.find_bone(instance.skin.get_bind_name(bind))
      if bone in selected: amount += weight
     polygon.append({"p":vertices[index],"n":original[Mesh.ARRAY_NORMAL][index],"uv":original[Mesh.ARRAY_TEX_UV][index] if original[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO,"w":weights,"a":amount})
    var pieces: Array = []
    if part == "arm" and joints.has("RightArm") and joints.has("LeftArm") and joints.has("RightForeArm"):
     if polygon.any(func(v):return v.a > 0.15):
      var shoulder: Vector3 = joints.RightArm
      var opposite: Vector3 = joints.LeftArm
      var elbow: Vector3 = joints.RightForeArm
      var origin := shoulder.lerp(elbow,0.10)
      var axis := (shoulder-opposite).normalized()
      pieces.append(clip_polygon(polygon,func(p):return (p-origin).dot(axis),false,retain_part))
     elif not retain_part: pieces.append(polygon)
    elif part in ["leg","legs"] and polygon.any(func(v):return v.a > 0.15) and joints.has("RightUpLeg") and joints.has("RightLeg") and joints.has("LeftUpLeg"):
     var hip: Vector3 = joints.RightUpLeg
     var other: Vector3 = joints.LeftUpLeg
     var midpoint := (hip+other)*0.5
     var side := (hip-other).normalized()
     var right := clip_polygon(polygon,func(p):return -(p-midpoint).dot(side))
     var left := clip_polygon(polygon,func(p):return (p-midpoint).dot(side))
     var knee: Vector3 = joints.RightLeg
     var origin := hip.lerp(knee,0.08)
     var axis := (knee-hip).normalized()
     right = clip_polygon(right,func(p):return (p-origin).dot(axis),false,retain_part)
     if part == "legs" and joints.has("LeftLeg"):
      var left_knee: Vector3 = joints.LeftLeg
      var left_origin := other.lerp(left_knee,0.08)
      var left_axis := (left_knee-other).normalized()
      left = clip_polygon(left,func(p):return (p-left_origin).dot(left_axis),false,retain_part)
     pieces.append(right)
     if part == "legs" or not retain_part: pieces.append(left)
    elif part in ["leg","legs"]:
     if not retain_part: pieces.append(polygon)
    else:
     pieces.append(clip_polygon(polygon,func(_p):return 0.0,true,retain_part))
    var retained := 0
    for clipped in pieces:
     for i in range(1,clipped.size()-1):
      var area: float = (clipped[i].p-clipped[0].p).cross(clipped[i+1].p-clipped[0].p).length_squared()
      if area < 0.00000000000001: continue
      output.append(clipped[0]);output.append(clipped[i]);output.append(clipped[i+1])
      retained += 1
    if retained != 1: changed += 1
   if output.is_empty(): continue
   var arrays: Array = [];arrays.resize(Mesh.ARRAY_MAX)
   var positions := PackedVector3Array();var normals := PackedVector3Array();var uvs := PackedVector2Array();var bones := PackedInt32Array();var weights := PackedFloat32Array()
   for vertex in output:
    positions.append(vertex.p);normals.append(vertex.n);uvs.append(vertex.uv)
    var keys: Array = vertex.w.keys()
    keys.sort_custom(func(a,b):return vertex.w[a]>vertex.w[b])
    var total := 0.0
    for slot in mini(influence_count,keys.size()): total += vertex.w[keys[slot]]
    for slot in influence_count:
     bones.append(keys[slot] if slot < keys.size() else 0)
     weights.append(vertex.w[keys[slot]]/total if slot < keys.size() else 0.0)
   arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
   replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if influence_count==8 else 0)
   replacement.surface_set_material(replacement.get_surface_count()-1,instance.mesh.surface_get_material(surface))
  instance.mesh = replacement
 return changed
static func interpolate(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
 var weights: Dictionary = {}
 for bind in a.w: weights[bind] = a.w[bind]*(1.0-t)
 for bind in b.w: weights[bind] = weights.get(bind,0.0)+b.w[bind]*t
 return {"p":a.p.lerp(b.p,t),"n":a.n.lerp(b.n,t).normalized(),"uv":a.uv.lerp(b.uv,t),"w":weights,"a":0.45}

static func section_distance(point: Vector3,joints: Dictionary,side: String) -> float:
 var hip: Vector3 = joints[side+"UpLeg"]
 var knee: Vector3 = joints[side+"Leg"]
 var other: Vector3 = joints[("Left" if side == "Right" else "Right")+"UpLeg"]
 var axis := (knee-hip).normalized()
 var origin := hip.lerp(knee,0.08)
 var facing := (hip-other).normalized()
 return minf((point-origin).dot(axis),(point-(hip+other)*0.5).dot(facing))

static func clip_polygon(polygon: Array[Dictionary],distance: Callable,use_weights := false, invert := false) -> Array[Dictionary]:
 var clipped: Array[Dictionary] = []
 if polygon.is_empty(): return clipped
 var previous: Dictionary = polygon[-1]
 var sign := -1.0 if invert else 1.0
 var before: float = sign*(previous.a-0.45 if use_weights else distance.call(previous.p))
 for current in polygon:
  var now: float = sign*(current.a-0.45 if use_weights else distance.call(current.p))
  var inside := now <= 0.0
  if inside != (before <= 0.0):
   clipped.append(interpolate(previous,current,before/(before-now)))
  if inside: clipped.append(current)
  previous=current;before=now
 return clipped
