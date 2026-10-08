"""Read-only sampled wrist area-strain audit; no mesh writes or approval."""
import bpy,json,os,math
from mathutils import Vector
from pathlib import Path
source=Path(os.environ.get('GUARD_WRIST_SOURCE','build/guard_weighted_locomotion_v9/guard.glb'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source.resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys)
body.data.calc_loop_triangles()
triangles=list(body.data.loop_triangles)
regions={}
for side in ('Right','Left'):
 inverse=arm.data.bones[side+'Hand'].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world
 group=body.vertex_groups[side+'Hand'].index
 forearm=body.vertex_groups[side+'ForeArm'].index
 lower=float(os.environ.get('GUARD_WRIST_LOWER','-.5'))
 eligible={v.index for v in body.data.vertices if sum(g.weight for g in v.groups if g.group in (group,forearm))>.95 and lower<(inverse@v.co).y<3.1}
 regions[side]=[tuple(t.vertices) for t in triangles if all(i in eligible for i in t.vertices)]
 assert regions[side]
def area(mesh,tri):
 a,b,c=[mesh.vertices[i].co for i in tri]
 return (b-a).cross(c-a).length*.5
reference={side:[area(body.data,t) for t in ts] for side,ts in regions.items()}
arm.animation_data_clear();arm.animation_data_create()
rows=[]
for clip in os.environ.get('GUARD_WRIST_CLIPS','aim_dual,armed_dual_walk,armed_dual_run').split(','):
 action=next(a for a in bpy.data.actions if a.name.split('.')[0]==clip)
 arm.animation_data.action=action
 body.data.shape_keys.key_blocks['WeaponGrip'].value=1
 samples=[]
 for sample in range(65):
  phase=sample/64;frame=action.frame_range[0]+phase*(action.frame_range[1]-action.frame_range[0])
  bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
  if sample==0:
   print('WRIST_LOCAL_ROTATION',clip,json.dumps({side:math.degrees(arm.pose.bones[side+'Hand'].matrix_basis.to_quaternion().angle) for side in ('Right','Left')}))
   print('WRIST_SWING_ONLY',clip,json.dumps({side:math.degrees(Vector((0,1,0)).rotation_difference(arm.pose.bones[side+'Hand'].matrix_basis.to_quaternion()@Vector((0,1,0))).angle) for side in ('Right','Left')}))
  evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
  for side,ts in regions.items():
   eligible=[(t,area(mesh,t)/base) for t,base in zip(ts,reference[side]) if base>1e-8]
   ratios=[r for t,r in eligible]
   worst=min(eligible,key=lambda pair:pair[1])
   samples.append({'phase':phase,'side':side,'min_area_ratio':min(ratios),'max_area_ratio':max(ratios),'extreme_triangles':sum(r<.05 or r>20 for r in ratios),'worst_triangle_vertices':list(worst[0])})
  evaluated.to_mesh_clear()
 rows.append({'clip':clip,'samples':samples,'extreme_samples':sum(s['extreme_triangles']>0 for s in samples)})
report={'approved':False,'source':str(source),'region_triangle_counts':{s:len(ts) for s,ts in regions.items()},'rows':rows,'scope':'65 phases per clip, area ratios against rest wrist triangles; does not prove normals, anatomical silhouette or self-intersection quality.'}
details=[]
for sample in rows[0]['samples'][:2]:
 side=sample['side'];inverse=arm.data.bones[side+'Hand'].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world
 for index in sample['worst_triangle_vertices']:
  vertex=body.data.vertices[index]
  details.append({'side':side,'vertex':index,'hand_local_rest':list(inverse@vertex.co),'morph_delta':list(body.data.shape_keys.key_blocks['WeaponGrip'].data[index].co-vertex.co),'weights':{body.vertex_groups[g.group].name:g.weight for g in vertex.groups}})
report['worst_rest_vertices']=details
(source.parent/'wrist_deformation_report.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'regions':report['region_triangle_counts'],'clips':[{'clip':r['clip'],'extreme_samples':r['extreme_samples'],'min':min(s['min_area_ratio'] for s in r['samples']),'max':max(s['max_area_ratio'] for s in r['samples'])} for r in rows]}))
print(json.dumps(details))
