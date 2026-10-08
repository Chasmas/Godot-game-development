"""Create a subtle idle pilot and measure grounded paw stability."""
import bpy
import json
import math
import sys
from mathutils import Euler
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
surface = '--surface' in sys.argv
neutral_tail = '--neutral-tail' in sys.argv
native = '--native' in sys.argv or surface
SOURCE = BASE / ('walk_candidate_v4/native_skin_candidate_v7/dog_doberman_native_skin.blend' if surface else 'walk_candidate_v4/native_skin_candidate_v6/dog_doberman_native_skin.blend' if native else 'skin_candidate_v6/dog_doberman_skin_candidate.blend')
OUT = BASE / ('idle_native_candidate_v3' if surface else 'idle_native_candidate_v2' if native else 'idle_candidate_v1')
if neutral_tail:
    if not surface:
        raise ValueError('Neutral-tail candidate requires corrected surface')
    OUT = BASE / 'idle_native_candidate_v4'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
if native:
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    bpy.context.view_layer.update()
    # Every bone has an explicit neutral transform in idle, so transitions
    # cannot retain translations or rotations left by locomotion.
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        for frame in (1, 73):
            for field in ('location', 'rotation_quaternion', 'scale'):
                bone.keyframe_insert(data_path=field, frame=frame, group=bone.name)
scene = bpy.context.scene
scene.render.fps = 30
scene.frame_start = 1
scene.frame_end = 72
obj.shape_key_add(name='Basis')
breath = obj.shape_key_add(name='Idle torso breath')
for vertex in obj.data.vertices:
    p = vertex.co
    # Local torso expansion avoids translating the legs or moving feet.
    factor = math.exp(-((p.y/.16)**2+(p.x/.18)**2))
    factor *= max(0., min(1., (p.z-.36)/.10))
    breath.data[vertex.index].co.z += .0018*factor
for frame in range(1,74):
    phase = 2*math.pi*(frame-1)/72
    for name,axis,angle in [('head',2,1.2*math.sin(phase)),
                             ('tail_1',0,4*math.sin(phase)),
                             ('tail_2',0,2*(math.sin(phase-.25)+(math.sin(.25) if neutral_tail else 0))),
                             ('tail_3',0,math.sin(phase-.5)+(math.sin(.5) if neutral_tail else 0))]:
        bone = rig.pose.bones[name]
        if native:
            rotation = Euler((0., 0., 0.), 'XYZ')
            rotation[axis] = math.radians(angle)
            bone.rotation_quaternion = rotation.to_quaternion()
            bone.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=name)
        else:
            bone.rotation_mode='XYZ'
            bone.rotation_euler[axis]=math.radians(angle)
            bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=name)
    breath.value=.5-.5*math.cos(phase)
    breath.keyframe_insert(data_path='value',frame=frame)
rig.animation_data.action.name='doberman_idle_skeleton_pilot'
obj.data.shape_keys.animation_data.action.name='doberman_idle_breath_pilot'
def evaluated():
    bpy.context.view_layer.update()
    evaluated_obj=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated_obj.to_mesh()
    points=[v.co.copy() for v in mesh.vertices]
    evaluated_obj.to_mesh_clear()
    return points
scene.frame_set(1)
start=evaluated()
paws=[v.index for v in obj.data.vertices if v.co.z < .06 and abs(v.co.x)>.025 and abs(v.co.y)>.13]
maximum=0.
for frame in range(1,74):
    scene.frame_set(frame)
    points=evaluated()
    maximum=max(maximum,max((points[i]-start[i]).length for i in paws))
end=evaluated()
seam=max((a-b).length for a,b in zip(start,end))
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dog_doberman_idle_candidate.blend'))
report={'runtime_approved':False,'animation_approved':False,
    'source_blend':str(SOURCE), 'native_linear_skin':native,
    'clip':'doberman_idle_skeleton_pilot','duration_seconds':2.4,
    'frames':72,'loop_duplicate_frame':73,'sampled_frames':73,
    'paw_sample_vertices':len(paws),'maximum_sampled_paw_displacement_m':maximum,
    'maximum_mesh_loop_seam_m':seam,
    'scope':'Authored idle animation and numerical evaluated-mesh checks; playback visual validation pending',
    'jaw_animation_ready':False}
(OUT/'animation_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report),flush=True)
