"""Isolated bellhop doze leg IK repair; preserve the production source."""
import bpy, json, hashlib, math, sys
from mathutils import Vector
from pathlib import Path
identity=sys.argv[sys.argv.index('--identity')+1] if '--identity' in sys.argv else 'bellhop'
source=(Path('assets/art/cast3d_rt')/identity/(identity+'.glb')).resolve()
sha=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
original=next(a for a in bpy.data.actions if a.name=='doze')
rig.animation_data_create()
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.action=original
rig.animation_data.action_slot=original.slots[0]
lo,hi=original.frame_range
bpy.context.scene.frame_set(int(lo))
bpy.context.view_layer.update()
meshes=[o for o in bpy.data.objects if o.type=='MESH']
regions={}
for side in ['Left','Right']:
    regions[side]=[]
    for obj in meshes:
        groups={g.index for g in obj.vertex_groups if g.name in [side+'Foot',side+'ToeBase']}
        indices=[v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.75]
        if indices:regions[side].append((obj,indices))
def sole(side):
    points=[];dg=bpy.context.evaluated_depsgraph_get()
    for obj,indices in regions[side]:
        ev=obj.evaluated_get(dg);m=ev.to_mesh()
        points.extend((ev.matrix_world@m.vertices[i].co).z for i in indices)
        ev.to_mesh_clear()
    return min(points)
samples=[];measurements=[]
for n in range(97):
    frame=lo+(hi-lo)*n/96
    bpy.context.scene.frame_set(int(frame),subframe=frame%1)
    bpy.context.view_layer.update()
    before={side:sole(side) for side in regions}
    rotations={side:rig.pose.bones[side+'Foot'].matrix.copy() for side in regions}
    hips=(rig.matrix_world@rig.pose.bones['Hips'].head).copy()
    for side in regions:
        thigh=rig.pose.bones[side+'UpLeg'];knee=rig.pose.bones[side+'Leg'];foot=rig.pose.bones[side+'Foot']
        H=rig.matrix_world@thigh.head;K=rig.matrix_world@knee.head;A=rig.matrix_world@foot.head
        T=A+Vector((0,0,.002-before[side]))
        l1=(K-H).length;l2=(A-K).length;axis=(T-H).normalized();distance=min((T-H).length,l1+l2-.0001)
        along=(l1*l1-l2*l2+distance*distance)/(2*distance)
        bend=K-H-axis*((K-H).dot(axis));bend.normalize()
        desired_knee=H+axis*along+bend*math.sqrt(max(0,l1*l1-along*along))
        world=rig.matrix_world@thigh.matrix
        rotation=(K-H).rotation_difference(desired_knee-H).to_matrix().to_4x4()
        basis=rotation@world;basis.translation=world.translation
        thigh.matrix=rig.matrix_world.inverted()@basis
        bpy.context.view_layer.update()
        current_knee=rig.matrix_world@knee.head;current_ankle=rig.matrix_world@foot.head
        world=rig.matrix_world@knee.matrix
        rotation=(current_ankle-current_knee).rotation_difference(T-current_knee).to_matrix().to_4x4()
        basis=rotation@world;basis.translation=world.translation
        knee.matrix=rig.matrix_world.inverted()@basis
        bpy.context.view_layer.update()
        matrix=rotations[side].copy();matrix.translation=foot.matrix.translation;foot.matrix=matrix
        bpy.context.view_layer.update()
    measurements.append({'phase':n/96,'before':before,'after':{side:sole(side) for side in regions},'pelvis_drift_m':((rig.matrix_world@rig.pose.bones['Hips'].head)-hips).length})
    samples.append({pb.name:rig.convert_space(pose_bone=pb,matrix=pb.matrix.copy(),from_space='POSE',to_space='LOCAL') for pb in rig.pose.bones})
rig.animation_data.action=None
candidate=bpy.data.actions.new('doze_contact_candidate')
rig.animation_data.action=candidate
for n,poses in enumerate(samples):
    for name,matrix in poses.items():
        pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION';pb.matrix_basis=matrix
        for channel in ['location','rotation_quaternion','scale']:pb.keyframe_insert(data_path=channel,frame=n+1,group=name)
bpy.context.scene.render.fps=30
bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=97
bpy.context.scene.frame_set(1)
out=Path('build/seated_contacts')/(identity+'_candidate_v2');out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str((out/(identity+'_doze.blend')).resolve()))
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes+[rig]:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str((out/(identity+'_doze.glb')).resolve()),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_anim_slide_to_zero=True,export_optimize_animation_size=False)
report={'runtime_approved':False,'visual_approved':False,'source_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==sha,'source_sha256':sha,'measurements':measurements,'scope':'Isolated doze candidate only; other production clips are deliberately absent from this review export'}
(out/'contact_repair.json').write_text(json.dumps(report,indent=2))
print('SEATED CANDIDATE',measurements[48])
