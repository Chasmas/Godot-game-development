"""Bake solved paw contacts and compare all mesh samples before exporting."""
import bpy
import json
import struct
import numpy as np
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
starting = '--start-contact' in sys.argv
sequential = '--sequential' in sys.argv
moving = '--moving' in sys.argv
stopping = '--blocked-stop' in sys.argv
starting = starting or stopping
BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman' / ('blocked_stop_candidate_v1' if stopping else (('start_contact_candidate_v3' if moving else ('start_contact_candidate_v2' if sequential else 'start_contact_candidate_v1')) if starting else 'walk_candidate_v4'))
stop_frame_arg = next((arg for arg in sys.argv if arg.startswith('--stop-frame=')), None)
if stopping and stop_frame_arg:
    stop_frame = int(stop_frame_arg.split('=', 1)[1])
    if stop_frame not in (1, 4, 7, 10, 13, 16, 19):
        raise ValueError('Export only measured phase candidates')
    BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/blocked_stop_phase_candidates_v2' / f'frame_{stop_frame:02d}'
OUT = BASE/'baked_candidate_v1'
trotting = '--trot' in sys.argv
if trotting:
    if starting and (not moving or stopping):
        raise ValueError('Trot bridge currently supports moving start only')
    BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'/('start_trot_candidate_v1' if starting else 'trot_candidate_v2')
    if starting and '--trot-midphase' in sys.argv:
        BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/start_trot_candidate_v4'
    OUT = BASE/'baked_candidate_v1'
if '--surface' in sys.argv:
    if not starting or (not moving and not stopping):
        raise ValueError('Corrected surface requires moving start or blocked stop')
    BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/start_contact_candidate_v4'
    if stopping:
        surface_stop_frame = int(stop_frame_arg.split('=', 1)[1]) if stop_frame_arg else 16
        BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/blocked_stop_phase_candidates_v3'/f'frame_{surface_stop_frame:02d}'
    OUT = BASE/'baked_candidate_v1'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/('dog_doberman_start_contact.blend' if starting else 'dog_doberman_walk_candidate.blend')))
rig = next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type=='MESH')
scene = bpy.context.scene
last_frame = (19 if moving or stopping else (37 if sequential else 13)) if starting else 31
if trotting and not starting:
    last_frame = 25
scene.frame_end = last_frame

def evaluated(frame):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    evaluated_obj = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated_obj.to_mesh()
    points = np.empty(len(mesh.vertices)*3,dtype=np.float32)
    mesh.vertices.foreach_get('co',points)
    evaluated_obj.to_mesh_clear()
    points = points.reshape(-1,3)
    world = np.array(evaluated_obj.matrix_world, dtype=np.float32)
    return points @ world[:3,:3].T + world[:3,3]

source = {frame:evaluated(frame) for frame in range(1,last_frame+1)}
object_travel = {}
if moving:
    for frame in source:
        scene.frame_set(frame)
        object_travel[frame] = rig.location.copy()
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.nla.bake(frame_start=1,frame_end=last_frame,step=1,only_selected=False,
    visual_keying=True,clear_constraints=True,use_current_action=False,bake_types={'POSE'})
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action.name = 'doberman_blocked_stop_baked_pilot' if stopping else ('doberman_start_baked_pilot' if starting else 'doberman_walk_baked_pilot')
if moving:
    # Pose bake creates a new action and otherwise drops the object's authored
    # translation. Preserve the measured world travel in that same action.
    for frame, position in object_travel.items():
        rig.location = position
        rig.keyframe_insert(data_path='location', frame=frame)
maximum = max(float(np.linalg.norm(evaluated(frame)-source[frame],axis=1).max()) for frame in source)
remaining = sum(len(bone.constraints) for bone in rig.pose.bones)
report = {'runtime_approved':False,'animation_approved':False,'sampled_frames':last_frame,
    'comparison_space':'world', 'object_travel_preserved':moving,
    'maximum_bake_mesh_difference_m':maximum,'remaining_bone_constraints':remaining,
    'scope':'Solved animation bake versus source at 30Hz; GLB skin limits and Godot playback pending'}
(OUT/'bake_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert maximum < .00001 and remaining==0, 'Bake differs from solved source; do not export'
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dog_doberman_walk_baked.blend'))
obj.select_set(True)
target = OUT/'dog_doberman_walk_baked.glb'
bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIVE_ACTIONS',
    export_anim_slide_to_zero=True,export_force_sampling=True,export_apply=False)
blob = target.read_bytes()
length,_ = struct.unpack_from('<II',blob,12)
document = json.loads(blob[20:20+length])
animations = []
for animation in document.get('animations',[]):
    accessors = [document['accessors'][sampler['input']] for sampler in animation['samplers']]
    animations.append({'name':animation.get('name'),'channels':len(animation['channels']),
        'start_seconds':min(a['min'][0] for a in accessors),
        'end_seconds':max(a['max'][0] for a in accessors)})
assert len(animations)==1 and abs(animations[0]['end_seconds']-(last_frame-1)/30)<.001
report['exported_animations'] = animations
(OUT/'bake_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report),flush=True)
