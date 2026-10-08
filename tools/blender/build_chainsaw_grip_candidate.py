import bpy,json,math
from pathlib import Path
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('assets/art/Artwork/3d/cass/rig_newhair.glb').resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
changed={}
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
baseline={o.name:{'positions':[v.co.copy() for v in o.data.vertices], 'weights':[[(g.group,g.weight) for g in v.groups] for v in o.data.vertices], 'uvs':[[tuple(d.uv) for d in layer.data] for layer in o.data.uv_layers], 'faces':[tuple(f.vertices) for f in o.data.polygons]} for o in meshes}
allowed=set()
for side in ['Left','Right']:
 name=side+'Hand';bone=arm.data.bones[name];changed[name]=0
 for obj in bpy.context.scene.objects:
  if obj.type!='MESH' or name not in obj.vertex_groups: continue
  group=obj.vertex_groups[name].index
  to_hand=bone.matrix_local.inverted()@arm.matrix_world.inverted()@obj.matrix_world
  from_hand=to_hand.inverted()
  for v in obj.data.vertices:
   weight=next((g.weight for g in v.groups if g.group==group),0)
   at=to_hand@v.co
   if weight<.5 or at.y<=6: continue
   # Candidate continuous finger curl, in the hand's rest frame (centimetres).
   t=min((at.y-6)/4,math.pi*.88)
   bent=Vector((at.x,6+4*math.sin(t)-at.z*math.sin(t),4*(1-math.cos(t))+at.z*math.cos(t)))
   allowed.add((obj.name,v.index))
   v.co=from_hand@bent
   changed[name]+=1
  obj.data.update()
audit={'protected_vertices':0,'protected_max_delta':0.0,'changed_outside_fingers':0,'weights_changed':0,'uv_layers_changed':0,'topology_changed':0,'nonfinite_vertices':0,'max_finger_displacement_cm':0.0}
for obj in meshes:
 before=baseline[obj.name]
 for v,original,weights in zip(obj.data.vertices,before['positions'],before['weights']):
  distance=(v.co-original).length
  if (obj.name,v.index) not in allowed:
   audit['protected_vertices']+=1
   audit['protected_max_delta']=max(audit['protected_max_delta'],distance)
   audit['changed_outside_fingers']+=int(distance>1e-6)
  else: audit['max_finger_displacement_cm']=max(audit['max_finger_displacement_cm'],distance)
  audit['weights_changed']+=int(weights!=[(g.group,g.weight) for g in v.groups])
  audit['nonfinite_vertices']+=int(not all(math.isfinite(x) for x in v.co))
 audit['uv_layers_changed']+=int(before['uvs']!=[[tuple(d.uv) for d in layer.data] for layer in obj.data.uv_layers])
 audit['topology_changed']+=int(before['faces']!=[tuple(f.vertices) for f in obj.data.polygons])
assert not any(audit[k] for k in ['changed_outside_fingers','weights_changed','uv_layers_changed','topology_changed','nonfinite_vertices']),audit
Path('build/chainsaw_pose_candidate/hand_geometry_invariants.json').write_text(json.dumps(audit,indent=2))
bpy.ops.export_scene.gltf(filepath=str(Path('build/chainsaw_pose_candidate/cass_grip_mesh.glb').resolve()),export_format='GLB',export_animations=False)
Path('build/chainsaw_pose_candidate/hand_curl_candidate.json').write_text(json.dumps({'approved':False,'changed_vertices':changed,'scope':'Candidate rest mesh finger curl; bones, weights and UVs preserved; not runtime.'},indent=2))
