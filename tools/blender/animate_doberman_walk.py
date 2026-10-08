"""Author a four-beat walk pilot and audit evaluated contacts over the full cycle."""
import bpy
import json
import math
import sys
import numpy as np
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
BALANCED = '--balanced' in sys.argv
TROT = '--trot' in sys.argv
TROT_CLEARANCE = '--trot-clearance' in sys.argv
if TROT_CLEARANCE and not TROT:
    raise ValueError('Trot clearance requires the trot gait')
BALANCED = BALANCED or TROT
OUT = BASE / ('trot_candidate_v1' if TROT else 'walk_candidate_v4' if BALANCED else 'walk_candidate_v2')
if TROT_CLEARANCE:
    OUT = BASE / 'trot_candidate_v2'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / ('walk_candidate_v4/native_skin_candidate_v7/dog_doberman_native_skin.blend' if TROT else 'walk_candidate_v3/dog_doberman_walk_candidate.blend' if BALANCED else 'contact_candidate_v3/dog_doberman_contact_candidate.blend')))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
scene = bpy.context.scene
scene.render.fps = 30
frames = 24 if TROT else 30
DURATION = frames / 30
scene.frame_start, scene.frame_end = 1, frames
STANCE = .55 if TROT else .65
STRIDE = .20
SPEED = STRIDE / STANCE
BODY_LOWERING = .028 if BALANCED else .040
if TROT_CLEARANCE:
    BODY_LOWERING = .032
phases = {'rear_negative_x': 0., 'front_negative_x': .25,
          'rear_positive_x': .5, 'front_positive_x': .75}
if TROT:
    phases = {'front_negative_x': 0., 'rear_positive_x': 0., 'front_positive_x': .5, 'rear_negative_x': .5}
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    for key in phases:
        constraint = rig.pose.bones[key+'_lower'].constraints.new('IK')
        constraint.target = rig
        constraint.subtarget = key+'_contact'
        constraint.chain_count = 2
        constraint.use_stretch = False
        constraint.iterations = 128
        orientation = rig.pose.bones[key+'_paw'].constraints.new('COPY_ROTATION')
        orientation.target = rig
        orientation.subtarget = key+'_contact'
        orientation.owner_space = 'POSE'
        orientation.target_space = 'POSE'
        for suffix in ('upper', 'lower', 'paw'):
            rig.pose.bones[key+'_'+suffix].ik_stretch = 0
leg_stances = {key: (.52 if BALANCED and not TROT and key.startswith('rear') else STANCE) for key in phases}
if BALANCED:
    rig.animation_data_clear()
    rig.pose.bones['pelvis'].location = (0,0,0)
    for key in phases:
        rig.pose.bones[key+'_contact'].matrix = rig.data.bones[key+'_paw'].matrix_local.copy()
    bpy.context.view_layer.update()
base_locations = {key: rig.pose.bones[key + '_contact'].location.copy() for key in phases}
base_endpoints = {key: rig.pose.bones[key + '_paw'].tail.copy() for key in phases}
source_positions = np.array([v.co[:] for v in obj.data.vertices])
sole_masks = {key: ((source_positions[:,2] < .06) &
    (source_positions[:,0] < -.025 if 'negative_x' in key else source_positions[:,0] > .025) &
    (source_positions[:,1] < -.13 if key.startswith('front') else source_positions[:,1] > .13)) for key in phases}

def trajectory(q, duty):
    stride = SPEED*duty
    if q < duty:
        return Vector((0., -stride/2 + SPEED*q, 0.)), True
    u = (q-duty)/(1-duty)
    # Hermite endpoint derivatives match planted-paw backward speed.
    slope = SPEED*(1-duty)
    y = (2*u**3-3*u**2+1)*(stride/2) + (u**3-2*u**2+u)*slope
    y += (-2*u**3+3*u**2)*(-stride/2) + (u**3-u**2)*slope
    return Vector((0., y, .035*math.sin(math.pi*u)**2)), False

samples = []
positions_by_frame = []
previous = {}
maximum_slip = 0.
maximum_endpoint_error = 0.
minimum_height = 1.
for frame in range(1,frames+2):
    t = (frame-1)/frames
    scene.frame_set(frame)
    pelvis = rig.pose.bones['pelvis']
    pelvis.location = pelvis.bone.matrix_local.to_3x3().inverted() @ Vector((.003*math.sin(2*math.pi*t),0.,-BODY_LOWERING+.002*math.cos(4*math.pi*t)))
    pelvis.keyframe_insert(data_path='location', frame=frame)
    desired = {}
    stance = {}
    for key, phase in phases.items():
        q = (t+phase) % 1.
        delta, planted = trajectory(q,leg_stances[key])
        control = rig.pose.bones[key + '_contact']
        control.location = base_locations[key] + control.bone.matrix_local.to_3x3().inverted() @ delta
        control.keyframe_insert(data_path='location', frame=frame, group=key)
        desired[key] = base_endpoints[key] + delta
        stance[key] = (q, planted)
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    evaluated_rig = rig.evaluated_get(graph)
    errors = {key: (evaluated_rig.pose.bones[key+'_paw'].tail-desired[key]).length for key in phases}
    maximum_endpoint_error = max(maximum_endpoint_error, max(errors.values()))
    evaluated_obj = obj.evaluated_get(graph)
    mesh = evaluated_obj.to_mesh()
    points = np.empty(len(mesh.vertices)*3,dtype=np.float32)
    mesh.vertices.foreach_get('co',points)
    points = points.reshape(-1,3)
    evaluated_obj.to_mesh_clear()
    positions_by_frame.append(points.copy())
    minimum_height = min(minimum_height,float(points[:,2].min()))
    for key, (q, planted) in stance.items():
        # Translate the in-place pilot by its physical forward speed. During
        # stance, each sole vertex must remain fixed in these world coordinates.
        world_soles = points[sole_masks[key]].copy()
        world_soles[:,1] -= SPEED*t
        if key in previous:
            prior_q, prior_planted, prior_soles = previous[key]
            if planted and prior_planted and q >= prior_q:
                slip = float(np.linalg.norm(world_soles-prior_soles,axis=1).max())
                maximum_slip = max(maximum_slip,slip)
        previous[key] = (q, planted, world_soles)
    samples.append({'frame':frame,'paw_endpoint_errors_m':errors,
                    'minimum_mesh_height_m':float(points[:,2].min())})
seam = float(np.linalg.norm(positions_by_frame[-1]-positions_by_frame[0],axis=1).max())
rig.animation_data.action.name = 'doberman_trot_controls_pilot' if TROT else 'doberman_walk_controls_pilot'
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dog_doberman_walk_candidate.blend'))
report = {'runtime_approved':False,'animation_approved':False,'duration_seconds':DURATION,
    'gait':'diagonal_trot' if TROT else 'four_beat_walk',
    'stride_m':STRIDE,'stance_fraction':STANCE,'matching_forward_speed_m_per_s':SPEED/DURATION,
    'neutral_body_lowering_m':BODY_LOWERING,'body_bob_amplitude_m':.002,
    'leg_stance_fractions':leg_stances,'leg_contact_travel_m':{key:SPEED*duty for key,duty in leg_stances.items()},
    'footfall_phase_offsets':phases,'sampled_frames':frames+1,
    'maximum_paw_endpoint_error_m':maximum_endpoint_error,
    'maximum_planted_sole_slip_per_frame_m':maximum_slip,
    'minimum_full_cycle_mesh_height_m':minimum_height,'mesh_loop_seam_m':seam,
    'scope':'Full-cycle Blender evaluated-mesh contact checks at 30Hz; rendered anatomy, baked export and Godot playback pending',
    'samples':samples}
(OUT/'walk_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({key:value for key,value in report.items() if key != 'samples'}),flush=True)
