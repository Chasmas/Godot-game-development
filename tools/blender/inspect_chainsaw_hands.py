import bpy,json
from pathlib import Path
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('assets/art/Artwork/3d/cass/rig_newhair.glb').resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
r={}
for side in ['Left','Right']:
 name=side+'Hand'; bone=arm.data.bones[name]; points=[]
 for obj in bpy.context.scene.objects:
  if obj.type!='MESH' or name not in obj.vertex_groups: continue
  group=obj.vertex_groups[name].index
  for v in obj.data.vertices:
   weight=next((g.weight for g in v.groups if g.group==group),0)
   if weight>.5:
    local=bone.matrix_local.inverted()@arm.matrix_world.inverted()@obj.matrix_world@v.co
    points.append(list(local))
 r[name]={'head':list(bone.head_local),'tail':list(bone.tail_local),'count':len(points),'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)],'points':points}
Path('build/chainsaw_pose_candidate/hand_geometry.json').write_text(json.dumps(r,indent=2))
