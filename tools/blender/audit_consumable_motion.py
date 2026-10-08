"""Evaluate actual animated body and detailed can triangles across the sip."""
import bpy,json,os
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri
out=Path(os.environ.get('CONSUMABLE_MOTION_AUDIT_OUTPUT','build/consumable_motion_mesh_audit')).resolve();out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(os.environ.get('CONSUMABLE_MOTION_AUDIT_MODEL','build/consumable_sip_v2_isolated/guard.glb')).resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
actions=[strip.action for track in arm.animation_data.nla_tracks for strip in track.strips if 'drink' in strip.action.name.lower()]
assert len(actions)==1,[(a.name,list(a.frame_range)) for a in bpy.data.actions]
action=actions[0];arm.animation_data_clear();arm.animation_data_create();arm.animation_data.action=action
old=next(o for o in bpy.context.scene.objects if o.type=='MESH' and 'RightHand' in o.vertex_groups)
with bpy.data.libraries.load(str(Path('build/consumable_grip_morph/guard_grip.blend').resolve()),link=False) as (source,destination):
 destination.objects=source.objects
body=next(o for o in destination.objects if o and o.type=='MESH' and 'RightHand' in o.vertex_groups)
bpy.context.scene.collection.objects.link(body)
world=old.matrix_world.copy();body.parent=arm;body.matrix_world=world
for modifier in body.modifiers:
 if modifier.type=='ARMATURE':modifier.object=arm
body.data.shape_keys.key_blocks['CanGrip'].value=1
bpy.data.objects.remove(old,do_unlink=True)
with bpy.data.libraries.load(str(Path('build/idle_consumables_candidate/can.blend').resolve()),link=False) as (source,destination):
 destination.objects=source.objects
props=[];rest={}
for obj in destination.objects:
 if not obj or obj.type not in {'MESH','CURVE','FONT'}:continue
 bpy.context.scene.collection.objects.link(obj);props.append(obj);rest[obj.name]=obj.matrix_world.copy()
def triangles(objects,deps):
 verts=[];faces=[]
 for obj in objects:
  evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh();mesh.calc_loop_triangles();start=len(verts)
  verts.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
  faces.extend(tuple(start+i for i in tri.vertices) for tri in mesh.loop_triangles)
  evaluated.to_mesh_clear()
 return verts,faces
def crosses(a,b):
 for i in range(3):
  delta=a[(i+1)%3]-a[i]
  if delta.length<1e-9:continue
  hit=intersect_ray_tri(*b,delta.normalized(),a[i],True)
  if hit is not None and -1e-7<=(hit-a[i]).dot(delta.normalized())<=delta.length+1e-7:return True
 return False
rows=[]
for sample in range(49):
 phase=sample/48;at=action.frame_range[0]+phase*(action.frame_range[1]-action.frame_range[0])
 bpy.context.scene.frame_set(int(at),subframe=at-int(at));bpy.context.view_layer.update()
 frame=arm.matrix_world@arm.pose.bones['RightHand'].matrix
 axes=frame.to_3x3().normalized();attachment=Matrix((axes.col[1],axes.col[2],axes.col[0])).transposed().to_4x4()
 attachment.translation=frame@Vector((-5.75,9,-4.1))
 for obj in props:obj.matrix_world=attachment@rest[obj.name]
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
 hv,hf=triangles([body],deps);pv,pf=triangles(props,deps)
 assert all(v.length<3 for v in hv),'Animated body vertices must remain in metre-scale scene'
 pairs=BVHTree.FromPolygons(hv,hf,all_triangles=True).overlap(BVHTree.FromPolygons(pv,pf,all_triangles=True))
 hits=[];regions={}
 for hi,pi in pairs:
  hand=[hv[v] for v in hf[hi]];prop=[pv[v] for v in pf[pi]]
  if not (crosses(hand,prop) or crosses(prop,hand)):continue
  hits.append([hi,pi])
  weights={}
  for vi in hf[hi]:
   for group in body.data.vertices[vi].groups:
    name=body.vertex_groups[group.group].name;weights[name]=weights.get(name,0)+group.weight
  region=max(weights,key=weights.get) if weights else 'unweighted';regions[region]=regions.get(region,0)+1
 rows.append({'phase':phase,'crossings':len(hits),'regions':regions,'hand_world':list(frame.translation),'mesh_vertex_world':list(hv[0])})
 print('MOTION_MESH',sample,len(hits),regions,flush=True)
(out/'report.json').write_text(json.dumps({'approved':False,'scope':'49 native Blender poses, bidirectional detailed can/body triangle crossings; Godot deformation parity, containment and coplanar surfaces still require validation.','rows':rows},indent=2))
assert (Vector(rows[0]['hand_world'])-Vector(rows[16]['hand_world'])).length>.1,'Audit must evaluate a moving hand'
at=action.frame_range[0]+.33*(action.frame_range[1]-action.frame_range[0])
bpy.context.scene.frame_set(int(at),subframe=at-int(at));bpy.context.view_layer.update()
frame=arm.matrix_world@arm.pose.bones['RightHand'].matrix;axes=frame.to_3x3().normalized()
attachment=Matrix((axes.col[1],axes.col[2],axes.col[0])).transposed().to_4x4();attachment.translation=frame@Vector((-5.75,9,-4.1))
for obj in props:obj.matrix_world=attachment@rest[obj.name]
head=arm.matrix_world@arm.pose.bones['Head'].head
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('MotionStudio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
bpy.ops.object.camera_add(location=head+Vector((.4,-.6,.2)));camera=bpy.context.object
camera.rotation_euler=(head-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=.42;camera.data.clip_start=.001;scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=head+Vector((.4,-.5,.6)));lamp=bpy.context.object
lamp.rotation_euler=(head-lamp.location).to_track_quat('-Z','Y').to_euler();lamp.data.energy=4;lamp.data.size=.5
scene.render.filepath=str(out/'sip_native.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'sip_review.blend'))
