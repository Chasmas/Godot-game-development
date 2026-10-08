"""Author an IK-supported start bridge on the refined native skin."""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
sequential = '--sequential' in sys.argv
moving = '--moving' in sys.argv
stopping = '--blocked-stop' in sys.argv
late_body = '--late-body' in sys.argv
surface = '--surface' in sys.argv
trotting = '--trot' in sys.argv
diagonal_start = '--diagonal-start' in sys.argv
trot_midphase = '--trot-midphase' in sys.argv
stop_frame_arg = next((arg for arg in sys.argv if arg.startswith('--stop-frame=')), None)
stop_frame = int(stop_frame_arg.split('=', 1)[1]) if stop_frame_arg else 16
if stopping and not 1 <= stop_frame <= 19:
    raise ValueError('Blocked-stop source frame must be in the authored start clip')
sequential = sequential or moving or stopping
OUT = BASE / ('blocked_stop_candidate_v1' if stopping else ('start_contact_candidate_v3' if moving else ('start_contact_candidate_v2' if sequential else 'start_contact_candidate_v1')))
if stopping and stop_frame_arg:
    OUT = BASE / ('blocked_stop_phase_candidates_v2' if late_body else 'blocked_stop_phase_candidates_v1') / f'frame_{stop_frame:02d}'
OUT.mkdir(parents=True, exist_ok=True)
if surface:
    if not moving and not stopping:
        raise ValueError('Corrected surface requires moving start or blocked stop')
    OUT = BASE / 'blocked_stop_phase_candidates_v3' / f'frame_{stop_frame:02d}' if stopping else BASE / 'start_contact_candidate_v4'
    OUT.mkdir(parents=True, exist_ok=True)
source_path = BASE / ('start_contact_candidate_v4/baked_candidate_v1/dog_doberman_walk_baked.blend' if surface and stopping else 'walk_candidate_v4/native_skin_candidate_v7/dog_doberman_native_skin.blend' if surface else 'start_contact_candidate_v3/baked_candidate_v1/dog_doberman_walk_baked.blend' if stopping else 'walk_candidate_v4/native_skin_candidate_v6/dog_doberman_native_skin.blend')
if trotting:
    if not moving or stopping:
        raise ValueError('Trot bridge currently supports moving start only')
    source_path = BASE / 'trot_candidate_v2/baked_candidate_v1/dog_doberman_walk_baked.blend'
    OUT = BASE / 'start_trot_candidate_v1'
    if diagonal_start:
        OUT = BASE / 'start_trot_candidate_v2'
    if trot_midphase:
        if not diagonal_start:
            raise ValueError('Midphase trot start requires diagonal scheduling')
        OUT = BASE / 'start_trot_candidate_v4'
    OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source_path))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
obj = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
scene = bpy.context.scene
scene.frame_set(stop_frame if stopping else 13 if trotting and trot_midphase else 1)
bpy.context.view_layer.update()
source_eval = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
source_mesh = source_eval.to_mesh()
walk_mesh_points = [source_eval.matrix_world @ vertex.co for vertex in source_mesh.vertices]
source_eval.to_mesh_clear()
keys = [pair + '_' + side for pair in ('front', 'rear') for side in ('negative_x', 'positive_x')]
walk_targets = {key: rig.pose.bones[key + '_paw'].matrix.copy() for key in keys}
walk_pelvis = rig.pose.bones['pelvis'].location.copy()
source_object_offset = rig.location.copy()
rig.animation_data_clear()
rig.location = (0, 0, 0)
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
idle_targets = {key: rig.pose.bones[key + '_paw'].matrix.copy() for key in keys}
neutral_eval = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
neutral_mesh = neutral_eval.to_mesh()
neutral_mesh_points = [neutral_eval.matrix_world @ vertex.co for vertex in neutral_mesh.vertices]
neutral_eval.to_mesh_clear()
if stopping:
    idle_targets, walk_targets = walk_targets, idle_targets
    start_pelvis = walk_pelvis.copy()
    walk_pelvis = Vector((0, 0, 0))
else:
    start_pelvis = Vector((0, 0, 0))
for key in keys:
    control = rig.pose.bones[key + '_contact']
    control.matrix = idle_targets[key]
    constraint = rig.pose.bones[key + '_lower'].constraints.new('IK')
    constraint.target = rig
    constraint.subtarget = control.name
    constraint.chain_count = 2
    constraint.use_stretch = False
    constraint.iterations = 128
    orientation = rig.pose.bones[key + '_paw'].constraints.new('COPY_ROTATION')
    orientation.target = rig
    orientation.subtarget = control.name
    orientation.owner_space = 'POSE'
    orientation.target_space = 'POSE'
    for suffix in ('upper', 'lower', 'paw'):
        rig.pose.bones[key + '_' + suffix].ik_stretch = 0
scene.render.fps = 30
last_frame = 19 if moving or stopping else (37 if sequential else 13)
scene.frame_start, scene.frame_end = 1, last_frame
samples = []
sole_ids = [v.index for v in obj.data.vertices if v.co.z < .06 and abs(v.co.x) > .025 and abs(v.co.y) > .13]
previous = None
maximum_step = 0
maximum_support_slip = 0
previous_support = {}
support_errors = []
initial_pose_error = None
order = ['front_positive_x', 'rear_negative_x', 'front_negative_x', 'rear_positive_x'] if stopping else (['front_negative_x', 'rear_positive_x', 'front_positive_x', 'rear_negative_x'] if moving else ['rear_negative_x', 'front_negative_x', 'rear_positive_x', 'front_positive_x'])
duration = (last_frame - 1) / 30
speed = .20 / (.55 * .8) if trotting else .20 / .65
def swing_timing(key):
    if trotting and diagonal_start:
        first_pair = ('front_negative_x', 'rear_positive_x')
        pair = 0 if key in first_pair else 1
        return .02 + pair * .22, .22
    return ((.02 + order.index(key) * .12) if moving or stopping else (.1 + order.index(key) * .25)), (.16 if moving or stopping else .2)
def travel_at(time):
    # Linear acceleration reaches the authored walk speed at the handoff.
    return .5 * speed * time * time / duration
sole_by_key = {key: [index for index in sole_ids
    if (obj.data.vertices[index].co.x < 0) == ('negative_x' in key)
    and (obj.data.vertices[index].co.y < 0) == key.startswith('front')] for key in keys}
for frame in range(1, last_frame + 1):
    scene.frame_set(frame)
    time = (frame - 1) / 30
    if moving:
        rig.location.y = -travel_at(time)
        rig.keyframe_insert(data_path='location', frame=frame)
    amount = time / duration if stopping else (min(1., time / .1) if sequential else (frame - 1) / 12)
    if stopping and late_body:
        amount = max(0., min(1., (time - .45) / .15))
    amount = amount * amount * (3 - 2 * amount)
    pelvis = rig.pose.bones['pelvis']
    pelvis.location = start_pelvis.lerp(walk_pelvis, amount)
    pelvis.keyframe_insert(data_path='location', frame=frame)
    for key in keys:
        control = rig.pose.bones[key + '_contact']
        # Both endpoint soles retain their authored orientation; interpolate
        # ankle targets, then solve the leg rather than blending joint angles.
        matrix = idle_targets[key].copy()
        if sequential:
            onset, swing_duration = swing_timing(key)
            progress = max(0., min(1., (time - onset) / swing_duration))
            eased = progress * progress * (3 - 2 * progress)
            landing = walk_targets[key].translation.copy()
            if moving:
                landing.y -= travel_at(duration)
            matrix.translation = idle_targets[key].translation.lerp(landing, eased)
            if moving:
                matrix.translation.y += travel_at(time)
            matrix.translation.z += .035 * math.sin(math.pi * progress) ** 2
        else:
            matrix.translation = idle_targets[key].translation.lerp(walk_targets[key].translation, amount)
        control.matrix = matrix
        control.keyframe_insert(data_path='location', frame=frame)
        control.keyframe_insert(data_path='rotation_quaternion', frame=frame)
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(graph)
    mesh = evaluated.to_mesh()
    if stopping and frame == 1:
        initial_pose_error = max((evaluated.matrix_world @ vertex.co - (walk_mesh_points[vertex.index] - source_object_offset)).length for vertex in mesh.vertices)
    points = [evaluated.matrix_world @ mesh.vertices[index].co for index in sole_ids]
    if sequential:
        for key in keys:
            onset, swing_duration = swing_timing(key)
            initially_grounded = abs(idle_targets[key].translation.z - rig.data.bones[key+'_paw'].head_local.z) < .001
            finally_grounded = abs(walk_targets[key].translation.z - rig.data.bones[key+'_paw'].head_local.z) < .001
            planted = (time <= onset and initially_grounded) or (time >= onset + swing_duration and finally_grounded)
            support = [evaluated.matrix_world @ mesh.vertices[index].co for index in sole_by_key[key]]
            if key in previous_support and planted and previous_support[key][0]:
                slip = max((a-b).length for a,b in zip(support, previous_support[key][1]))
                maximum_support_slip = max(maximum_support_slip, slip)
                support_errors.append({'frame':frame, 'paw':key, 'slip_m':slip})
            previous_support[key] = (planted, support)
    minimum = min(point.z for point in points)
    if previous is not None:
        maximum_step = max(maximum_step, max((a-b).length for a,b in zip(points, previous)))
    evaluated.to_mesh_clear()
    previous = points
    samples.append({'frame': frame, 'minimum_sole_height_m': minimum})
endpoint_eval = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
endpoint_mesh = endpoint_eval.to_mesh()
translation = Vector((0, -travel_at(duration), 0)) if moving else Vector((0, 0, 0))
handoff_error = max((endpoint_eval.matrix_world @ vertex.co - translation - walk_mesh_points[vertex.index]).length for vertex in endpoint_mesh.vertices)
idle_handoff_error = max((endpoint_eval.matrix_world @ vertex.co - neutral_mesh_points[vertex.index]).length for vertex in endpoint_mesh.vertices) if stopping else None
endpoint_eval.to_mesh_clear()
scene.frame_set(1)
rig.animation_data.action.name = 'doberman_start_contact'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_start_contact.blend'))
report = {'runtime_approved': False, 'animation_approved': False,
          'duration_seconds': (last_frame - 1)/30, 'samples': samples,
          'sequential_first_steps': sequential,
          'moving_body': moving, 'forward_travel_m': travel_at(duration) if moving else 0,
          'blocked_stop': stopping,
          'blocked_source_frame': stop_frame if stopping else None,
          'blocked_source_pose_difference_m': initial_pose_error,
          'idle_handoff_mesh_difference_m': idle_handoff_error,
          'handoff_speed_m_per_s': speed if moving else 0,
          'maximum_support_slip_per_frame_m': maximum_support_slip if sequential else None,
          'maximum_world_sole_step_m': maximum_step,
          'maximum_walk_handoff_mesh_difference_m': None if stopping else handoff_error,
          'minimum_sole_height_m': min(sample['minimum_sole_height_m'] for sample in samples),
          'scope': f'Blender IK blocked-stop from moving-start frame {stop_frame} to neutral idle; export and visual validation pending' if stopping else 'Blender IK bridge from idle to walk frame 1; world-space sole samples and optional object travel. Export, handoff and visual validation pending'}
report['largest_support_errors'] = sorted(support_errors, key=lambda sample:sample['slip_m'], reverse=True)[:8]
report['handoff_source_frame'] = stop_frame if stopping else 13 if trotting and trot_midphase else 1
(OUT / 'contact_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
